//
//  CarePlan.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore


open class CarePlan: PCKVersionedObject, PCKRemoteSynchronized {

    @NSManaged public var patient:Patient?
    @NSManaged var patientUUIDString:String?
    @NSManaged public var title:String
    
    public var patientUUID:UUID? {
        get {
            if next != nil{
                return UUID(uuidString: patient!.uuid)
            }else if patientUUIDString != nil {
                return UUID(uuidString: patientUUIDString!)
            }else{
                return nil
            }
        }
        set{
            patientUUIDString = newValue?.uuidString
        }
    }
    
    public static func parseClassName() -> String {
        return kPCKCarePlanClassKey
    }
    
    public convenience init(careKitEntity: OCKAnyCarePlan, store: OCKAnyStoreProtocol, completion: @escaping(PCKObject?) -> Void) {
        self.init()
        guard let store = store as? OCKStore else{
            completion(nil)
            return
        }
        self.store = store
        self.copyCareKit(careKitEntity, clone: true, completion: completion)
    }
    
    open func new() -> PCKSynchronized {
        return CarePlan()
    }
    
    open func new(with careKitEntity: OCKEntity, store: OCKAnyStoreProtocol, completion: @escaping(PCKSynchronized?)-> Void){
        guard let store = store as? OCKStore else{
            completion(nil)
            return
        }
        self.store = store
        switch careKitEntity {
        case .carePlan(let entity):
            self.copyCareKit(entity, clone: true, completion: completion)
        default:
            print("Error in \(parseClassName).new(with:). The wrong type of entity was passed \(careKitEntity)")
            completion(nil)
        }
    }
    
    public func addToCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current() else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        let query = CarePlan.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: self.uuid)
        query.includeKeys([kPCKCarePlanPatientKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.findObjectsInBackground(){ [weak self]
            (objects, parseError) in
            
            guard let self = self else{
                completion(false,ParseCareKitError.cantUnwrapSelf)
                return
            }
            
            guard let foundObjects = objects else{
                guard let error = parseError as NSError?,
                    let errorDictionary = error.userInfo["error"] as? [String:Any],
                    let reason = errorDictionary["routine"] as? String else {
                        completion(false,parseError)
                        return
                }
                //If the query was looking in a column that wasn't a default column, it will return nil if the table doesn't contain the custom column
                if reason == "errorMissingColumn"{
                    //Saving the new item with the custom column should resolve the issue
                    print("This table '\(self.parseClassName)' either doesn't exist or is missing a column. Attempting to create the table and add new data to it...")
                    //Make wallclock level entities compatible with KnowledgeVector by setting it's initial clock to 0
                    if !usingKnowledgeVector{
                        self.logicalClock = 0
                    }
                    self.saveAndCheckRemoteID(self, completion: completion)
                }else{
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).addToCloud(). \(error.localizedDescription)")
                    completion(false,error)
                }
                return
            }
            
            if foundObjects.count > 0{
                //Maybe this needs to be updated instead
                self.updateCloud(usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
            }else{
                //Make wallclock level entities compatible with KnowledgeVector by setting it's initial clock to 0
                if !usingKnowledgeVector{
                    self.logicalClock = 0
                }
                self.saveAndCheckRemoteID(self, completion: completion)
            }
        }
    }
    
    public func updateCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current(),
            let carePlanUUID = UUID(uuidString: self.uuid) else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        var careKitQuery = OCKCarePlanQuery()
        careKitQuery.uuids = [carePlanUUID]
        
        store.fetchCarePlans(query: careKitQuery, callbackQueue: .global(qos: .background)){ [weak self]
            result in
            
            guard let self = self else{
                completion(false,ParseCareKitError.cantUnwrapSelf)
                return
            }
            
            switch result{
            case .success(let carePlans):
                
                guard let carePlan = carePlans.first else{
                    completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                    return
                }
                
                //Check to see if already in the cloud
                guard let remoteID = carePlan.remoteID else{
                    //Check to see if this entity is already in the Cloud, but not matched locally
                    let query = CarePlan.query()!
                    query.whereKey(kPCKObjectUUIDKey, equalTo: carePlanUUID.uuidString)
                    query.includeKeys([kPCKCarePlanPatientKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
                    query.getFirstObjectInBackground(){
                        (object, error) in
                        guard let foundObject = object as? CarePlan else{
                            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                            return
                        }
                        self.compareUpdate(carePlan, parse: foundObject, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
                        
                    }
                    return
                }
                //Get latest item from the Cloud to compare against
                let query = CarePlan.query()!
                query.whereKey(kPCKParseObjectIdKey, equalTo: remoteID)
                query.includeKeys([kPCKCarePlanPatientKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
                query.getFirstObjectInBackground(){ [weak self]
                    (object, error) in
                    
                    guard let self = self else{
                        completion(false,ParseCareKitError.cantUnwrapSelf)
                        return
                    }
                    
                    guard let foundObject = object as? CarePlan else{
                        completion(false,error)
                        return
                    }
                    self.compareUpdate(carePlan, parse: foundObject, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
                }
            case .failure(let error):
                print("Error in Contact.addToCloud(). \(error)")
                completion(false,error)
            }
        }
        
    }
    
    public func deleteFromCloud(_ usingKnowledgeVector:Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current() else{
                completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
       
        //Get latest item from the Cloud to compare against
        let query = CarePlan.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: self.uuid)
        query.getFirstObjectInBackground{ [weak self]
            (object, error) in
            guard let foundObject = object as? CarePlan else{
                completion(false,error)
                return
            }
            
            guard let self = self else{
                completion(false,ParseCareKitError.cantUnwrapSelf)
                return
            }
            
            self.compareDelete(foundObject, completion: completion)
        }
    }
    
    public func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        let query = CarePlan.query()!
        query.whereKey(kPCKObjectClockKey, greaterThanOrEqualTo: localClock)
        query.includeKeys([kPCKCarePlanPatientKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.findObjectsInBackground{ (objects,error) in
            guard let carePlans = objects as? [CarePlan] else{
                let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
                guard let error = error as NSError?,
                    let errorDictionary = error.userInfo["error"] as? [String:Any],
                    let reason = errorDictionary["routine"] as? String else {
                        mergeRevision(revision)
                        return
                }
                //If the query was looking in a column that wasn't a default column, it will return nil if the table doesn't contain the custom column
                if reason == "errorMissingColumn"{
                    //Saving the new item with the custom column should resolve the issue
                    print("Warning, table CarePlan either doesn't exist or is missing the column \(kPCKObjectClockKey). It should be fixed during the first sync of an Outcome...")
                }
                mergeRevision(revision)
                return
            }
            let pulled = carePlans.compactMap{$0.convertToCareKit()}
            let entities = pulled.compactMap{OCKEntity.carePlan($0)}
            let revision = OCKRevisionRecord(entities: entities, knowledgeVector: cloudVector)
            mergeRevision(revision)
        }
    }
    
    public func pushRevision(_ overwriteRemote: Bool, cloudClock: Int, completion: @escaping (Error?) -> Void){
        self.logicalClock = cloudClock //Stamp Entity
        if self.deletedDate == nil{
            self.addToCloud(true, overwriteRemote: overwriteRemote){
                (success,error) in
                if success{
                    completion(nil)
                }else{
                    completion(error)
                }
            }
        }else{
            self.deleteFromCloud(true){
                (success,error) in
                if success{
                    completion(nil)
                }else{
                    completion(error)
                }
            }
        }
    }
    
    open func copyCareKit(_ carePlanAny: OCKAnyCarePlan, clone: Bool, completion: @escaping(CarePlan?) -> Void){
        
        guard let _ = PFUser.current(),
            let carePlan = carePlanAny as? OCKCarePlan else{
            completion(nil)
            return
        }
        
        if let uuid = carePlan.uuid?.uuidString{
            self.uuid = uuid
        }else{
            print("Warning in \(parseClassName). Entity missing uuid: \(carePlan)")
        }
        self.entityId = carePlan.id
        self.deletedDate = carePlan.deletedDate
        self.title = carePlan.title
        self.groupIdentifier = carePlan.groupIdentifier
        self.tags = carePlan.tags
        self.source = carePlan.source
        self.asset = carePlan.asset
        self.timezoneIdentifier = carePlan.timezone.abbreviation()!
        self.effectiveDate = carePlan.effectiveDate
        self.updatedDate = carePlan.updatedDate
        self.userInfo = carePlan.userInfo
        if clone{
            self.createdDate = carePlan.createdDate
            self.notes = carePlan.notes?.compactMap{Note(careKitEntity: $0)}
        }else{
            //Only copy this over if the Local Version is older than the Parse version
            if self.createdDate == nil {
                self.createdDate = carePlan.createdDate
            } else if self.createdDate != nil && carePlan.createdDate != nil{
                if carePlan.createdDate! < self.createdDate!{
                    self.createdDate = carePlan.createdDate
                }
            }
            self.notes = Note.updateIfNeeded(self.notes, careKit: carePlan.notes)
        }
        
        //Setting up CarePlan query
        var uuidsToQuery = [UUID]()
        if let previousUUID = carePlan.previousVersionUUID{
            uuidsToQuery.append(previousUUID)
        }
        if let nextUUID = carePlan.nextVersionUUID{
            uuidsToQuery.append(nextUUID)
        }
        
        if uuidsToQuery.isEmpty{
            self.previous = nil
            self.next = nil
            
            guard let carePlanUUID = carePlan.uuid else{
                completion(self)
                return
            }
            self.fetchRelatedPatient(carePlanUUID){ [weak self]
                patient in
                
                guard let self = self else{
                    completion(nil)
                    return
                }
                
                if patient != nil && carePlan.patientUUID != nil{
                    self.patient = patient
                    completion(self)
                }else if patient == nil && carePlan.patientUUID == nil{
                    completion(self)
                }else{
                    completion(nil)
                }
            }
        }else{
            var query = OCKCarePlanQuery()
            query.uuids = uuidsToQuery
            store.fetchCarePlans(query: query, callbackQueue: .global(qos: .background)){ [weak self]
                results in
                
                guard let self = self else{
                    completion(nil)
                    return
                }
                
                switch results{
                    
                case .success(let entities):
                    let previousRemoteId = entities.filter{$0.uuid == carePlan.previousVersionUUID}.first?.remoteID
                    if previousRemoteId != nil && carePlan.previousVersionUUID != nil{
                        self.previous = CarePlan(withoutDataWithObjectId: previousRemoteId!)
                    }else if previousRemoteId == nil && carePlan.previousVersionUUID == nil{
                        self.previous = nil
                    }else{
                        completion(nil)
                        return
                    }
                    
                    let nextRemoteId = entities.filter{$0.uuid == carePlan.nextVersionUUID}.first?.remoteID
                    if nextRemoteId != nil{
                        self.next = CarePlan(withoutDataWithObjectId: nextRemoteId!)
                    }
                case .failure(let error):
                    print("Error in \(self.parseClassName).copyCareKit(). Error \(error)")
                    self.previous = nil
                    self.next = nil
                }
                
                guard let carePlanUUID = carePlan.uuid else{
                    completion(self)
                    return
                }
                self.fetchRelatedPatient(carePlanUUID){
                    patient in
                    if patient != nil && carePlan.patientUUID != nil{
                        self.patient = patient
                        completion(self)
                    }else if patient == nil && carePlan.patientUUID == nil{
                        completion(self)
                    }else{
                        completion(nil)
                    }
                }
            }
        }
    }
    
    //Note that CarePlans have to be saved to CareKit first in order to properly convert to CareKit
    open func convertToCareKit(fromCloud:Bool=true)->OCKCarePlan?{
        
        let patientUUID:UUID?
        if let patientUUIDString = patient?.uuid{
            patientUUID = UUID(uuidString: patientUUIDString)
            if patientUUID == nil{
                print("Warning in \(parseClassName).convertToCareKit. Couldn't make UUID from \(patientUUIDString). Attempted to convert anyways...")
            }
        }else{
            patientUUID = nil
        }
        //Create bare Entity and replace contents with Parse contents
        var carePlan = OCKCarePlan(id: self.entityId, title: self.title, patientUUID: patientUUID)
        
        if fromCloud{
            guard let decodedCarePlan = decodedCareKitObject(carePlan) else {
                print("Error in \(parseClassName). Couldn't decode entity \(self)")
                return nil
            }
            carePlan = decodedCarePlan
        }
        
        carePlan.groupIdentifier = self.groupIdentifier
        carePlan.tags = self.tags
        if let effectiveDate = self.effectiveDate{
            carePlan.effectiveDate = effectiveDate
        }
        carePlan.source = self.source
        carePlan.groupIdentifier = self.groupIdentifier
        carePlan.asset = self.asset
        carePlan.remoteID = self.objectId
        carePlan.notes = self.notes?.compactMap{$0.convertToCareKit()}
        carePlan.userInfo = self.userInfo
        if let timeZone = TimeZone(abbreviation: self.timezoneIdentifier){
            carePlan.timezone = timeZone
        }
        return carePlan
    }
}
