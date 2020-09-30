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


public final class Patient: PCKVersionable, PCKSynchronizable {
    public internal(set) var nextVersion: Patient? {
        didSet {
            nextVersionUUID = nextVersion?.uuid
        }
    }
    
    public internal(set) var nextVersionUUID:UUID? {
        didSet {
            if nextVersionUUID != nextVersion?.uuid {
                nextVersion = nil
            }
        }
    }

    public internal(set) var previousVersion: Patient? {
        didSet {
            previousVersionUUID = previousVersion?.uuid
        }
    }
    
    public internal(set) var previousVersionUUID: UUID? {
        didSet {
            if previousVersionUUID != previousVersion?.uuid {
                previousVersion = nil
            }
        }
    }
    
    var effectiveDate: Date?
    
    var uuid: UUID?
    
    var entityId: String?
    
    var logicalClock: Int?
    
    var schemaVersion: OCKSemanticVersion?
    
    var createdDate: Date?
    
    var updatedDate: Date?
    
    var deletedDate: Date?
    
    var timezone: TimeZone?
    
    var userInfo: [String : String]?
    
    var groupIdentifier: String?
    
    var tags: [String]?
    
    var source: String?
    
    var asset: String?
    
    var notes: [Note]?
    
    var remoteID: String?
    
    var encodingForParse: Bool = true
    
    public var objectId: String?
    
    public var createdAt: Date?
    
    public var updatedAt: Date?
    
    public var ACL: ParseACL?
    
    
    public var alergies:[String]?
    public var birthday:Date?
    public var name: PersonNameComponents?
    public var sex: OCKBiologicalSex?
    
    public static var className: String {
        kPCKPatientClassKey
    }

    init () {
        //super.init()
    }

    public convenience init?(careKitEntity: OCKAnyPatient) {
        self.init()
        do {
            _ = try self.copyCareKit(careKitEntity)
        } catch {
            return nil
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case alergies, birthday, name, sex
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(alergies, forKey: .alergies)
        try container.encode(birthday, forKey: .birthday)
        try container.encode(name, forKey: .name)
        try container.encode(sex, forKey: .sex)
        try encodeVersionable(to: encoder)
        encodingForParse = true
    }
    
    public func new() -> PCKSynchronizable {
        return Patient()
    }
    
    public func new(with careKitEntity: OCKEntity)->PCKSynchronizable?{
    
        switch careKitEntity {
        case .patient(let entity):
            return Patient(careKitEntity: entity)
            
        default:
            print("Error in \(className).new(with:). The wrong type of entity was passed \(careKitEntity)")
            return nil
        }
    }
    
    public func addToCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
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
                    self.save(completion: completion)
                default:
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.className).addToCloud(). \(error.localizedDescription)")
                    completion(false,error)
                }
                return
            }
        }
    }
    
    public func updateCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
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
                    guard let previousVersion = foundObjects.first(where: {$0.uuid == previousPatientUUID}) else {
                        print("Error in \(self.className).updateCloud(). Didn't find previousVersion and this UUID already exists in Cloud")
                        completion(false,ParseCareKitError.uuidAlreadyExists)
                        return
                    }
                    var updated = self
                    updated = updated.copyRelationalEntities(previousVersion)
                    updated.addToCloud(completion: completion)

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
    
    
    
    public func deleteFromCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
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
    
    public class func copyValues(from other: Patient, to here: Patient) throws -> Self {
        var here = here
        here.copyCommonValues(from: other)
        here.name = other.name
        here.birthday = other.birthday
        here.sex = other.sex
        here.alergies = other.alergies
        guard let copied = here as? Self else {
            throw ParseCareKitError.cantCastToNeededClassType
        }
        return copied
    }
    
    public func copyCareKit(_ patientAny: OCKAnyPatient) throws -> Patient {
        
        guard let _ = PCKUser.current,
            let patient = patientAny as? OCKPatient else{
            throw ParseCareKitError.cantCastToNeededClassType
        }
        
        let encoded = try JSONEncoder().encode(patient)
        let decoded = try JSONDecoder().decode(Self.self, from: encoded)
        self.entityId = patient.id
        
        return try Self.copyValues(from: decoded, to: self)
        
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
    
    public func convertToCareKit(fromCloud:Bool=true) throws ->OCKPatient {
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
