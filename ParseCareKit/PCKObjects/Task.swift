//
//  Task.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore


open class Task: PCKVersionedObject, PCKRemoteSynchronized {

    @NSManaged public var carePlan:CarePlan?
    @NSManaged public var impactsAdherence:Bool
    @NSManaged public var instructions:String?
    @NSManaged public var title:String?
    @NSManaged public var elements:[ScheduleElement] //Use elements to generate a schedule. Each task will point to an array of schedule elements
   
    public static func parseClassName() -> String {
        return kPCKTaskClassKey
    }
    
    public convenience init(careKitEntity: OCKAnyTask, store: OCKAnyStoreProtocol, completion: @escaping(PCKObject?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, clone: true, store: store, completion: completion)
    }
    
    public func new() -> PCKRemoteSynchronized {
        return CarePlan()
    }
    
    public func new(with careKitEntity: OCKEntity, store: OCKStore, completion: @escaping(PCKRemoteSynchronized?)-> Void){
        switch careKitEntity {
        case .task(let entity):
            self.copyCareKit(entity, clone: true, store: store, completion: completion)
        default:
            print("Error in \(parseClassName).new(with:). The wrong type of entity was passed \(careKitEntity)")
        }
    }
    
    public func addToCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current(),
            let taskUUID = UUID(uuidString: self.uuid) else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if already in the cloud
        let query = Task.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: taskUUID.uuidString)
        query.includeKeys([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.findObjectsInBackground(){
            (objects, error) in
            guard let foundObjects = objects else{
                guard let error = error as NSError?,
                    let errorDictionary = error.userInfo["error"] as? [String:Any],
                    let reason = errorDictionary["routine"] as? String else {
                    completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
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
                    Task.saveAndCheckRemoteID(self, store: store, completion: completion)
                }else{
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).addToCloud(). \(error.localizedDescription)")
                    completion(false,error)
                }
                return
            }
            
            //If object already in the Cloud, exit
            if foundObjects.count > 0{
                //Maybe this needs to be updated of instead
                self.updateCloud(store, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
            }else{
                //Make wallclock level entities compatible with KnowledgeVector by setting it's initial clock to 0
                if !usingKnowledgeVector{
                    self.logicalClock = 0
                }
                Task.saveAndCheckRemoteID(self, store: store, completion: completion)
            }
        }
    }
    
    public func updateCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current(),
            let store = store as? OCKStore,
            let taskUUID = UUID(uuidString: self.uuid) else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        var careKitQuery = OCKTaskQuery()
        careKitQuery.uuids = [taskUUID]
        
        store.fetchTasks(query: careKitQuery, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let tasks):
                guard let task = tasks.first else{
                    completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                    return
                }
                guard let remoteID = task.remoteID else{
                           
                    //Check to see if this entity is already in the Cloud, but not matched locally
                    let query = Task.query()!
                    query.whereKey(kPCKObjectUUIDKey, equalTo: taskUUID.uuidString)
                    query.includeKeys([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
                    query.getFirstObjectInBackground{
                        (objects, error) in
                        guard let foundObject = objects as? Task else{
                            completion(false,error)
                            return
                        }
                        self.compareUpdate(task, parse: foundObject, store: store, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
                    }
                    return
                }
                       
                //Get latest item from the Cloud to compare against
                let query = Task.query()!
                query.whereKey(kPCKParseObjectIdKey, equalTo: remoteID)
                query.includeKeys([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
                query.getFirstObjectInBackground(){
                    (object, error) in
                    guard let foundObject = object as? Task else{
                        completion(false,error)
                        return
                    }
                    self.compareUpdate(task, parse: foundObject, store: store, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
                }
            case .failure(let error):
                print("Error in Contact.addToCloud(). \(error)")
                completion(false,error)
            }
        }
       
    }
    
    public func deleteFromCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current(),
            let store = store as? OCKStore,
            let taskUUID = UUID(uuidString: self.uuid) else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Get latest item from the Cloud to compare against
        let query = Task.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: taskUUID.uuidString)
        query.includeKeys([kPCKTaskElementsKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.getFirstObjectInBackground(){
            (objects, error) in
            guard let foundObject = objects as? Task else{
                completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                return
            }
            self.compareDelete(foundObject, store: store, usingKnowledgeVector: usingKnowledgeVector, completion: completion)
        }
    }
    
    public func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        let query = Task.query()!
        query.whereKey(kPCKObjectClockKey, greaterThanOrEqualTo: localClock)
        query.includeKeys([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.findObjectsInBackground{ (objects,error) in
            guard let tasks = objects as? [Task] else{
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
                    print("Warning, table Task either doesn't exist or is missing the column \(kPCKObjectClockKey). It should be fixed during the first sync of a Task...")
                }
                mergeRevision(revision)
                return
            }
            let pulled = tasks.compactMap{$0.convertToCareKit()}
            let entities = pulled.compactMap{OCKEntity.task($0)}
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
    
    
    open func copyCareKit(_ taskAny: OCKAnyTask, clone:Bool, store: OCKAnyStoreProtocol, completion: @escaping(Task?) -> Void){
        
        guard let _ = PFUser.current(),
            let task = taskAny as? OCKTask,
            let store = store as? OCKStore else{
            completion(nil)
            return
        }
        
        if let uuid = task.uuid?.uuidString{
            self.uuid = uuid
        }else{
            print("Warning in \(parseClassName). Entity missing uuid: \(task)")
        }
        self.entityId = task.id
        self.deletedDate = task.deletedDate
        self.groupIdentifier = task.groupIdentifier
        self.title = task.title
        self.impactsAdherence = task.impactsAdherence
        self.tags = task.tags
        self.source = task.source
        self.asset = task.asset
        self.timezoneIdentifier = task.timezone.abbreviation()!
        self.effectiveDate = task.effectiveDate
        self.updatedDate = task.updatedDate
        self.userInfo = task.userInfo
        if clone{
            self.createdDate = task.createdDate
            self.notes = task.notes?.compactMap{Note(careKitEntity: $0)}
            self.elements = task.schedule.elements.compactMap{ScheduleElement(careKitEntity: $0)}
        }else{
            //Only copy this over if the Local Version is older than the Parse version
            if self.createdDate == nil {
                self.createdDate = task.createdDate
            } else if self.createdDate != nil && task.createdDate != nil{
                if task.createdDate! < self.createdDate!{
                    self.createdDate = task.createdDate
                }
            }
            self.notes = Note.updateIfNeeded(self.notes, careKit: task.notes)
            self.elements = ScheduleElement.updateIfNeeded(self.elements, careKit: task.schedule.elements)
        }
        
        //Setting up CarePlan query
        var uuidsToQuery = [UUID]()
        if let previousUUID = task.previousVersionUUID{
            uuidsToQuery.append(previousUUID)
        }
        if let nextUUID = task.nextVersionUUID{
            uuidsToQuery.append(nextUUID)
        }
        
        if uuidsToQuery.isEmpty{
            self.previous = nil
            self.next = nil
            
            guard let carePlanUUID = task.carePlanUUID else{
                completion(self)
                return
            }
            
            self.fetchRelatedCarePlan(carePlanUUID, store: store){
                carePlan in
                if carePlan != nil && task.carePlanUUID != nil{
                    self.carePlan = carePlan
                    completion(self)
                }else if carePlan == nil && task.carePlanUUID == nil{
                    completion(self)
                }else{
                    completion(nil)
                }
            }
        }else{
            var query = OCKTaskQuery()
            query.uuids = uuidsToQuery
            store.fetchTasks(query: query, callbackQueue: .global(qos: .background)){
                results in
                switch results{
                    
                case .success(let entities):
                    let previousRemoteId = entities.filter{$0.uuid == task.previousVersionUUID}.first?.remoteID
                    if previousRemoteId != nil && task.previousVersionUUID != nil{
                        self.previous = Task(withoutDataWithObjectId: previousRemoteId!)
                    }else if previousRemoteId == nil && task.previousVersionUUID == nil{
                        self.previous = nil
                    }else{
                        completion(nil)
                        return
                    }
                    
                    let nextRemoteId = entities.filter{$0.uuid == task.nextVersionUUID}.first?.remoteID
                    if nextRemoteId != nil{
                        self.next = Task(withoutDataWithObjectId: nextRemoteId!)
                    }
                    
                case .failure(let error):
                    print("Error in \(self.parseClassName).copyCareKit(). Error \(error)")
                    self.previous = nil
                    self.next = nil
                }
                
                guard let carePlanUUID = task.carePlanUUID else{
                    completion(self)
                    return
                }
                self.fetchRelatedCarePlan(carePlanUUID, store: store){
                    carePlan in
                    if carePlan != nil && task.carePlanUUID != nil{
                        self.carePlan = carePlan
                        completion(self)
                    }else if carePlan == nil && task.carePlanUUID == nil{
                        completion(self)
                    }else{
                        completion(nil)
                    }
                }
            }
        }
        
    }
    
    
    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit(fromCloud:Bool=true)->OCKTask?{
        
        //Create bare Entity and replace contents with Parse contents
        let careKitScheduleElements = self.elements.compactMap{$0.convertToCareKit()}
        let schedule = OCKSchedule(composing: careKitScheduleElements)
        var task = OCKTask(id: self.entityId, title: self.title, carePlanUUID: nil, schedule: schedule)
        
        if fromCloud{
            guard let decodedTask = decodedCareKitObject(task) else{
                print("Error in \(parseClassName). Couldn't decode entity \(self)")
                return nil
            }
            task = decodedTask
        }
        
        task.groupIdentifier = self.groupIdentifier
        task.tags = self.tags
        if let effectiveDate = self.effectiveDate{
            task.effectiveDate = effectiveDate
        }
        task.source = self.source
        task.instructions = self.instructions
        task.impactsAdherence = self.impactsAdherence
        task.groupIdentifier = self.groupIdentifier
        task.asset = self.asset
        task.userInfo = self.userInfo
        if let timeZone = TimeZone(abbreviation: self.timezoneIdentifier){
            task.timezone = timeZone
        }
        task.notes = self.notes?.compactMap{$0.convertToCareKit()}
        task.remoteID = self.objectId
        
        guard let parseCarePlan = self.carePlan,
            let carePlanUUID = UUID(uuidString: parseCarePlan.uuid) else{
            return task
        }
        task.carePlanUUID = carePlanUUID
        return task
    }
    
    open override func stampRelationalEntities(){
        super.stampRelationalEntities()
        self.elements.forEach{$0.stamp(self.logicalClock)}
    }
}
