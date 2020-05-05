//
//  Outcomes.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/14/20.
//  Copyright © 2020 NetReconLab. All rights reserved.
//

import Parse
import CareKit


open class Outcome: PFObject, PFSubclassing, PCKEntity {

    //1 to 1 between Parse and CareStore
    @NSManaged public var asset:String?
    @NSManaged public var careKitId:String //maps to id
    @NSManaged public var groupIdentifier:String?
    @NSManaged public var locallyCreatedAt:Date?
    @NSManaged public var locallyUpdatedAt:Date?
    @NSManaged public var notes:[Note]?
    @NSManaged public var tags:[String]?
    @NSManaged public var task:Task?
    @NSManaged public var taskId:String
    @NSManaged public var taskOccurrenceIndex:Int
    @NSManaged public var timezone:String
    @NSManaged public var source:String?
    @NSManaged public var values:[OutcomeValue]
    
    //Not 1 tot 1, UserInfo fields in CareStore
    @NSManaged public var uuid:String //maps to id
    
    public static func parseClassName() -> String {
        return kPCKOutcomeClassKey
    }

    public convenience init(careKitEntity: OCKAnyOutcome, storeManager: OCKSynchronizedStoreManager, completion: @escaping(PCKEntity?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, storeManager: storeManager, completion: completion)
    }
    
    open func updateCloudEventually(_ storeManager: OCKSynchronizedStoreManager){
        
        guard let _ = User.current(),
            let store = storeManager.store as? OCKStore else{
            return
        }
        
        var careKitQuery = OCKOutcomeQuery()
        careKitQuery.tags = [self.uuid]
        careKitQuery.sortDescriptors = [.date(ascending: false)]
        store.fetchOutcome(query: careKitQuery, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let outcome):
                guard let remoteID = outcome.remoteID else{
                    //Check to see if this entity is already in the Cloud, but not matched locally
                    let query = Outcome.query()!
                    query.whereKey(kPCKOutcomeIdKey, equalTo: self.uuid)
                    query.includeKey(kPCKOutcomeTaskKey)
                    query.findObjectsInBackground{
                        (objects, error) in
                        
                        guard let foundObject = objects?.first as? Outcome else{
                            return
                        }
                        var mutableOutcome = outcome
                        mutableOutcome.remoteID = foundObject.objectId
                        self.compareUpdate(mutableOutcome, parse: foundObject, storeManager: storeManager)
                    }
                    return
                }
                
                //Get latest item from the Cloud to compare against
                let query = Outcome.query()!
                query.whereKey(kPCKOutcomeObjectIdKey, equalTo: remoteID)
                query.includeKey(kPCKOutcomeTaskKey)
                query.findObjectsInBackground{
                    (objects, error) in
                    guard let foundObject = objects?.first as? Outcome else{
                        return
                    }
                    self.compareUpdate(outcome, parse: foundObject, storeManager: storeManager)
                }
            case .failure(let error):
                print("Error in \(self.parseClassName).updateCloudEventually(). \(error)")
            }
        }
    }
    
    func compareUpdate(_ careKit: OCKOutcome, parse: Outcome, storeManager: OCKSynchronizedStoreManager){
        guard let careKitLastUpdated = careKit.updatedDate,
            let cloudUpdatedAt = parse.locallyUpdatedAt else{
            return
        }
        
        if cloudUpdatedAt < careKitLastUpdated{
            parse.copyCareKit(careKit, storeManager: storeManager){_ in
                //An update may occur when Internet isn't available, try to update at some point
                parse.saveAndCheckRemoteID(storeManager){
                    (success) in
                    
                    if !success{
                        print("Error in \(self.parseClassName).updateCloudEventually(). Couldn't update in cloud: \(careKit)")
                    }else{
                        print("Successfully updated \(self.parseClassName) \(self) in the Cloud")
                    }
                }
            }
            
        }else if cloudUpdatedAt > careKitLastUpdated {
            parse.convertToCareKit(storeManager){
                converted in
                
                //The cloud version is newer than local, update the local version instead
                guard let updatedCarePlanFromCloud = converted else{
                    return
                }
                storeManager.store.updateAnyOutcome(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                    result in
                    
                    switch result{
                        
                    case .success(_):
                        print("Successfully updated \(self.parseClassName) \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    case .failure(_):
                        print("Error updating \(self.parseClassName) \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    }
                }
            }
        }
    }
    
    open func deleteFromCloudEventually(_ storeManager: OCKSynchronizedStoreManager){
        
        guard let _ = User.current() else{
            return
        }
                
        //Get latest item from the Cloud to compare against
        let query = Outcome.query()!
        query.whereKey(kPCKOutcomeIdKey, equalTo: self.uuid)
        query.includeKey(kPCKOutcomeTaskKey)
        query.findObjectsInBackground{
            (objects, error) in
            guard let foundObject = objects?.first as? Outcome else{
                return
            }
            self.compareDelete(foundObject, storeManager: storeManager)
        }
    }
    
    func compareDelete(_ parse: Outcome, storeManager: OCKSynchronizedStoreManager){
        guard let careKitLastUpdated = self.locallyUpdatedAt,
            let cloudUpdatedAt = parse.locallyUpdatedAt else{
            return
        }
        
        if cloudUpdatedAt <= careKitLastUpdated{
            parse.deleteInBackground{
                (success, error) in
                if !success{
                    guard let error = error else{return}
                    print("Error in \(self.parseClassName).deleteFromCloudEventually(). \(error)")
                }else{
                    print("Successfully deleted \(self.parseClassName) \(self) in the Cloud")
                }
            }
        }else {
            parse.convertToCareKit(storeManager){
                converted in
                //The updated version in the cloud is newer, local delete has already occured, so updated the device with the newer one from the cloud
                guard let updatedCarePlanFromCloud = converted else{
                    return
                }
                storeManager.store.updateAnyOutcome(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(_):
                        print("Successfully deleting \(self.parseClassName) \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    case .failure(_):
                        print("Error deleting \(self.parseClassName) \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    }
                }
            }
        }
    }
    
    open func addToCloudInBackground(_ storeManager: OCKSynchronizedStoreManager){
            
        guard let _ = User.current() else{
            return
        }
        
        //Check to see if already in the cloud
        let query = Outcome.query()!
        query.whereKey(kPCKOutcomeIdKey, equalTo: self.uuid)
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
                    self.saveAndCheckRemoteID(storeManager){_ in }
                }else{
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).addToCloudInBackground(). \(error.localizedDescription)")
                }
                return
            }
            
            if foundObjects.count > 0{
                //Maybe this needs to be updated instead added
                self.updateCloudEventually(storeManager)
                
            }else{
                //This is the first object, make sure to save it
                self.saveAndCheckRemoteID(storeManager){_ in }
            }
            
        }
    }
    
    func saveAndCheckRemoteID(_ storeManager: OCKSynchronizedStoreManager, completion: @escaping(Bool) -> Void){
        guard let store = storeManager.store as? OCKStore else {return}
        
        self.saveEventually{(success, error) in
            if success{
                print("Successfully saved \(self) in Cloud.")
                
                var careKitQuery = OCKOutcomeQuery()
                careKitQuery.tags = [self.uuid]
                store.fetchOutcome(query: careKitQuery, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(var mutableOutcome):
                        var needToUpdate = false
                        if mutableOutcome.remoteID == nil{
                            mutableOutcome.remoteID = self.objectId
                            needToUpdate = true
                        }else{
                            if mutableOutcome.remoteID! != self.objectId!{
                                print("Error in \(self.parseClassName).saveAndCheckRemoteID(). remoteId \(mutableOutcome.remoteID!) should equal (self.objectId)")
                                completion(false)
                                return
                            }
                        }
                        
                        //UUIDs are custom, make sure to add them as a tag for querying
                        if let outcomeTags = mutableOutcome.tags{
                            if !outcomeTags.contains(self.uuid){
                                mutableOutcome.tags!.append(self.uuid)
                                needToUpdate = true
                            }
                        }else{
                            mutableOutcome.tags = [self.uuid]
                            needToUpdate = true
                        }
                        
                        self.values.forEach{
                            for (index,value) in mutableOutcome.values.enumerated(){
                                guard let id = value.userInfo?[kPCKOutcomeValueUserInfoIDKey],
                                    id == $0.uuid else{
                                    continue
                                }
                                
                                if mutableOutcome.values[index].remoteID == nil{
                                    mutableOutcome.values[index].remoteID = $0.objectId
                                    needToUpdate = true
                                }
                                
                                guard let updatedValue = $0.compareUpdate(mutableOutcome.values[index], parse: $0, storeManager: storeManager) else {continue}
                                mutableOutcome.values[index] = updatedValue
                                needToUpdate = true
                            }
                        }
                        
                        if needToUpdate{
                            store.updateOutcome(mutableOutcome){
                                result in
                                switch result{
                                case .success(let updatedContact):
                                    print("Updated remoteID of \(self.parseClassName): \(updatedContact)")
                                    completion(true)
                                case .failure(let error):
                                    print("Error updating remoteID. \(error)")
                                    completion(false)
                                }
                            }
                        }else{
                            completion(true)
                        }
                    case .failure(let error):
                        print("Error in \(self.parseClassName).saveAndCheckRemoteID(). \(error)")
                        
                        if error.localizedDescription.contains("matching"){
                            //Need to find and save Outcome with correct tag, only way to do this is search all outcomes
                            var query = OCKOutcomeQuery()
                            query.sortDescriptors = [.date(ascending: false)]
                            store.fetchOutcomes(query: query, callbackQueue: .global(qos: .background)){
                                result in
                                
                                switch result{
                                case .success(let foundOutcomes):
                                    let matchingOutcomes = foundOutcomes.filter{
                                        guard let foundUuid = $0.userInfo?[kPCKOutcomeUserInfoIDKey] else{return false}
                                        if foundUuid == self.uuid{
                                            return true
                                        }
                                        return false
                                    }
                                    
                                    if matchingOutcomes.count > 1{
                                        print("Warning in \(self.parseClassName).saveAndCheckRemoteID(), found \(matchingOutcomes.count) matching uuid \(self.uuid). There should only be 1")
                                    }

                                    guard var outcomeToUse = matchingOutcomes.first else{
                                        print("Error in \(self.parseClassName).saveAndCheckRemoteID(), found no matching Outcomes with uuid \(self.uuid). There should be 1")
                                        completion(false)
                                        return
                                    }
                                    //Fix tag
                                    outcomeToUse.tags = [self.uuid]
                                    store.updateOutcome(outcomeToUse, callbackQueue: .global(qos: .background)){
                                        result in
                                        
                                        switch result{
                                        case .success(let foundOutcome):
                                            print("Fixed tag for \(foundOutcome)")
                                        case .failure(let error):
                                            print("Error fixing tag on \(outcomeToUse). \(error)")
                                        }
                                        completion(false)
                                    }
                                case .failure(let error):
                                    print("Error updating remoteID. \(error)")
                                    completion(false)
                                }
                            }
                        }else{
                            completion(false)
                        }
                        
                    }
                }
            }else{
                guard let error = error else{
                    completion(false)
                    return
                }
                print("Error in CarePlan.addToCloudInBackground(). \(error)")
                completion(false)
            }
        }
    }
    
    open func copyCareKit(_ outcomeAny: OCKAnyOutcome, storeManager: OCKSynchronizedStoreManager, completion: @escaping(Outcome?) -> Void){
        
        guard let _ = User.current(),
            let outcome = outcomeAny as? OCKOutcome,
            let store = storeManager.store as? OCKStore else{
            completion(nil)
            return
        }

        self.careKitId = outcome.id
        self.taskOccurrenceIndex = outcome.taskOccurrenceIndex
        self.groupIdentifier = outcome.groupIdentifier
        self.tags = outcome.tags
        self.source = outcome.source
        self.asset = outcome.asset
        self.timezone = outcome.timezone.abbreviation()!
        self.locallyUpdatedAt = outcome.updatedDate
        
        guard let id = outcome.userInfo?[kPCKOutcomeUserInfoIDKey] else{
            print("Error in \(self.parseClassName).copyCareKit, missing \(kPCKOutcomeUserInfoIDKey) in outcome.userInfo ")
            return
        }
        self.uuid = id
        
        
        //Only copy this over if the Local Version is older than the Parse version
        if self.locallyCreatedAt == nil {
            self.locallyCreatedAt = outcome.createdDate
        } else if self.locallyCreatedAt != nil && outcome.createdDate != nil{
            if outcome.createdDate! < self.locallyCreatedAt!{
                self.locallyCreatedAt = outcome.createdDate
            }
        }
        
        Note.convertCareKitArrayToParse(outcome.notes, storeManager: storeManager){
        copiedNotes in
            self.notes = copiedNotes
            
            OutcomeValue.convertCareKitArrayToParse(outcome.values, storeManager: storeManager){
                copiedValues in
                self.values = copiedValues
                //ID's are the same for related Plans
                var query = OCKTaskQuery()
                query.versionIDs = [outcome.taskID]
                store.fetchTasks(query: query, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(let anyTask):
                        
                        guard let task = anyTask.first else{
                            completion(nil)
                            return
                        }
                        
                        self.taskId = task.id
                        
                        guard let taskRemoteID = task.remoteID else{
                            
                            let taskQuery = Task.query()!
                            taskQuery.whereKey(kPCKCarePlanIDKey, equalTo: task.id)
                            taskQuery.findObjectsInBackground(){
                                (objects, error) in
                                
                                guard let taskFound = objects?.first as? Task else{
                                    completion(self)
                                    return
                                }
                                
                                self.task = taskFound
                                completion(self)
                            }
                            return
                        }
                        
                        self.task = Task(withoutDataWithObjectId: taskRemoteID)
                        completion(self)
                        
                    case .failure(_):
                        completion(nil)
                    }
                }
                
            }
            
        }
        
    }
    
    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit(_ storeManager: OCKSynchronizedStoreManager, completion: @escaping(OCKOutcome?) -> Void){
        
        guard let task = self.task,
         let store = storeManager.store as? OCKStore else{
            completion(nil)
            return
        }
        
        //Outcomes can only be converted if they have a relationship with a task locally
        store.fetchTask(withID: task.uuid){
            result in
            
            switch result{
            case .success(let fetchedTask):
                
                guard let taskID = fetchedTask.localDatabaseID else{
                    completion(nil)
                    return
                }
                
                let outcomeValues = self.values.compactMap{$0.convertToCareKit()}
                
                var outcome = OCKOutcome(taskID: taskID, taskOccurrenceIndex: self.taskOccurrenceIndex, values: outcomeValues)
                
                outcome.groupIdentifier = self.groupIdentifier
                outcome.tags = self.tags
                outcome.source = self.source
                outcome.userInfo = [kPCKOutcomeUserInfoIDKey: self.uuid] //For some reason, outcome doesn't let you set the current one. Assuming this is a bug in the current CareKit
                
                outcome.taskOccurrenceIndex = self.taskOccurrenceIndex
                outcome.groupIdentifier = self.groupIdentifier
                outcome.asset = self.asset
                if let timeZone = TimeZone(abbreviation: self.timezone){
                    outcome.timezone = timeZone
                }
                outcome.notes = self.notes?.compactMap{$0.convertToCareKit()}
                outcome.remoteID = self.objectId
                completion(outcome)
                
                /*
                let query = OutcomeValue.query()
                query.whereKey(kPCKOutcomeValueId, containsAllObjectsIn: self.values)
                query.order(byAscending: kPCKOutcomeValueIndex)
                
                query.findObjectsInBackground{
                    (objects, error) in
                    
                    guard let parseOutcomeValues = objects as? [OutcomeValue] else{
                        completion(nil)
                        return
                    }
                    
                    let outcomeValues = parseOutcomeValues.compactMap{
                        return $0.convertToCareKit()
                    }
                    
                    var outcome = OCKOutcome(taskID: taskID, taskOccurrenceIndex: self.taskOccurrenceIndex, values: outcomeValues)
                    
                    //outcome.taskID = OCKLocalVersionID(self.taskID)
                    outcome.groupIdentifier = self.groupIdentifier
                    outcome.tags = self.tags
                    outcome.source = self.source
                    outcome.userInfo?[kPCKOutcomeUserInfoIDKey] = self.id
                    
                    outcome.taskOccurrenceIndex = self.taskOccurrenceIndex
                    outcome.groupIdentifier = self.groupIdentifier
                    outcome.asset = self.asset
                    if let timeZone = TimeZone(abbreviation: self.timezone){
                        outcome.timezone = timeZone
                    }
                    
                    completion(outcome)
                }*/
                
            case .failure(_):
                completion(nil)
        
            }
        
        }
        
    }
}

