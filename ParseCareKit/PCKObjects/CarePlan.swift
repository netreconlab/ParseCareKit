//
//  CarePlan.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import ParseSwift
import CareKitStore


open class CarePlan: PCKVersionedObject, PCKRemoteSynchronized {

    var patient:Patient?
    var patientUUIDString:String?
    public var title:String?
    
    public var patientUUID:UUID? {
        get {
            if patient?.uuid != nil{
                return UUID(uuidString: patient!.uuid!)
            }else if patientUUIDString != nil {
                return UUID(uuidString: patientUUIDString!)
            }else{
                return nil
            }
        }
        set{
            patientUUIDString = newValue?.uuidString
            if newValue?.uuidString != patient?.uuid{
                patient = nil
            }
        }
    }
    
    public var currentPatient: Patient?{
        get{
            return patient
        }
        set{
            patient = newValue
            patientUUIDString = newValue?.uuid
        }
    }
    
    public class func className() -> String {
        return kPCKCarePlanClassKey
    }

    override init() {
        super.init()
    }
    
    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    public convenience init(careKitEntity: OCKAnyCarePlan) {
        self.init()
        _ = self.copyCareKit(careKitEntity)
    }
    
    open func new() -> PCKSynchronized {
        return CarePlan()
    }

    public func new(with careKitEntity: OCKEntity) -> PCKSynchronized? {
        switch careKitEntity {
        case .carePlan(let entity):
            return CarePlan(careKitEntity: entity)
        default:
            print("Error in \(className).new(with:). The wrong type of entity was passed \(careKitEntity)")
            return nil
        }
    }
    
    public func addToCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PCKUser.current else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        let query = Self.query(kPCKObjectUUIDKey == self.uuid)
        query.first(callbackQueue: .global(qos: .background)){
            result in
            
            switch result {
            
            case .success(_):
                completion(false,ParseCareKitError.uuidAlreadyExists)
            case .failure(let error):

                switch error.code {
                case .internalServer, .objectNotFound: //1 - this column hasn't been added. 101 - Query returned no results
                        self.save(self, completion: completion)
                default:
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.className).addToCloud(). \(error.localizedDescription)")
                    completion(false,error)
                }
            }
        }
    }
    
    public func updateCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PCKUser.current,
            let previousCarePlanUUIDString = self.previousVersionUUID?.uuidString else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if this entity is already in the Cloud, but not matched locally
        var query = Self.query(containedIn(key: kPCKObjectUUIDKey, array: [self.uuid, previousCarePlanUUIDString]))
        query.include(kPCKCarePlanPatientKey,kPCKObjectNotesKey,
                          kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey)
        query.find(callbackQueue: .main) {
            results in
            
            switch results {
            
            case .success(let foundObjects):
                switch foundObjects.count{
                case 0:
                    print("Warning in \(self.className).updateCloud(). A previous version is suppose to exist in the Cloud, but isn't present, saving as new")
                    self.addToCloud(completion: completion)
                case 1:
                    //This is the typical case
                    guard let previousVersion = foundObjects.filter({$0.uuid == previousCarePlanUUIDString}).first else {
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
    
    public func deleteFromCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        //Handled with update, marked for deletion
        completion(true,nil)
    }
    
    public func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        var query = Self.query(kPCKObjectClockKey >= localClock)
        query.order([.ascending(kPCKObjectClockKey), .ascending(kPCKParseCreatedAtKey)])
        query.include([kPCKCarePlanPatientKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.find(callbackQueue: .global(qos: .background)){ results in
            
            switch results {
            
            case .success(let carePlans):
                let pulled = carePlans.compactMap{$0.convertToCareKit()}
                let entities = pulled.compactMap{OCKEntity.carePlan($0)}
                let revision = OCKRevisionRecord(entities: entities, knowledgeVector: cloudVector)
                mergeRevision(revision)
            case .failure(let error):
                let revision = OCKRevisionRecord(entities: [], knowledgeVector: cloudVector)
                
                switch error.code{
                case .internalServer, .objectNotFound: //1 - this column hasn't been added. 101 - Query returned no results
                    //If the query was looking in a column that wasn't a default column, it will return nil if the table doesn't contain the custom column
                    //Saving the new item with the custom column should resolve the issue
                    print("Warning, table CarePlan either doesn't exist or is missing the column \(kPCKObjectClockKey). It should be fixed during the first sync of an Outcome... \(error.localizedDescription)")
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
        guard let other = other as? CarePlan else{return}
        self.currentPatient = other.currentPatient
        self.patientUUID = other.patientUUID
        self.title = other.title
    }
    
    open func copyCareKit(_ carePlanAny: OCKAnyCarePlan)-> CarePlan?{
        
        guard let _ = PCKUser.current,
            let carePlan = carePlanAny as? OCKCarePlan else{
            return nil
        }
        
        if let uuid = carePlan.uuid?.uuidString{
            self.uuid = uuid
        }else{
            print("Warning in \(className). Entity missing uuid: \(carePlan)")
        }
        
        if let schemaVersion = CarePlan.getSchemaVersionFromCareKitEntity(carePlan){
            self.schemaVersion = schemaVersion
        }else{
            print("Warning in \(className).copyCareKit(). Entity missing schemaVersion: \(carePlan)")
        }
        
        self.entityId = carePlan.id
        self.deletedDate = carePlan.deletedDate
        self.title = carePlan.title
        self.groupIdentifier = carePlan.groupIdentifier
        self.tags = carePlan.tags
        self.source = carePlan.source
        self.asset = carePlan.asset
        self.timezone = carePlan.timezone.abbreviation()!
        self.effectiveDate = carePlan.effectiveDate
        self.updatedDate = carePlan.updatedDate
        self.userInfo = carePlan.userInfo
        self.createdDate = carePlan.createdDate
        self.notes = carePlan.notes?.compactMap{Note(careKitEntity: $0)}
        self.remoteID = carePlan.remoteID
        self.patientUUID = carePlan.patientUUID
        self.previousVersionUUID = carePlan.previousVersionUUID
        self.nextVersionUUID = carePlan.nextVersionUUID
        return self
    }
    
    //Note that CarePlans have to be saved to CareKit first in order to properly convert to CareKit
    open func convertToCareKit(fromCloud:Bool=true)->OCKCarePlan? {
        
        //If super passes, can safely force unwrap entityId, timeZone
        guard self.canConvertToCareKit() == true,
              let title = self.title else {
            return nil
        }

        //Create bare Entity and replace contents with Parse contents
        var carePlan = OCKCarePlan(id: self.entityId!, title: title, patientUUID: self.patientUUID)
        
        if fromCloud{
            guard let decodedCarePlan = decodedCareKitObject(carePlan) else {
                print("Error in \(className). Couldn't decode entity \(self)")
                return nil
            }
            carePlan = decodedCarePlan
        }
        carePlan.remoteID = self.remoteID
        carePlan.groupIdentifier = self.groupIdentifier
        carePlan.tags = self.tags
        if let effectiveDate = self.effectiveDate{
            carePlan.effectiveDate = effectiveDate
        }
        carePlan.source = self.source
        carePlan.groupIdentifier = self.groupIdentifier
        carePlan.asset = self.asset
        carePlan.notes = self.notes?.compactMap{$0.convertToCareKit()}
        carePlan.userInfo = self.userInfo
        if let timeZone = TimeZone(abbreviation: self.timezone!){
            carePlan.timezone = timeZone
        }
        return carePlan
    }
    
    ///Link versions and related classes
    open override func linkRelated(completion: @escaping(Bool,CarePlan)->Void){
        super.linkRelated(){
            (isNew, _) in
            
            var linkedNew = isNew
            
            guard let patientUUID = self.patientUUID else{
                //Finished if there's no CarePlan, otherwise see if it's in the cloud
                completion(linkedNew,self)
                return
            }
            
            self.getFirstPCKObject(patientUUID, classType: Patient(), relatedObject: self.patient, include: true){
            (isNew,patient) in
                
                guard let patient = patient as? Patient else{
                    completion(linkedNew,self)
                    return
                }
                
                self.patient = patient
                if self.patient != nil{
                    linkedNew = true
                }
                completion(linkedNew,self)
            }
        }
    }
}
