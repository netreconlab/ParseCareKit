//
//  Patients.swift
//  ParseCareKit
//
//  Created by Corey Baker on 10/5/19.
//  Copyright © 2019 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore


open class Patient: PCKVersionedObject, PCKRemoteSynchronized {
    
    public var alergies:[String]?
    public var birthday:Date?
    public var name: PersonNameComponents?
    public var sex: OCKBiologicalSex?
    
    public static var className: String {
        kPCKPatientClassKey
    }

    override init () {
        super.init()
    }

    public convenience init?(careKitEntity: OCKAnyPatient) {
        self.init()
        do {
            _ = try self.copyCareKit(careKitEntity)
        } catch {
            return nil
        }
    }
    
    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
    
    enum CodingKeys: String, CodingKey {
        case alergies, birthday, name, sex
    }
    
    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(alergies, forKey: .alergies)
        try container.encode(birthday, forKey: .birthday)
        try container.encode(name, forKey: .name)
        try container.encode(sex, forKey: .sex)
    }
    
    open func new() -> PCKSynchronized {
        return Patient()
    }
    
    open func new(with careKitEntity: OCKEntity)->PCKSynchronized?{
    
        switch careKitEntity {
        case .patient(let entity):
            return Patient(careKitEntity: entity)
            
        default:
            print("Error in \(className).new(with:). The wrong type of entity was passed \(careKitEntity)")
            return nil
        }
    }
    
    open func addToCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PCKUser.current,
              let uuid = self.uuid else{
            completion(false, ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }

        //Check to see if already in the cloud
        var query = Self.query(kPCKObjectableUUIDKey == uuid)
        query.include([kPCKObjectableNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.first(callbackQueue: .global(qos: .background)){ result in
           
            switch result {
            
            case .success(_):
                completion(false,ParseCareKitError.uuidAlreadyExists)
            case .failure(let error):
                
                switch error.code{
                case .internalServer, .objectNotFound: //1 - this column hasn't been added. 101 - Query returned no results
                    self.save(self, completion: completion)
                default:
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.className).addToCloud(). \(error.localizedDescription)")
                    completion(false,error)
                }
                return
            }
        }
    }
    
    open func updateCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PCKUser.current,
              let uuid = self.uuid,
            let previousPatientUUID = self.previousVersionUUID else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if this entity is already in the Cloud, but not paired locally
        var query = Patient.query(containedIn(key: kPCKObjectableUUIDKey, array: [uuid,previousPatientUUID]))
        query.include([kPCKObjectableNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.find(callbackQueue: .global(qos: .background)){ results in
            
            switch results {
            
            case .success(let foundObjects):
                switch foundObjects.count{
                case 0:
                    print("Warning in \(self.className).updateCloud(). A previous version is suppose to exist in the Cloud, but isn't present, saving as new")
                    self.addToCloud(completion: completion)
                case 1:
                    //This is the typical case
                    guard let previousVersion = foundObjects.filter({$0.uuid == previousPatientUUID}).first else {
                        print("Error in \(self.className).updateCloud(). Didn't find previousVersion and this UUID already exists in Cloud")
                        completion(false,ParseCareKitError.uuidAlreadyExists)
                        return
                    }
                    self.copyRelationalEntities(previousVersion)
                    self.addToCloud(completion: completion)

                default:
                    print("Error in \(self.className).updateCloud(). UUID already exists in Cloud")
                    completion(false,ParseCareKitError.uuidAlreadyExists)
                }
            case .failure(let error):
                print("Error in \(self.className).updateCloud(). \(error.localizedDescription)")
                completion(false,error)
            }
        }
    }
    
    
    
    open func deleteFromCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        //Handled with update, marked for deletion
        completion(true,nil)
    }
    
    public func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        var query = Self.query(kPCKObjectableClockKey >= localClock)
        query.order([.ascending(kPCKObjectableClockKey), .ascending(kPCKParseCreatedAtKey)])
        query.include([kPCKObjectableNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.find(callbackQueue: .global(qos: .background)){ results in
            switch results {
            
            case .success(let carePlans):
                let pulled = carePlans.compactMap{try? $0.convertToCareKit()}
                let entities = pulled.compactMap{OCKEntity.patient($0)}
                let revision = OCKRevisionRecord(entities: entities, knowledgeVector: cloudVector)
                mergeRevision(revision)
            case .failure(let error):
                let revision = OCKRevisionRecord(entities: [], knowledgeVector: cloudVector)
                
                switch error.code{
                case .internalServer, .objectNotFound: //1 - this column hasn't been added. 101 - Query returned no results
                    //If the query was looking in a column that wasn't a default column, it will return nil if the table doesn't contain the custom column
                    //Saving the new item with the custom column should resolve the issue
                    print("Warning, table CarePlan either doesn't exist or is missing the column \(kPCKObjectableClockKey). It should be fixed during the first sync of an Outcome... \(error.localizedDescription)")
                default:
                    print("An unexpected error occured \(error.localizedDescription)")
                }
                mergeRevision(revision)
            }
        }
    }
    
    public func pushRevision(_ overwriteRemote: Bool, cloudClock: Int, completion: @escaping (Error?) -> Void){
        
        self.logicalClock = cloudClock //Stamp Entity
        
        guard let _ = self.previousVersionUUID else{
            self.addToCloud(true, overwriteRemote: overwriteRemote){
                (success,error) in
                if success{
                    completion(nil)
                }else{
                    completion(error)
                }
            }
            return
        }
        
        self.updateCloud(true, overwriteRemote: overwriteRemote){
            (success,error) in
            if success{
                completion(nil)
            }else{
                completion(error)
            }
        }
    }
    
    open override func copyCommonValues(from other: PCKObject){
        super.copyCommonValues(from: other)
        guard let other = other as? Patient else{return}
        self.name = other.name
        self.birthday = other.birthday
        self.sex = other.sex
        self.alergies = other.alergies
    }
    
    open func copyCareKit(_ patientAny: OCKAnyPatient) throws -> Patient {
        
        guard let _ = PCKUser.current,
            let patient = patientAny as? OCKPatient else{
            throw ParseCareKitError.cantCastToNeededClassType
        }
        
        let encoded = try JSONEncoder().encode(patient)
        let decoded = try JSONDecoder().decode(Self.self, from: encoded)
        self.copyCommonValues(from: decoded)
        self.entityId = patient.id
        return self
        
        /*
        if let uuid = patient.uuid?.uuidString {
            self.uuid = uuid
        }else{
            print("Warning in \(className). Entity missing uuid: \(patient)")
        }
        
        if let schemaVersion = Patient.getSchemaVersionFromCareKitEntity(patient){
            self.schemaVersion = schemaVersion
        }else{
            print("Warning in \(className).copyCareKit(). Entity missing schemaVersion: \(patient)")
        }
        
        self.entityId = patient.id
        self.name = CareKitPersonNameComponents.familyName.convertToDictionary(patient.name)
        self.birthday = patient.birthday
        self.sex = patient.sex?.rawValue
        self.effectiveDate = patient.effectiveDate
        self.deletedDate = patient.deletedDate
        self.updatedDate = patient.updatedDate
        self.timezone = patient.timezone.abbreviation()!
        self.userInfo = patient.userInfo
        self.remoteID = patient.remoteID
        self.alergies = patient.allergies
        self.createdDate = patient.createdDate
        self.notes = patient.notes?.compactMap{Note(careKitEntity: $0)}
        self.previousVersionUUID = patient.previousVersionUUID
        self.nextVersionUUID = patient.nextVersionUUID
        return self*/
    }
    
    open func convertToCareKit(fromCloud:Bool=true) throws ->OCKPatient {
        self.encodingForParse = false
        let encoded = try JSONEncoder().encode(self)
        self.encodingForParse = true
        return try JSONDecoder().decode(OCKPatient.self, from: encoded)
        
        /*guard self.canConvertToCareKit() == true,
            let name = self.name else {
            return nil
        }
        let nameComponents = CareKitPersonNameComponents.familyName.convertToPersonNameComponents(name)
        var patient = OCKPatient(id: self.entityId!, name: nameComponents)

        if fromCloud{
            guard let decodedPatient = decodedCareKitObject(patient) else{
                print("Error in \(className). Couldn't decode entity \(self)")
                return nil
            }
            patient = decodedPatient
        }
        
        if let effectiveDate = self.effectiveDate{
            patient.effectiveDate = effectiveDate
        }
        patient.birthday = self.birthday
        patient.allergies = self.alergies
        patient.groupIdentifier = self.groupIdentifier
        patient.tags = self.tags
        patient.source = self.source
        patient.asset = self.asset
        patient.userInfo = self.userInfo
        patient.notes = self.notes?.compactMap{$0.convertToCareKit()}
        patient.remoteID = self.remoteID
        if let timeZone = TimeZone(abbreviation: self.timezone!){
            patient.timezone = timeZone
        }
        if let sex = self.sex{
            patient.sex = OCKBiologicalSex(rawValue: sex)
        }
        return patient*/
    }
}
