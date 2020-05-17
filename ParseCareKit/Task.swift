//
//  Task.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore


open class Task : PFObject, PFSubclassing, PCKSynchronizedEntity, PCKRemoteSynchronizedEntity {

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
    @NSManaged public var uuid:String
    @NSManaged public var nextVersionUUID:String?
    @NSManaged public var previousVersionUUID:String?
    @NSManaged public var elements:[ScheduleElement] //Use elements to generate a schedule. Each task will point to an array of schedule elements
    @NSManaged public var userInfo:[String:String]?
    
    //Not 1 to 1
    @NSManaged public var entityId:String //maps to id
    @NSManaged public var clock:Int
    
    //SOSDatabase info
    @NSManaged public var sosDeliveredToDestinationAt:Date? //When was the outcome posted D2D
    
    
    public static func parseClassName() -> String {
        return kPCKTaskClassKey
    }
    
    public convenience init(careKitEntity: OCKAnyTask, store: OCKAnyStoreProtocol, completion: @escaping(PCKSynchronizedEntity?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, clone: true, store: store, completion: completion)
    }
    
    open func updateCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = User.current(),
            let store = store as? OCKStore else{
            completion(false,nil)
            return
        }
        
        store.fetchTask(withID: self.entityId, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let task):
                guard let remoteID = task.remoteID else{
                           
                    //Check to see if this entity is already in the Cloud, but not matched locally
                    let query = Task.query()!
                    query.whereKey(kPCKTaskEntityIdKey, equalTo: task.id)
                    query.includeKeys([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKTaskNotesKey])
                    query.findObjectsInBackground{
                        (objects, error) in
                        guard let foundObject = objects?.first as? Task else{
                            completion(false,error)
                            return
                        }
                        self.compareUpdate(task, parse: foundObject, store: store, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
                    }
                    return
                }
                       
                //Get latest item from the Cloud to compare against
                let query = Task.query()!
                query.whereKey(kPCKTaskObjectIdKey, equalTo: remoteID)
                query.includeKeys([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKTaskNotesKey])
                query.findObjectsInBackground{
                    (objects, error) in
                    guard let foundObject = objects?.first as? Task else{
                        completion(false,error)
                        return
                    }
                    self.compareUpdate(task, parse: foundObject, store: store, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
                }
            case .failure(let error):
                print("Error in Contact.addToCloud(). \(error)")
                completion(false,nil)
            }
        }
       
    }
    
    func compareUpdate(_ careKit: OCKTask, parse: Task, store: OCKStore, usingKnowledgeVector:Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void){
        if !usingKnowledgeVector{
            guard let careKitLastUpdated = careKit.updatedDate,
                let cloudUpdatedAt = parse.locallyUpdatedAt else{
                completion(false,nil)
                return
            }
            if ((cloudUpdatedAt < careKitLastUpdated) || overwriteRemote){
                parse.copyCareKit(careKit, clone: overwriteRemote, store: store){_ in
                    //An update may occur when Internet isn't available, try to update at some point
                    parse.saveAndCheckRemoteID(store){
                        (success,error) in
                        
                        if !success{
                            print("Error in \(self.parseClassName).compareUpdate(). Error updating \(careKit)")
                        }else{
                            print("Successfully updated Task \(self) in the Cloud")
                        }
                        completion(success,nil)
                    }
                }
            }else if cloudUpdatedAt > careKitLastUpdated {
                //The cloud version is newer than local, update the local version instead
                guard let updatedCarePlanFromCloud = parse.convertToCareKit() else{
                    completion(false,nil)
                    return
                }
                store.updateAnyTask(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                    result in
                    
                    switch result{
                        
                    case .success(_):
                        print("Successfully updated Task \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                        completion(true,nil)
                    case .failure(let error):
                        print("Error updating Task \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                        completion(false,error)
                    }
                }
            }else{
                completion(true,nil)
            }
        }else{
            if ((self.clock > parse.clock) || overwriteRemote){
                parse.copyCareKit(careKit, clone: overwriteRemote, store: store){_ in
                    parse.clock = self.clock //Place stamp on this entity since it's correctly linked to Parse
                    //An update may occur when Internet isn't available, try to update at some point
                    parse.saveAndCheckRemoteID(store){
                        (success,error) in
                        
                        if !success{
                            print("Error in \(self.parseClassName).compareUpdate(). Error updating \(careKit)")
                        }else{
                            print("Successfully updated Task \(self) in the Cloud")
                        }
                        completion(success,nil)
                    }
               }
            }else{
                //This should throw a conflict as pullRevisions should have made sure it doesn't happen. Ignoring should allow the newer one to be pulled from the cloud, so we do nothing here
                print("Warning in \(self.parseClassName).compareUpdate(). KnowledgeVector in Cloud \(parse.clock) >= \(self.clock). This should never occur. It should get fixed in next pullRevision. Local: \(self)... Cloud: \(parse)")
                completion(false,nil)
            }
        }
    }
    
    open func deleteFromCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = User.current(),
            let store = store as? OCKStore else{
            completion(false,nil)
            return
        }
        
        //Get latest item from the Cloud to compare against
        let query = Task.query()!
        query.whereKey(kPCKTaskEntityIdKey, equalTo: self.entityId)
        query.includeKeys([kPCKTaskElementsKey,kPCKTaskNotesKey])
        query.getFirstObjectInBackground(){
            (objects, error) in
            guard let foundObject = objects as? Task else{
                completion(false,nil)
                return
            }
            self.compareDelete(foundObject, store: store, usingKnowledgeVector: usingKnowledgeVector, completion: completion)
        }
    }
    
    func compareDelete(_ parse: Task, store: OCKStore, usingKnowledgeVector:Bool, completion: @escaping(Bool,Error?) -> Void){
        guard let careKitLastUpdated = self.locallyUpdatedAt,
            let cloudUpdatedAt = parse.locallyUpdatedAt else{
            completion(false,nil)
            return
        }
        
        if ((cloudUpdatedAt <= careKitLastUpdated) || usingKnowledgeVector){
            parse.elements.forEach{
                $0.deleteInBackground()
            }
            parse.notes?.forEach{
                $0.deleteInBackground()
            }
            parse.deleteInBackground{
                (success, error) in
                if !success{
                    guard let error = error else{return}
                    print("Error in Task.deleteFromCloud(). \(error)")
                }else{
                    print("Successfully deleted Task \(self) in the Cloud")
                }
                completion(success,error)
            }
        }else {
            //The updated version in the cloud is newer, local delete has already occured, so updated the device with the newer one from the cloud
            guard let updatedCarePlanFromCloud = parse.convertToCareKit() else{
                completion(false,nil)
                return
            }
            store.updateAnyTask(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                result in
                switch result{
                case .success(_):
                    print("Successfully deleting Task \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    completion(true,nil)
                case .failure(let error):
                    print("Error deleting Task \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    completion(false,error)
                }
            }
        }
    }
    
    open func addToCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = User.current()else{
            completion(false,nil)
            return
        }
        
        //Check to see if already in the cloud
        let query = Task.query()!
        query.whereKey(kPCKTaskEntityIdKey, equalTo: self.entityId)
        query.includeKeys([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKTaskNotesKey])
        query.findObjectsInBackground(){
            (objects, error) in
            guard let foundObjects = objects else{
                guard let error = error as NSError?,
                    let errorDictionary = error.userInfo["error"] as? [String:Any],
                    let reason = errorDictionary["routine"] as? String else {
                    completion(false,nil)
                    return
                }
                //If the query was looking in a column that wasn't a default column, it will return nil if the table doesn't contain the custom column
                if reason == "errorMissingColumn"{
                    //Saving the new item with the custom column should resolve the issue
                    print("This table '\(self.parseClassName)' either doesn't exist or is missing a column. Attempting to create the table and add new data to it...")
                    //Make wallclock level entities compatible with KnowledgeVector by setting it's initial clock to 0
                    if !usingKnowledgeVector{
                        self.clock = 0
                    }
                    self.saveAndCheckRemoteID(store, completion: completion)
                }else{
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).addToCloud(). \(error.localizedDescription)")
                    completion(false,nil)
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
                    self.clock = 0
                }
                self.saveAndCheckRemoteID(store, completion: completion)
            }
        }
    }
    
    private func saveAndCheckRemoteID(_ store: OCKAnyStoreProtocol, completion: @escaping(Bool,Error?) -> Void){
        guard let store = store as? OCKStore else{
            completion(false,nil)
            return
        }
        stampRelationalEntities()
        self.saveInBackground{(success, error) in
            if success{
                print("Successfully saved \(self) in Cloud.")
                //Need to save remoteId for this and all relational data
                store.fetchTask(withID: self.entityId, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(var mutableEntity):
                        if mutableEntity.remoteID == nil{
                            mutableEntity.remoteID = self.objectId
                            store.updateAnyTask(mutableEntity){
                                result in
                                switch result{
                                case .success(let updatedTask):
                                    print("Updated remoteID of task \(updatedTask)")
                                    completion(true, nil)
                                case .failure(let error):
                                    print("Error in \(self.parseClassName).addToCloud() updating remoteID. \(error)")
                                    completion(false,error)
                                }
                            }
                        }else{
                            if mutableEntity.remoteID! != self.objectId{
                                print("Error in \(self.parseClassName).saveAndCheckRemoteID(). remoteId \(mutableEntity.remoteID!) should equal \(self.objectId!)")
                                completion(false,error)
                            }else{
                                completion(true,nil)
                            }
                            return
                        }
                    case .failure(let error):
                        print("Error in Contact.addToCloud(). \(error)")
                        completion(false,error)
                    }
                }
            }else{
                print("Error in \(self.parseClassName).addToCloud(). \(String(describing: error))")
                completion(false,error)
            }
        }
    }
    
    open func copyCareKit(_ taskAny: OCKAnyTask, clone:Bool, store: OCKAnyStoreProtocol, completion: @escaping(Task?) -> Void){
        
        guard let _ = User.current(),
            let task = taskAny as? OCKTask else{
            completion(nil)
            return
        }
        guard let uuid = task.uuid?.uuidString else{
            print("Error in \(parseClassName). Entity missing uuid: \(task)")
            completion(nil)
            return
        }
        self.uuid = uuid
        self.previousVersionUUID = task.nextVersionUUID?.uuidString
        self.nextVersionUUID = task.previousVersionUUID?.uuidString
        self.entityId = task.id
        self.groupIdentifier = task.groupIdentifier
        self.title = task.title
        self.impactsAdherence = task.impactsAdherence
        self.tags = task.tags
        self.source = task.source
        self.asset = task.asset
        self.timezone = task.timezone.abbreviation()!
        self.locallyUpdatedAt = task.updatedDate
        self.userInfo = task.userInfo
        if clone{
            self.locallyCreatedAt = task.createdDate
            self.notes = task.notes?.compactMap{Note(careKitEntity: $0)}
            self.elements = task.schedule.elements.compactMap{ScheduleElement(careKitEntity: $0)}
        }else{
            //Only copy this over if the Local Version is older than the Parse version
            if self.locallyCreatedAt == nil {
                self.locallyCreatedAt = task.createdDate
            } else if self.locallyCreatedAt != nil && task.createdDate != nil{
                if task.createdDate! < self.locallyCreatedAt!{
                    self.locallyCreatedAt = task.createdDate
                }
            }
            self.notes = Note.updateIfNeeded(self.notes, careKit: task.notes)
            self.elements = ScheduleElement.updateIfNeeded(self.elements, careKit: task.schedule.elements)
        }
        
        //If no CarePlan, we are finished
        guard let carePlanLocalID = task.carePlanUUID else{
            completion(self)
            return
        }
        
        var query = OCKCarePlanQuery()
        query.uuids = [carePlanLocalID]
        store.fetchAnyCarePlans(query: query, callbackQueue: .global(qos: .background)){
            result in
            
            switch result{
            case .success(let plan):
                guard let foundPlan = plan.first else{
                    completion(nil)
                    return
                }
                self.carePlanId = foundPlan.id
                //Attempt to link based off of local database
                guard let carePlanRemoteID = foundPlan.remoteID else{
                    //Local CarePlan hasn't been linked with it's Cloud version, see if we can link to Cloud version
                    let carePlanQuery = CarePlan.query()!
                    carePlanQuery.whereKey(kPCKCarePlanEntityIdKey, equalTo: foundPlan.id)
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
                //Link to Parse based on remoteId
                self.carePlan = CarePlan(withoutDataWithObjectId: carePlanRemoteID)
                completion(self)
            case .failure(_):
                print("")
                completion(nil)
            }
        }
    }
    
    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit()->OCKTask?{
        
        guard var task = createDecodedEntity() else{return nil}
        task.groupIdentifier = self.groupIdentifier
        task.tags = self.tags
        task.source = self.source
        task.instructions = self.instructions
        task.impactsAdherence = self.impactsAdherence
        task.groupIdentifier = self.groupIdentifier
        task.asset = self.asset
        task.userInfo = self.userInfo
        if let timeZone = TimeZone(abbreviation: self.timezone){
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
    
    open func getEntityAsJSONDictionary(_ entity: OCKTask)->[String:Any]?{
        let jsonDictionary:[String:Any]
        do{
            let data = try JSONEncoder().encode(entity)
            jsonDictionary = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers,.mutableLeaves]) as! [String:Any]
        }catch{
            print("Error in \(parseClassName).getEntityAsJSONDictionary(). \(error)")
            return nil
        }
        
        return jsonDictionary
    }
    
    open func createDecodedEntity()->OCKTask?{
        guard let createdDate = self.locallyCreatedAt?.timeIntervalSinceReferenceDate,
            let updatedDate = self.locallyUpdatedAt?.timeIntervalSinceReferenceDate else{
                print("Error in \(parseClassName).createDecodedEntity(). Missing either locallyCreatedAt \(String(describing: locallyCreatedAt)) or locallyUpdatedAt \(String(describing: locallyUpdatedAt))")
            return nil
        }
        
        let careKitScheduleElements = self.elements.compactMap{$0.convertToCareKit()}
        let schedule = OCKSchedule(composing: careKitScheduleElements)
        let tempEntity = OCKTask(id: self.entityId, title: self.title, carePlanUUID: nil, schedule: schedule)
        
        //Create bare CareKit entity from json
        guard var json = getEntityAsJSONDictionary(tempEntity) else{return nil}
        json["uuid"] = self.uuid
        json["createdDate"] = createdDate
        json["updatedDate"] = updatedDate
        if let previous = self.previousVersionUUID{
            json["previousVersionUUID"] = previous
        }
        if let next = self.nextVersionUUID{
            json["nextVersionUUID"] = next
        }
        let entity:OCKTask!
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            let jsonString = String(data: data, encoding: .utf8)!
            print(jsonString)
            entity = try JSONDecoder().decode(OCKTask.self, from: data)
        }catch{
            print("Error in \(parseClassName).createDecodedEntity(). \(error)")
            return nil
        }
        return entity
    }
    
    func stampRelationalEntities(){
        self.notes?.forEach{$0.stamp(self.clock)}
        self.elements.forEach{$0.stamp(self.clock)}
    }
    
    class func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        let query = Task.query()!
        query.whereKey(kPCKTaskClockKey, greaterThanOrEqualTo: localClock)
        query.includeKeys([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKTaskNotesKey])
        query.findObjectsInBackground{ (objects,error) in
            guard let tasks = objects as? [Task] else{
                guard let error = error as NSError?,
                    let errorDictionary = error.userInfo["error"] as? [String:Any],
                    let reason = errorDictionary["routine"] as? String else {return}
                //If the query was looking in a column that wasn't a default column, it will return nil if the table doesn't contain the custom column
                if reason == "errorMissingColumn"{
                    //Saving the new item with the custom column should resolve the issue
                    print("Warning, table Task either doesn't exist or is missing the column \(kPCKTaskClockKey). It should be fixed during the first sync of a Task...")
                }
                let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
                mergeRevision(revision)
                return
            }
            let pulled = tasks.compactMap{$0.convertToCareKit()}
            let entities = pulled.compactMap{OCKEntity.task($0)}
            let revision = OCKRevisionRecord(entities: entities, knowledgeVector: cloudVector)
            mergeRevision(revision)
        }
    }
    
    class func pushRevision(_ store: OCKStore, overwriteRemote: Bool, cloudClock: Int, careKitEntity:OCKEntity, completion: @escaping (Error?) -> Void){
        switch careKitEntity {
        case .task(let careKit):
            let _ = Task(careKitEntity: careKit, store: store){
                copied in
                guard let parse = copied as? Task else{return}
                parse.clock = cloudClock //Stamp Entity
                if careKit.deletedDate == nil{
                    parse.addToCloud(store, usingKnowledgeVector: true, overwriteRemote: overwriteRemote){
                        (success,error) in
                        if success{
                            completion(nil)
                        }else{
                            completion(error)
                        }
                    }
                }else{
                    parse.deleteFromCloud(store, usingKnowledgeVector: true){
                        (success,error) in
                        if success{
                            completion(nil)
                        }else{
                            completion(error)
                        }
                    }
                }
            }
        default:
            print("Error in Contact.pushRevision(). Received wrong type \(careKitEntity)")
            completion(nil)
        }
    }
}

