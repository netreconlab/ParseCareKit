//
//  Outcomes.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/14/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore


open class Outcome: PCKObject, PCKRemoteSynchronized {

    @NSManaged public var task:Task?
    @NSManaged public var taskOccurrenceIndex:Int
    @NSManaged public var values:[OutcomeValue]
    
    
    public static func parseClassName() -> String {
        return kPCKOutcomeClassKey
    }

    public convenience init(careKitEntity: OCKAnyOutcome, store: OCKAnyStoreProtocol, completion: @escaping(PCKObject?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, clone: true, store: store, completion: completion)
    }
    
    public func new() -> PCKRemoteSynchronized {
        return CarePlan()
    }
    
    public func new(with careKitEntity: OCKEntity, store: OCKStore, completion: @escaping(PCKRemoteSynchronized?)-> Void){
        switch careKitEntity {
        case .outcome(let entity):
            self.copyCareKit(entity, clone: true, store: store, completion: completion)
        default:
            print("Error in \(parseClassName).new(with:). The wrong type of entity was passed \(careKitEntity)")
        }
    }
    
    open func addToCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
            
        guard let _ = PFUser.current() else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if already in the cloud
        let query = Outcome.query()!
        query.whereKey(kPCKObjectEntityIdKey, equalTo: self.entityId)
        query.includeKeys([kPCKOutcomeTaskKey,kPCKOutcomeValuesKey,kPCKObjectNotesKey])
        query.findObjectsInBackground(){
            (objects, error) in
            guard let foundObjects = objects else{
                guard let error = error as NSError?,
                    let errorDictionary = error.userInfo["error"] as? [String:Any],
                    let reason = errorDictionary["routine"] as? String else {return}
                //If the query was looking in a column that wasn't a default column, it will return nil if the table doesn't contain the custom column
                if reason == "errorMissingColumn"{
                    //Saving the new item with the custom column should resolve the issue
                    print("This table '\(self.parseClassName)' either doesn't exist or is missing a column. Attempting to create the table and add new data to it...")
                    //Make wall.logicalClock level entities compatible with KnowledgeVector by setting it's initial .logicalClock to 0
                    if !usingKnowledgeVector{
                        self.logicalClock = 0
                    }
                    PCKObject.saveAndCheckRemoteID(self, store: store, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
                }else{
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).addToCloud(). \(error.localizedDescription)")
                    completion(false,error)
                }
                return
            }
            
            if foundObjects.count > 0{
                //Maybe this needs to be updated instead of added
                self.updateCloud(store, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
            }else{
                //Make wall.logicalClock level entities compatible with KnowledgeVector by setting it's initial .logicalClock to 0
                if !usingKnowledgeVector{
                    self.logicalClock = 0
                }
                //This is the first object, make sure to save it
                PCKObject.saveAndCheckRemoteID(self, store:store, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
            }
        }
    }
    
    open func updateCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        
        guard let _ = PFUser.current(),
            let store = store as? OCKStore,
            let _ = UUID(uuidString: self.uuid) else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        var careKitQuery = OCKOutcomeQuery()
        careKitQuery.tags = [self.entityId]
        //careKitQuery.uuids = [entityUUID]
        store.fetchOutcome(query: careKitQuery, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let outcome):
                guard let remoteID = outcome.remoteID else{
                    //Check to see if this entity is already in the Cloud, but not matched locally
                    let query = Outcome.query()!
                    query.whereKey(kPCKObjectEntityIdKey, equalTo: self.entityId)
                    query.includeKeys([kPCKOutcomeTaskKey,kPCKOutcomeValuesKey,kPCKObjectNotesKey])
                    query.getFirstObjectInBackground(){
                        (object, error) in
                        guard let foundObject = object as? Outcome else{
                            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                            return
                        }
                        var mutableOutcome = outcome
                        mutableOutcome.remoteID = foundObject.objectId
                        self.compareUpdate(mutableOutcome, parse: foundObject, store: store, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
                    }
                    return
                }
                
                //Get latest item from the Cloud to compare against
                let query = Outcome.query()!
                query.whereKey(kPCKParseObjectIdKey, equalTo: remoteID)
                query.includeKeys([kPCKOutcomeTaskKey,kPCKOutcomeValuesKey,kPCKObjectNotesKey])
                query.getFirstObjectInBackground(){
                    (object, error) in
                    guard let foundObject = object as? Outcome else{
                        completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                        return
                    }
                    
                    self.compareUpdate(outcome, parse: foundObject, store: store, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
                    
                }
            case .failure(let error):
                print("Error in \(self.parseClassName).updateCloud(). \(error)")
                completion(false,error)
            }
        }
    }
    
    open func deleteFromCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, completion: @escaping(Bool,Error?) -> Void){
        
        guard let _ = PFUser.current(),
            let store = store as? OCKStore else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
                
        //Get latest item from the Cloud to compare against
        let query = Outcome.query()!
        query.whereKey(kPCKObjectEntityIdKey, equalTo: self.entityId)
        query.includeKeys([kPCKOutcomeValuesKey,kPCKObjectNotesKey])
        query.getFirstObjectInBackground(){
            (object, error) in
            guard let foundObject = object as? Outcome else{
                completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                return
            }
            self.compareDelete(foundObject, store: store, usingKnowledgeVector: usingKnowledgeVector, completion: completion)
        }
    }
    
    public func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        let query = Outcome.query()!
        query.whereKey(kPCKObjectClockKey, greaterThanOrEqualTo: localClock)
        query.includeKeys([kPCKOutcomeTaskKey,kPCKOutcomeValuesKey,kPCKObjectNotesKey])
        query.findObjectsInBackground{ (objects,error) in
            guard let outcomes = objects as? [Outcome] else{
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
                    print("Warning, table Outcome either doesn't exist or is missing the column \(kPCKObjectClockKey). It should be fixed during the first sync of an Outcome...")
                }
                mergeRevision(revision)
                return
            }
            let pulled = outcomes.compactMap{$0.convertToCareKit()}
            let entities = pulled.compactMap{OCKEntity.outcome($0)}
            let revision = OCKRevisionRecord(entities: entities, knowledgeVector: cloudVector)
            mergeRevision(revision)
        }
    }
    
    public func pushRevision(_ store: OCKStore, overwriteRemote: Bool, cloudClock: Int, completion: @escaping (Error?) -> Void){
        
        self.logicalClock = cloudClock //Stamp Entity
        if self.deletedDate == nil{
            self.addToCloud(store, usingKnowledgeVector: true, overwriteRemote: overwriteRemote){
                (success,error) in
                if success{
                    completion(nil)
                }else{
                    completion(error)
                }
            }
        }else{
            self.deleteFromCloud(store, usingKnowledgeVector: true){
                (success,error) in
                if success{
                    completion(nil)
                }else{
                    completion(error)
                }
            }
        }
    }
        
    open func copyCareKit(_ outcomeAny: OCKAnyOutcome, clone: Bool, store: OCKAnyStoreProtocol, completion: @escaping(Outcome?) -> Void){
        
        guard let _ = PFUser.current(),
            let outcome = outcomeAny as? OCKOutcome,
            let store = store as? OCKStore else{
            completion(nil)
            return
        }
        
        if let uuid = outcome.uuid?.uuidString{
            self.uuid = uuid
        }else{
            print("Warning in \(parseClassName).copyCareKit(). Entity missing uuid: \(outcome)")
        }
        
        self.entityId = outcome.id
        self.taskOccurrenceIndex = outcome.taskOccurrenceIndex
        self.groupIdentifier = outcome.groupIdentifier
        self.tags = outcome.tags
        if self.tags == nil{
            self.tags = [self.entityId]
        }else if !self.tags!.contains(self.entityId){
            self.tags!.append(self.entityId)
        }
        self.source = outcome.source
        self.asset = outcome.asset
        self.timezoneIdentifier = outcome.timezone.abbreviation()!
        self.updatedDate = outcome.updatedDate
        self.userInfo = outcome.userInfo
        
        if clone{
            self.createdDate = outcome.createdDate
            self.notes = outcome.notes?.compactMap{Note(careKitEntity: $0)}
            self.values = outcome.values.compactMap{OutcomeValue(careKitEntity: $0)}
        }else{
            //Only copy this over if the Local Version is older than the Parse version
            if self.createdDate == nil {
                self.createdDate = outcome.createdDate
            } else if self.createdDate != nil && outcome.createdDate != nil{
                if outcome.createdDate! < self.createdDate!{
                    self.createdDate = outcome.createdDate
                }
            }
            self.notes = Note.updateIfNeeded(self.notes, careKit: outcome.notes)
            self.values = OutcomeValue.updateIfNeeded(self.values, careKit: outcome.values)
        }
        
        self.fetchRelatedTask(outcome.taskUUID, store: store){
            relatedTask in
            guard let relatedTask = relatedTask else{
                completion(nil)
                return
            }
            self.task = relatedTask
            completion(self)
        }
    }
        
    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit(fromCloud:Bool=true)->OCKOutcome?{
        
        guard let task = self.task,
            let taskUUID = UUID(uuidString: task.uuid) else{
                print("Error in \(parseClassName). Must contain task with a uuid in \(self)")
                return nil
        }
        
        var outcome:OCKOutcome!
        if fromCloud{
            guard let decodedOutcome = decodedCareKitObject(self.task, taskOccurrenceIndex: self.taskOccurrenceIndex, values: self.values) else{
                print("Error in \(parseClassName). Couldn't decode entity \(self)")
                return nil
            }
            outcome = decodedOutcome
        }else{
            //Create bare Entity and replace contents with Parse contents
            let outcomeValues = self.values.compactMap{$0.convertToCareKit()}
            outcome = OCKOutcome(taskUUID: taskUUID, taskOccurrenceIndex: self.taskOccurrenceIndex, values: outcomeValues)
        }
        
        outcome.groupIdentifier = self.groupIdentifier
        outcome.tags = self.tags
        //Fix querying issue
        if outcome.tags == nil{
            outcome.tags = [self.entityId]
        }else if !outcome.tags!.contains(self.entityId){
            outcome.tags?.append(self.entityId)
        }
        
        outcome.source = self.source
        outcome.userInfo = self.userInfo
        if outcome.userInfo == nil{
            outcome.userInfo = [kPCKOutcomUserInfoEntityIdKey: self.entityId]
        } else if self.userInfo![kPCKOutcomUserInfoEntityIdKey] == nil{
            self.userInfo![kPCKOutcomUserInfoEntityIdKey] = self.entityId
        }
        outcome.taskOccurrenceIndex = self.taskOccurrenceIndex
        outcome.groupIdentifier = self.groupIdentifier
        outcome.asset = self.asset
        if let timeZone = TimeZone(abbreviation: self.timezoneIdentifier){
            outcome.timezone = timeZone
        }
        outcome.notes = self.notes?.compactMap{$0.convertToCareKit()}
        outcome.remoteID = self.objectId
        return outcome
    }
    
    open override func stampRelationalEntities(){
        super.stampRelationalEntities()
        self.values.forEach{$0.stamp(self.logicalClock)}
    }
}

