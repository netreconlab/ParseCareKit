//
//  Task.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 NetReconLab. All rights reserved.
//

import Parse
import CareKit


open class Task : PFObject, PFSubclassing, PCKEntity {

    //1 to 1 between Parse and CareStore
    @NSManaged public var asset:String?
    @NSManaged public var carePlan:CarePlan?
    @NSManaged public var carePlanId: String?
    @NSManaged public var groupIdentifier:String?
    @NSManaged public var impactsAdherence:Bool
    @NSManaged public var instructions:String?
    @NSManaged public var locallyCreatedAt:Date?
    @NSManaged public var locallyUpdatedAt:Date?
    @NSManaged public var notes:[Note]?
    @NSManaged public var source:String?
    @NSManaged public var tags:[String]?
    @NSManaged public var timezone:String
    @NSManaged public var title:String?
    @NSManaged public var uuid:String //maps to id
    
    @NSManaged public var elements:[ScheduleElement] //Use elements to generate a schedule. Each task will point to an array of schedule elements
    
    //SOSDatabase info
    @NSManaged public var sosDeliveredToDestinationAt:Date? //When was the outcome posted D2D
    
    
    public static func parseClassName() -> String {
        return kPCKTaskClassKey
    }
    
    public convenience init(careKitEntity: OCKAnyTask, storeManager: OCKSynchronizedStoreManager, completion: @escaping(PCKEntity?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, storeManager: storeManager, completion: completion)
    }
    
    open func updateCloudEventually(_ storeManager: OCKSynchronizedStoreManager){
        guard let _ = User.current(),
            let store = storeManager.store as? OCKStore else{
            return
        }
        
        store.fetchTask(withID: self.uuid, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let task):
                guard let remoteID = task.remoteID else{
                           
                    //Check to see if this entity is already in the Cloud, but not matched locally
                    let query = Task.query()!
                    query.whereKey(kPCKCarePlanIDKey, equalTo: task.id)
                    query.findObjectsInBackground{
                        (objects, error) in
                        guard let foundObject = objects?.first as? Task else{
                            return
                        }
                        self.compareUpdate(task, parse: foundObject, storeManager: storeManager)
                    }
                    return
                }
                       
                //Get latest item from the Cloud to compare against
                let query = Task.query()!
                query.whereKey(kPCKTaskObjectIdKey, equalTo: remoteID)
                query.findObjectsInBackground{
                    (objects, error) in
                    guard let foundObject = objects?.first as? Task else{
                        return
                    }
                    self.compareUpdate(task, parse: foundObject, storeManager: storeManager)
                }
            case .failure(let error):
                print("Error in Contact.addToCloudInBackground(). \(error)")
            }
        }
       
    }
    
    func compareUpdate(_ careKit: OCKTask, parse: Task, storeManager: OCKSynchronizedStoreManager){
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
                        print("Error in \(self.parseClassName).updateCloudEventually(). Error updating \(careKit)")
                    }else{
                        print("Successfully updated Task \(self) in the Cloud")
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
                storeManager.store.updateAnyTask(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                    result in
                    
                    switch result{
                        
                    case .success(_):
                        print("Successfully updated Task \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    case .failure(_):
                        print("Error updating Task \(updatedCarePlanFromCloud) from the Cloud to CareStore")
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
        let query = Task.query()!
        query.whereKey(kPCKTaskIdKey, equalTo: self.uuid)
        query.findObjectsInBackground{
            (objects, error) in
            guard let foundObject = objects?.first as? Task else{
                return
            }
            self.compareDelete(foundObject, storeManager: storeManager)
        }
    }
    
    func compareDelete(_ parse: Task, storeManager: OCKSynchronizedStoreManager){
        guard let careKitLastUpdated = self.locallyUpdatedAt,
            let cloudUpdatedAt = parse.locallyUpdatedAt else{
            return
        }
        if cloudUpdatedAt <= careKitLastUpdated{
            parse.deleteInBackground{
                (success, error) in
                if !success{
                    guard let error = error else{return}
                    print("Error in Task.deleteFromCloudEventually(). \(error)")
                }else{
                    print("Successfully deleted Task \(self) in the Cloud")
                }
            }
        }else {
            parse.convertToCareKit(storeManager){
                converted in
                //The updated version in the cloud is newer, local delete has already occured, so updated the device with the newer one from the cloud
                guard let updatedCarePlanFromCloud = converted else{
                    return
                }
                storeManager.store.updateAnyTask(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(_):
                        print("Successfully deleting Task \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    case .failure(_):
                        print("Error deleting Task \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    }
                }
            }
        }
    }
    
    open func addToCloudInBackground(_ storeManager: OCKSynchronizedStoreManager){
        guard let _ = User.current()else{
            return
        }
        
        //Check to see if already in the cloud
        let query = Task.query()!
        query.whereKey(kPCKTaskIdKey, equalTo: self.uuid)
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
                    self.saveAndCheckRemoteID(storeManager){_ in}
                }else{
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).addToCloudInBackground(). \(error.localizedDescription)")
                }
                return
            }
            
            //If object already in the Cloud, exit
            if foundObjects.count > 0{
                //Maybe this needs to be updated instead
                self.updateCloudEventually(storeManager)
            }else{
                self.saveAndCheckRemoteID(storeManager){_ in}
            }
        }
    }
    
    private func saveAndCheckRemoteID(_ storeManager: OCKSynchronizedStoreManager, completion: @escaping(Bool) -> Void){
        guard let store = storeManager.store as? OCKStore else{return}
        self.saveEventually{(success, error) in
            if success{
                print("Successfully saved \(self) in Cloud.")
                //Need to save remoteId for this and all relational data
                store.fetchTask(withID: self.uuid, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(var mutableEntity):
                        if mutableEntity.remoteID == nil{
                            mutableEntity.remoteID = self.objectId
                            storeManager.store.updateAnyTask(mutableEntity){
                                result in
                                switch result{
                                case .success(let updatedTask):
                                    print("Updated remoteID of task \(updatedTask)")
                                    completion(true)
                                case .failure(let error):
                                    print("Error in \(self.parseClassName).addToCloudInBackground() updating remoteID. \(error)")
                                    completion(false)
                                }
                            }
                        }else{
                            if mutableEntity.remoteID! != self.objectId{
                                print("Error in \(self.parseClassName).saveAndCheckRemoteID(). remoteId \(mutableEntity.remoteID!) should equal (self.objectId)")
                                completion(false)
                            }
                        }
                    case .failure(let error):
                        print("Error in Contact.addToCloudInBackground(). \(error)")
                        completion(false)
                    }
                }
            }else{
                guard let error = error else{
                    completion(false)
                    return
                }
                print("Error in \(self.parseClassName).addToCloudInBackground(). \(error)")
                completion(false)
            }
        }
    }
    
    open func copyCareKit(_ taskAny: OCKAnyTask, storeManager: OCKSynchronizedStoreManager, completion: @escaping(Task?) -> Void){
        
        guard let _ = User.current(),
            let task = taskAny as? OCKTask else{
            completion(nil)
            return
        }
        
        self.uuid = task.id
        self.groupIdentifier = task.groupIdentifier
        self.title = task.title
        self.impactsAdherence = task.impactsAdherence
        self.tags = task.tags
        self.source = task.source
        self.asset = task.asset
        self.timezone = task.timezone.abbreviation()!
    
        self.locallyUpdatedAt = task.updatedDate
        
        //Only copy this over if the Local Version is older than the Parse version
        if self.locallyCreatedAt == nil {
            self.locallyCreatedAt = task.createdDate
        } else if self.locallyCreatedAt != nil && task.createdDate != nil{
            if task.createdDate! < self.locallyCreatedAt!{
                self.locallyCreatedAt = task.createdDate
            }
        }
        
        Note.convertCareKitArrayToParse(task.notes, storeManager: storeManager){
            copiedNotes in
            self.notes = copiedNotes
            //Elements don't have have id's and tags when initially created, need to add them
            let elements = task.schedule.elements.map{(element) -> OCKScheduleElement in
                var newElement = element
                if newElement.userInfo == nil{
                    newElement.userInfo = [kPCKScheduleElementUserInfoIDKey: UUID.init().uuidString]
                }else{
                    if newElement.userInfo![kPCKScheduleElementUserInfoIDKey] == nil{
                        newElement.userInfo![kPCKScheduleElementUserInfoIDKey] = UUID.init().uuidString
                    }
                }
                if let tags = newElement.tags {
                    if !tags.contains(task.id){
                        newElement.tags!.append(task.id)
                    }
                }else{
                    newElement.tags = [task.id]
                }
                return newElement
            }
            
            ScheduleElement.convertCareKitArrayToParse(elements, storeManager: storeManager){
                copiedScheduleElements in
                self.elements = copiedScheduleElements
                
                guard let carePlanLocalID = task.carePlanID else{
                    completion(self)
                    return
                }
                
                var query = OCKCarePlanQuery()
                query.versionIDs = [carePlanLocalID]
                storeManager.store.fetchAnyCarePlans(query: query, callbackQueue: .global(qos: .background)){
                    result in
                    
                    switch result{
                    case .success(let plan):
                        
                        guard let foundPlan = plan.first else{
                            completion(nil)
                            return
                        }
                        self.carePlanId = foundPlan.id
                        guard let carePlanRemoteID = foundPlan.remoteID else{
                            let carePlanQuery = CarePlan.query()!
                            carePlanQuery.whereKey(kPCKCarePlanIDKey, equalTo: foundPlan.id)
                            carePlanQuery.findObjectsInBackground(){
                                (objects, error) in
                                
                                guard let carePlanFound = objects?.first as? CarePlan else{
                                    completion(self)
                                    return
                                }
                                
                                self.carePlan = carePlanFound
                                completion(self)
                            }
                            return
                        }
                        
                        self.carePlan = CarePlan(withoutDataWithObjectId: carePlanRemoteID)
                        completion(self)
                        /*
                        let copiedCarePlan = CarePlan()
                        copiedCarePlan.copyCareKit(foundPlan){
                            copied in
                            
                            guard let copiedCarePlan = copied else{
                                completion(nil)
                                return
                            }
                            
                            self.carePlan = copiedCarePlan
                            self.author = copiedCarePlan.author //If this task is tied to a carePlan, then the author of the CarePlan is the author of the task
                            
                            completion(self)
                        }*/
                    case .failure(_):
                        print("")
                        completion(nil)
                    }
                }
                
                completion(self)
                
            }
        }
        
        
        
        
        /*
        guard let currentCarePlan = carePlan else{
            
            guard let carePlanLocalID = task.carePlanID else{
                completion(self)
                return
            }
            
            let store = DataStoreManager.shared.store
            
            var query = OCKCarePlanQuery()
            query.versionIDs = [carePlanLocalID]
            
            store.fetchCarePlans(query: query, callbackQueue: .global(qos: .background)){
                result in
                
                switch result{
                case .success(let plan):
                    
                    guard let foundPlan = plan.first else{
                        completion(nil)
                        return
                    }
                    
                    let copiedCarePlan = CarePlan()
                    copiedCarePlan.copyCareKit(foundPlan){
                        copied in
                        
                        guard let copiedCarePlan = copied else{
                            completion(nil)
                            return
                        }
                        
                        self.carePlan = copiedCarePlan
                        self.author = copiedCarePlan.author
                        completion(self)
                    }
                case .failure(_):
                    print("")
                    completion(nil)
                }
            }
            
            completion(self)
            return
        }
        
        let copiedCarePlan = CarePlan()
        copiedCarePlan.copyCareKit(currentCarePlan){
            copied in
            
            guard let copiedCarePlan = copied else{
                completion(nil)
                return
            }
            
            self.carePlan = copiedCarePlan
            self.author = copiedCarePlan.author
            completion(self)
        }*/
        
        
        /*
        if let notes = task.notes {
            var noteIDs = [String]()
            notes.forEach{
                //Ignore notes who don't have a ID
                guard let noteID = $0.userInfo?[kPCKNoteUserInfoIDKey] else{
                    return
                }
                
                noteIDs.append(noteID)
            }
        }*/
        
        //self.schedule = Schedule()
        
        //schedule!.co
        
    }
    
    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit(_ storeManager: OCKSynchronizedStoreManager, completion: @escaping(OCKTask?) -> Void){
        
        let careKitScheduleElements = self.elements.compactMap{$0.convertToCareKit()}
        let schedule = OCKSchedule(composing: careKitScheduleElements)
        
        var task = OCKTask(id: self.uuid, title: self.title, carePlanID: nil, schedule: schedule)
        task.groupIdentifier = self.groupIdentifier
        task.tags = self.tags
        task.source = self.source
        task.instructions = self.instructions
        task.impactsAdherence = self.impactsAdherence
        task.groupIdentifier = self.groupIdentifier
        task.asset = self.asset
        if let timeZone = TimeZone(abbreviation: self.timezone){
            task.timezone = timeZone
        }
        task.notes = self.notes?.compactMap{$0.convertToCareKit()}
        task.remoteID = self.objectId
        
        guard let parseCarePlan = self.carePlan,
            let store = storeManager.store as? OCKStore else{
            completion(task)
            return
        }
        
        //Need to grab the local CarePlan ID from the CarePlanStore in order to link locally
        store.fetchCarePlan(withID: parseCarePlan.uuid){
            result in
            
            switch result{
            case .success(let foundPlan):
                task.carePlanID = foundPlan.localDatabaseID
                completion(task)
                /*
                guard let taskID = task.localDatabaseID,
                    let query = OutcomeValue.query() else{
                    return
                }
                
                
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

