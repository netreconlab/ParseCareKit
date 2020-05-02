//
//  Outcomes.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/14/20.
//  Copyright © 2020 NetReconLab. All rights reserved.
//

import Parse
import CareKit

public protocol PCKAnyOutcome: PCKEntity {
    func updateCloudEventually(_ outcome: OCKAnyOutcome, storeManager: OCKSynchronizedStoreManager)
    func deleteFromCloudEventually(_ outcome: OCKAnyOutcome, storeManager: OCKSynchronizedStoreManager)
}

open class Outcome: PFObject, PFSubclassing, PCKAnyOutcome {

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
    
    open func updateCloudEventually(_ outcome: OCKAnyOutcome, storeManager: OCKSynchronizedStoreManager){
        
        guard let _ = User.current(),
            let castedOutcome = outcome as? OCKOutcome else{
            return
        }
        
        guard let remoteID = castedOutcome.remoteID else{
            //Check to see if this entity is already in the Cloud, but not matched locally
            let query = Outcome.query()!
            query.whereKey(kPCKOutcomeCareKitIdKey, equalTo: outcome.id)
            query.includeKey(kPCKOutcomeTaskKey)
            query.findObjectsInBackground{
                (objects, error) in
                
                guard let foundObject = objects?.first as? Outcome else{
                    return
                }
                var mutableOutcome = castedOutcome
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
            self.compareUpdate(castedOutcome, parse: foundObject, storeManager: storeManager)
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
                parse.saveEventually{
                    (success,error) in
                    
                    if !success{
                        guard let error = error else{return}
                        print("Error in \(self.parseClassName).updateCloudEventually(). \(error)")
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
    
    open func deleteFromCloudEventually(_ outcome: OCKAnyOutcome, storeManager: OCKSynchronizedStoreManager){
        
        guard let _ = User.current(),
            let castedOutcome = outcome as? OCKOutcome else{
            return
        }
        
        guard let remoteID = castedOutcome.remoteID else{
            
            //Check to see if this entity is already in the Cloud, but not matched locally
            let query = Outcome.query()!
            query.whereKey(kPCKOutcomeCareKitIdKey, equalTo: outcome.id)
            query.includeKey(kPCKOutcomeTaskIDKey)
            query.findObjectsInBackground{
                (objects, error) in
                guard let foundObject = objects?.first as? Outcome else{
                    return
                }
                self.compareDelete(castedOutcome, parse: foundObject, storeManager: storeManager)
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
            self.compareDelete(castedOutcome, parse: foundObject, storeManager: storeManager)
        }
    }
    
    func compareDelete(_ careKit: OCKOutcome, parse: Outcome, storeManager: OCKSynchronizedStoreManager){
        guard let careKitLastUpdated = careKit.updatedDate,
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
        let careKitQuery = OCKOutcomeQuery(id: self.careKitId)
        storeManager.store.fetchAnyOutcome(query: careKitQuery, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let fetchedOutcome):
                guard let outcome = fetchedOutcome as? OCKOutcome else{return}
                //Check to see if already in the cloud
                let query = Outcome.query()!
                query.whereKey(kPCKOutcomeCareKitIdKey, equalTo: outcome.id)
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
                            self.saveAndCheckRemoteID(outcome, storeManager: storeManager)
                        }else{
                            //There was a different issue that we don't know how to handle
                            print("Error in \(self.parseClassName).addToCloudInBackground(). \(error.localizedDescription)")
                        }
                        return
                    }
                    //If object already in the Cloud, exit
                    if foundObjects.count > 0{
                        //Maybe this needs to be updated instead
                        self.updateCloudEventually(outcome, storeManager: storeManager)
                        return
                    }
                    self.saveAndCheckRemoteID(outcome, storeManager: storeManager)
                }
            case .failure(let error):
                print("Error in \(self.parseClassName).saveAndCheckRemoteID(). \(error)")
            }
        }
    }
    
    func saveAndCheckRemoteID(_ careKitEntity: OCKOutcome, storeManager: OCKSynchronizedStoreManager){
        self.saveEventually{(success, error) in
            if success{
                print("Successfully saved \(self) in Cloud.")
                //Need to save remoteId for this and all relational data
                var mutableOutcome = careKitEntity
                mutableOutcome.remoteID = self.objectId
                self.values.forEach{
                    for (index,value) in mutableOutcome.values.enumerated(){
                        guard let id = value.userInfo?[kPCKOutcomeValueUserInfoIDKey],
                            id == $0.uuid else{
                            continue
                        }
                        mutableOutcome.values[index].remoteID = $0.objectId
                    }
                }
                storeManager.store.updateAnyOutcome(mutableOutcome){
                    result in
                    switch result{
                    case .success(let updatedContact):
                        print("Updated remoteID of \(self.parseClassName): \(updatedContact)")
                    case .failure(let error):
                        print("Error updating remoteID. \(error)")
                    }
                }
            }else{
                guard let error = error else{
                    return
                }
                print("Error in CarePlan.addToCloudInBackground(). \(error)")
            }
        }
    }
    
    open func copyCareKit(_ outcomeAny: OCKAnyOutcome, storeManager: OCKSynchronizedStoreManager, completion: @escaping(Outcome?) -> Void){
        
        guard let _ = User.current(),
            let outcome = outcomeAny as? OCKOutcome else{
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
                storeManager.store.fetchAnyTasks(query: query, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(let anyTask):
                        
                        guard let task = anyTask.first as? OCKTask else{
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
        
        guard let task = self.task else{
            completion(nil)
            return
        }
        
        //Outcomes can only be converted if they have a relationship with a task locally
        storeManager.store.fetchAnyTask(withID: task.uuid){
            result in
            
            switch result{
            case .success(let fetchedTask):
                
                guard let task = fetchedTask as? OCKTask,
                    let taskID = task.localDatabaseID else{
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

