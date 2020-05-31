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

    @NSManaged public var taskOccurrenceIndex:Int
    @NSManaged public var values:[OutcomeValue]
    @NSManaged var task:Task?
    @NSManaged var taskUUIDString:String?
    @NSManaged var date:Date?
    
    public internal(set) var taskUUID:UUID? {
        get {
            if task != nil{
                return UUID(uuidString: task!.uuid)
            }else if taskUUIDString != nil {
                return UUID(uuidString: taskUUIDString!)
            }else{
                return nil
            }
        }
        set{
            taskUUIDString = newValue?.uuidString
            if newValue?.uuidString != task?.uuid{
                task = nil
            }
        }
    }
    
    public var currentTask: Task?{
        get{
            return task
        }
        set{
            task = newValue
            taskUUIDString = newValue?.uuid
        }
    }
    
    public static func parseClassName() -> String {
        return kPCKOutcomeClassKey
    }

    public convenience init(careKitEntity: OCKAnyOutcome, completion: @escaping(PCKObject?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, clone: true, completion: completion)
    }
    
    public func new() -> PCKSynchronized {
        return Outcome()
    }
    
    public func new(with careKitEntity: OCKEntity, completion: @escaping(PCKSynchronized?)-> Void){
        
        switch careKitEntity {
        case .outcome(let entity):
            let newClass = Outcome()
            newClass.copyCareKit(entity, clone: true){
                _ in
                completion(newClass)
            }
        default:
            print("Error in \(parseClassName).new(with:). The wrong type of entity was passed \(careKitEntity)")
            completion(nil)
        }
    }
    
    open func addToCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
            
        guard let _ = PFUser.current() else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Make wall.logicalClock level entities compatible with KnowledgeVector by setting it's initial .logicalClock to 0
        if !usingKnowledgeVector{
            self.logicalClock = 0
        }
        
        //Check to see if already in the cloud
        let query = Outcome.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: self.uuid)
        //query.whereKey(kPCKObjectEntityIdKey, equalTo: self.entityId)
        query.includeKeys([kPCKOutcomeTaskKey,kPCKOutcomeValuesKey,kPCKObjectNotesKey])
        query.getFirstObjectInBackground(){
            (object, error) in
            
            guard let foundObject = object as? Outcome else{
                guard let parseError = error as NSError? else{
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).addToCloud(). \(String(describing: error?.localizedDescription))")
                    completion(false,error)
                    return
                }
                
                switch parseError.code{
                    case 1,101: //1 - this column hasn't been added. 101 - Query returned no results
                        self.save(self, completion: completion)
                default:
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).addToCloud(). \(String(describing: error?.localizedDescription))")
                    completion(false,error)
                }
                return
            }
            
            self.compareUpdate(foundObject, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
        }
    }
    
    open func updateCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        
        guard let _ = PFUser.current() else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if this entity is already in the Cloud, but not matched locally
        let query = Outcome.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: self.uuid)
        //query.whereKey(kPCKObjectEntityIdKey, equalTo: self.entityId)
        query.includeKeys([kPCKOutcomeTaskKey,kPCKOutcomeValuesKey,kPCKObjectNotesKey])
        query.getFirstObjectInBackground(){
            (object, error) in
            
            guard let foundObject = object as? Outcome else{
                guard let parseError = error as NSError? else{
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).updateCloud(). \(String(describing: error?.localizedDescription))")
                    completion(false,error)
                    return
                }
                
                switch parseError.code{
                    case 1,101: //1 - this column hasn't been added. 101 - Query returned no results
                        self.save(self, completion: completion)
                default:
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).updateCloud(). \(String(describing: error?.localizedDescription))")
                    completion(false,error)
                }
                return
            }
            
            self.compareUpdate(foundObject, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
        }
    }
    
    open func deleteFromCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        //Handled with update, marked for deletion
        completion(true,nil)
        /*
        guard let _ = PFUser.current() else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
                
        //Get latest item from the Cloud to compare against
        let query = Outcome.query()!
        //query.whereKey(kPCKObjectEntityIdKey, equalTo: self.entityId)
        query.whereKey(kPCKObjectUUIDKey, equalTo: self.uuid)
        query.includeKeys([kPCKOutcomeValuesKey,kPCKObjectNotesKey])
        query.getFirstObjectInBackground(){
            (object, error) in
            guard let foundObject = object as? Outcome else{
                //This was tombstoned, but never reached the cloud, no need to do anything
                completion(true,nil)
                return
            }
            guard let local = self.convertToCareKit() else{
                completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                return
            }
            
            foundObject.copyCareKit(local, clone: true){
                tombstoned in
                tombstoned?.saveInBackground(block: completion)
            }
            //self.compareUpdate(foundObject, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
        }*/
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
    
    public func pushRevision(_ overwriteRemote: Bool, cloudClock: Int, completion: @escaping (Error?) -> Void){
        
        self.logicalClock = cloudClock //Stamp Entity
        
        if self.createdDate != nil && self.updatedDate != nil{
            self.addToCloud(true, overwriteRemote: overwriteRemote){
                (success,error) in
                if success{
                    completion(nil)
                }else{
                    completion(error)
                }
            }
        }else{
            self.tombstsone(){
                (success,error) in
                if success{
                    completion(nil)
                }else{
                    completion(error)
                }
            }
        }
    }
    
    public func tombstsone(_ completion: @escaping(Bool,Error?) -> Void){
        
        guard let _ = PFUser.current() else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
                
        //Get latest item from the Cloud to compare against
        let query = Outcome.query()!
        //query.whereKey(kPCKObjectEntityIdKey, equalTo: self.entityId)
        query.whereKey(kPCKObjectUUIDKey, equalTo: self.uuid)
        query.includeKeys([kPCKOutcomeValuesKey,kPCKObjectNotesKey])
        query.getFirstObjectInBackground(){
            (object, error) in
            
            guard let foundObject = object as? Outcome else{
                guard let parseError = error as NSError? else{
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).tombstsone(). \(String(describing: error?.localizedDescription))")
                    completion(false,error)
                    return
                }
                
                switch parseError.code{
                    case 1,101: //1 - this column hasn't been added. 101 - Query returned no results
                        //This was tombstoned, but never reached the cloud, upload it now
                        self.saveInBackground(block: completion)
                        completion(true,nil)
                default:
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).tombstsone(). \(String(describing: error?.localizedDescription))")
                    completion(false,error)
                }
                return
            }
            
            foundObject.copy(self)
            foundObject.saveInBackground(block: completion)
        }
        
    }
    
    open override func copy(_ parse: PCKObject){
        super.copy(parse)
        guard let parse = parse as? Outcome else{return}
        self.taskOccurrenceIndex = parse.taskOccurrenceIndex
        self.values = parse.values
        self.currentTask = parse.currentTask
        self.taskUUID = parse.taskUUID
    }
        
    open func copyCareKit(_ outcomeAny: OCKAnyOutcome, clone: Bool, completion: @escaping(Outcome?) -> Void){
        
        guard let _ = PFUser.current(),
            let outcome = outcomeAny as? OCKOutcome else{
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
        self.source = outcome.source
        self.asset = outcome.asset
        self.timezoneIdentifier = outcome.timezone.abbreviation()!
        self.updatedDate = outcome.updatedDate
        self.userInfo = outcome.userInfo
        self.taskUUID = outcome.taskUUID
        self.deletedDate = outcome.deletedDate
        self.remoteID = outcome.remoteID
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
        
        guard let taskUUID = self.taskUUID else{
            //Finished if there's no Task, otherwise see if it's in the cloud
            completion(self)
            return
        }
        
        self.findTask(taskUUID){
            task in
            
            self.task = task
            
            guard let task = self.currentTask else{
                self.date = nil
                completion(self)
                return
            }
            
            let schedule = task.makeSchedule()
            self.date = schedule.event(forOccurrenceIndex: self.taskOccurrenceIndex)?.start
            
            completion(self)
        }
    }
        
    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit(fromCloud:Bool=true)->OCKOutcome?{
        
        guard let taskUUID = self.taskUUID else{
            print("Error in \(parseClassName).convertToCareKit(). Must contain task with a uuid in \(self)")
            return nil
        }
        
        //Create bare Entity and replace contents with Parse contents
        let outcomeValues = self.values.compactMap{$0.convertToCareKit()}
        var outcome = OCKOutcome(taskUUID: taskUUID, taskOccurrenceIndex: self.taskOccurrenceIndex, values: outcomeValues)
        
        if fromCloud{
            guard let decodedOutcome = decodedCareKitObject(outcome) else{
                print("Error in \(parseClassName). Couldn't decode entity \(self)")
                return nil
            }
            outcome = decodedOutcome
        }
        
        outcome.groupIdentifier = self.groupIdentifier
        outcome.tags = self.tags
        outcome.remoteID = self.remoteID
        outcome.source = self.source
        outcome.userInfo = self.userInfo
        outcome.taskOccurrenceIndex = self.taskOccurrenceIndex
        outcome.groupIdentifier = self.groupIdentifier
        outcome.asset = self.asset
        if let timeZone = TimeZone(abbreviation: self.timezoneIdentifier){
            outcome.timezone = timeZone
        }
        outcome.notes = self.notes?.compactMap{$0.convertToCareKit()}
        return outcome
    }
    
    public class func tagWithId(_ outcome: OCKOutcome)-> OCKOutcome?{
        
        //If this object has a createdDate, it's been stored locally before
        guard outcome.uuid != nil else{
            return nil
        }
        
        var mutableOutcome = outcome
       
        if mutableOutcome.tags != nil{
            if !mutableOutcome.tags!.contains(mutableOutcome.id){
                mutableOutcome.tags!.append(mutableOutcome.id)
                return mutableOutcome
            }
        }else{
            mutableOutcome.tags = [mutableOutcome.id]
            return mutableOutcome
        }
        
        return nil
    }
    
    open override func stampRelationalEntities(){
        super.stampRelationalEntities()
        self.values.forEach{$0.stamp(self.logicalClock)}
    }
}

