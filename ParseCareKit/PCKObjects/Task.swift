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

    @NSManaged public var impactsAdherence:Bool
    @NSManaged public var instructions:String?
    @NSManaged public var title:String?
    @NSManaged public var elements:[ScheduleElement] //Use elements to generate a schedule. Each task will point to an array of schedule elements
    @NSManaged var carePlan:CarePlan?
    @NSManaged var carePlanUUIDString:String?
    
    public var carePlanUUID:UUID? {
        get {
            if carePlan != nil{
                return UUID(uuidString: carePlan!.uuid)
            }else if carePlanUUIDString != nil {
                return UUID(uuidString: carePlanUUIDString!)
            }else{
                return nil
            }
        }
        set{
            carePlanUUIDString = newValue?.uuidString
        }
    }
    
    public var currentCarePlan: CarePlan?{
        get{
            return carePlan
        }
        set{
            carePlan = newValue
            carePlanUUIDString = newValue?.uuid
        }
    }
   
    public static func parseClassName() -> String {
        return kPCKTaskClassKey
    }
    
    public convenience init(careKitEntity: OCKAnyTask, store: OCKAnyStoreProtocol, completion: @escaping(PCKObject?) -> Void) {
        self.init()
        guard let store = store as? OCKStore else{
            completion(nil)
            return
        }
        self.store = store
        self.copyCareKit(careKitEntity, clone: true, completion: completion)
    }
    
    open func new() -> PCKSynchronized {
        return Task()
    }
    
    open func new(with careKitEntity: OCKEntity, store: OCKAnyStoreProtocol, completion: @escaping(PCKSynchronized?)-> Void){
        
        guard let store = store as? OCKStore else{
            completion(nil)
            return
        }
        self.store = store
        
        switch careKitEntity {
        case .task(let entity):
            let newClass = Task()
            newClass.store = self.store
            newClass.copyCareKit(entity, clone: true){
                _ in
                completion(newClass)
            }
        default:
            print("Error in \(parseClassName).new(with:). The wrong type of entity was passed \(careKitEntity)")
            completion(nil)
        }
    }
    
    public func addToCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current(),
            let taskUUID = UUID(uuidString: self.uuid) else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if already in the cloud
        let query = Task.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: taskUUID.uuidString)
        query.includeKeys([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.findObjectsInBackground(){ [weak self]
            (objects, error) in
            
            guard let self = self else{
                completion(false,ParseCareKitError.cantUnwrapSelf)
                return
            }
            
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
                    self.saveAndCheckRemoteID(self, completion: completion)
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
            let taskUUID = UUID(uuidString: self.uuid) else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        var careKitQuery = OCKTaskQuery()
        careKitQuery.uuids = [taskUUID]
        
        store.fetchTasks(query: careKitQuery, callbackQueue: .global(qos: .background)){ [weak self]
            result in
            
            guard let self = self else{
                completion(false,ParseCareKitError.cantUnwrapSelf)
                return
            }
            
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
                    query.getFirstObjectInBackground{ [weak self]
                        (objects, error) in
                        guard let foundObject = objects as? Task else{
                            completion(false,error)
                            return
                        }
                        
                        guard let self = self else{
                            completion(false,ParseCareKitError.cantUnwrapSelf)
                            return
                        }
                        
                        self.compareUpdate(task, parse: foundObject, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
                    }
                    return
                }
                       
                //Get latest item from the Cloud to compare against
                let query = Task.query()!
                query.whereKey(kPCKParseObjectIdKey, equalTo: remoteID)
                query.includeKeys([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
                query.getFirstObjectInBackground(){ [weak self]
                    (object, error) in
                    guard let foundObject = object as? Task else{
                        completion(false,error)
                        return
                    }
                    
                    guard let self = self else{
                        completion(false,ParseCareKitError.cantUnwrapSelf)
                        return
                    }
                    self.compareUpdate(task, parse: foundObject, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
                }
            case .failure(let error):
                print("Error in Contact.addToCloud(). \(error)")
                completion(false,error)
            }
        }
       
    }
    
    public func deleteFromCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current(),
            let taskUUID = UUID(uuidString: self.uuid) else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Get latest item from the Cloud to compare against
        let query = Task.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: taskUUID.uuidString)
        query.includeKeys([kPCKTaskElementsKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.getFirstObjectInBackground(){ [weak self]
            (objects, error) in
            guard let foundObject = objects as? Task else{
                completion(false,error)
                return
            }
            
            guard let self = self else{
                completion(false,ParseCareKitError.cantUnwrapSelf)
                return
            }
            
            self.compareDelete(self, parse: foundObject, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
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
    
    
    open func copyCareKit(_ taskAny: OCKAnyTask, clone:Bool, completion: @escaping(Task?) -> Void){
        
        guard let _ = PFUser.current(),
            let task = taskAny as? OCKTask else{
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
        
        self.previousVersionUUID = task.previousVersionUUID
        self.nextVersionUUID = task.nextVersionUUID
        self.carePlanUUID = task.carePlanUUID
        
        //Link versions and related classes
        self.findTask(self.previousVersionUUID){ [weak self]
            previousTask in
            
            guard let self = self else{
                completion(nil)
                return
            }
            
            self.previousVersion = previousTask
            
            //Fix doubly linked list if it's broken in the cloud
            if self.previousVersion != nil{
                if self.previousVersion!.nextVersion == nil{
                    if self.previousVersion!.store == nil{
                        self.previousVersion!.store = self.store
                    }
                    self.previousVersion!.nextVersion = self
                }
            }
            
            self.findTask(self.nextVersionUUID){ [weak self]
                nextTask in
                
                guard let self = self else{
                    completion(nil)
                    return
                }
                
                self.nextVersion = nextTask
                
                //Fix doubly linked list if it's broken in the cloud
                if self.nextVersion != nil{
                    if self.nextVersion!.previousVersion == nil{
                        if self.nextVersion!.store == nil{
                            self.nextVersion!.store = self.store
                        }
                        self.nextVersion!.previousVersion = self
                    }
                }
                
                guard let carePlanUUID = self.carePlanUUID else{
                    //Finished if there's no CarePlan, otherwise see if it's in the cloud
                    completion(self)
                    return
                }
                
                self.findCarePlan(carePlanUUID){ [weak self]
                    carePlan in
                    
                    guard let self = self else{
                        completion(nil)
                        return
                    }
                    
                    self.currentCarePlan = carePlan
                    guard let carePlan = self.currentCarePlan else{
                        completion(self)
                        return
                    }
                    if carePlan.store == nil{
                        carePlan.store = self.store
                    }
                    completion(self)
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

