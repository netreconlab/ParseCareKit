//
//  Outcomes.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/14/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore


open class Outcome: PFObject, PFSubclassing, PCKSynchronizedEntity, PCKRemoteSynchronizedEntity {

    //1 to 1 between Parse and CareStore
    @NSManaged public var asset:String?
    @NSManaged public var careKitId:String //maps to id
    @NSManaged public var entityId:String
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
    @NSManaged public var userInfo:[String:String]?
    
    //Not 1 tot 1, UserInfo fields in CareStore
    @NSManaged public var uuid:String //maps to id
    @NSManaged public var clock:Int
    
    public static func parseClassName() -> String {
        return kPCKOutcomeClassKey
    }

    public convenience init(careKitEntity: OCKAnyOutcome, store: OCKAnyStoreProtocol, completion: @escaping(PCKSynchronizedEntity?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, clone: true, store: store, completion: completion)
    }
    
    open func updateCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        
        guard let _ = User.current(),
            let store = store as? OCKStore else{
            completion(false,nil)
            return
        }
        
        var careKitQuery = OCKOutcomeQuery()
        //careKitQuery.ids = [self.entityId] //Querying ids has a bug as noted here: https://github.com/carekit-apple/CareKit/issues/418#issuecomment-623724009
        careKitQuery.tags = [self.entityId]
        careKitQuery.sortDescriptors = [.date(ascending: false)]
        store.fetchOutcome(query: careKitQuery, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let outcome):
                guard let remoteID = outcome.remoteID else{
                    //Check to see if this entity is already in the Cloud, but not matched locally
                    let query = Outcome.query()!
                    query.whereKey(kPCKOutcomeEntityIdKey, equalTo: self.entityId)
                    //query.whereKey(kPCKOutcomeIdKey, equalTo: self.uuid)
                    query.includeKeys([kPCKOutcomeTaskKey,kPCKOutcomeValuesKey,kPCKOutcomeNotesKey])
                    query.findObjectsInBackground{
                        (objects, error) in
                        guard let foundObject = objects?.first as? Outcome else{
                            completion(false,nil)
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
                query.whereKey(kPCKOutcomeObjectIdKey, equalTo: remoteID)
                query.includeKeys([kPCKOutcomeTaskKey,kPCKOutcomeValuesKey,kPCKOutcomeNotesKey])
                query.findObjectsInBackground{
                    (objects, error) in
                    guard let foundObject = objects?.first as? Outcome else{
                        completion(false,nil)
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
    
    func fetchOutcomeValuesIfNeeded(_ values:[OutcomeValue], completion: @escaping(Bool) -> Void){
        var itemsFetched = 0
        values.forEach{
            $0.fetchIfNeededInBackground(){
                (object,error) in
                guard let _ = object else{
                    if error != nil{
                        print("Error in Outcome.fetchOutcomeValuesIfNeeded(). \(error!)")
                    }
                    completion(true)
                    return
                }
                itemsFetched += 1
                if itemsFetched == values.count{
                    completion(true)
                }
            }
        }
    }
    
    func compareUpdate(_ careKit: OCKOutcome, parse: Outcome, store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void){
        guard let store = store as? OCKStore else{return}
        if !usingKnowledgeVector{
            guard let careKitLastUpdated = careKit.updatedDate,
                let cloudUpdatedAt = parse.locallyUpdatedAt else{
                completion(false,nil)
                return
            }
            if ((cloudUpdatedAt < careKitLastUpdated) || overwriteRemote){
                parse.copyCareKit(careKit, clone: overwriteRemote, store: store){_ in
                    //An update may occur when Internet isn't available, try to update at some point
                    parse.saveAndCheckRemoteID(store, outcomeValues: careKit.values, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote){
                        (success,error) in
                        
                        if !success{
                            print("Error in \(self.parseClassName).updateCloud(). Couldn't update in cloud: \(careKit)")
                        }else{
                            print("Successfully updated \(self.parseClassName) \(self) in the Cloud")
                        }
                        completion(success,error)
                    }
                }
            }else if cloudUpdatedAt > careKitLastUpdated {
                guard let updatedCarePlanFromCloud = parse.convertToCareKit() else{
                    completion(false,nil)
                    return
                }
                    
                store.updateAnyOutcome(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(_):
                        print("Successfully updated \(self.parseClassName) \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                        completion(true,nil)
                    case .failure(let error):
                        print("Error updating \(self.parseClassName) \(updatedCarePlanFromCloud) from the Cloud to CareStore")
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
                    parse.saveAndCheckRemoteID(store, outcomeValues: careKit.values, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote){
                        (success,error) in
                        
                        if !success{
                            print("Error in \(self.parseClassName).updateCloud(). Couldn't update in cloud: \(careKit)")
                        }else{
                            print("Successfully updated \(self.parseClassName) \(self) in the Cloud")
                        }
                        completion(success,error)
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
        
        guard let _ = User.current() else{
            completion(false,nil)
            return
        }
                
        //Get latest item from the Cloud to compare against
        let query = Outcome.query()!
        query.whereKey(kPCKOutcomeEntityIdKey, equalTo: entityId)
        query.includeKeys([kPCKOutcomeValuesKey,kPCKOutcomeNotesKey])
        query.findObjectsInBackground{
            (objects, error) in
            guard let foundObject = objects?.first as? Outcome else{
                completion(false,nil)
                return
            }
            self.compareDelete(foundObject, store: store, usingKnowledgeVector: usingKnowledgeVector, completion: completion)
        }
    }
    
    func compareDelete(_ parse: Outcome, store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool, completion: @escaping(Bool,Error?) -> Void){
        guard let careKitLastUpdated = self.locallyUpdatedAt,
            let cloudUpdatedAt = parse.locallyUpdatedAt else{
            completion(false,nil)
            return
        }
        
        if ((cloudUpdatedAt <= careKitLastUpdated) || usingKnowledgeVector) {
            parse.values.forEach{
                $0.deleteInBackground()
            }
            parse.notes?.forEach{
                $0.deleteInBackground()
            }
            parse.deleteInBackground{
                (success, error) in
                if !success{
                    print("Error in \(self.parseClassName).deleteFromCloud(). \(String(describing: error))")
                }else{
                    print("Successfully deleted \(self.parseClassName) \(self) in the Cloud")
                }
                completion(success,error)
            }
        }else {
            guard let updatedCarePlanFromCloud = parse.convertToCareKit() else{
                completion(false,nil)
                return
            }
            store.updateAnyOutcome(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                result in
                switch result{
                case .success(_):
                    print("Successfully deleting \(self.parseClassName) \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    completion(true,nil)
                case .failure(let error):
                    print("Error deleting \(self.parseClassName) \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    completion(false,error)
                }
            }
        }
    }
    
    open func addToCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
            
        guard let _ = User.current() else{
            completion(false,nil)
            return
        }
        
        //Check to see if already in the cloud
        let query = Outcome.query()!
        query.whereKey(kPCKOutcomeEntityIdKey, equalTo: entityId)
        //query.whereKey(kPCKOutcomeIdKey, equalTo: self.uuid)
        query.includeKeys([kPCKOutcomeTaskKey,kPCKOutcomeValuesKey,kPCKOutcomeNotesKey])
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
                    //Make wallclock level entities compatible with KnowledgeVector by setting it's initial clock to 0
                    if !usingKnowledgeVector{
                        self.clock = 0
                    }
                    self.saveAndCheckRemoteID(store, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
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
                //Make wallclock level entities compatible with KnowledgeVector by setting it's initial clock to 0
                if !usingKnowledgeVector{
                    self.clock = 0
                }
                //This is the first object, make sure to save it
                self.saveAndCheckRemoteID(store, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
            }
        }
    }
    
    func saveAndCheckRemoteID(_ store: OCKAnyStoreProtocol, outcomeValues:[OCKOutcomeValue]?=nil, usingKnowledgeVector: Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void){
        guard let store = store as? OCKStore else {
            completion(false,nil)
            return
        }
        stampRelationalEntities()
        self.saveInBackground{(success, error) in
            if success{
                print("Successfully saved \(self) in Cloud.")
                
                var careKitQuery = OCKOutcomeQuery()
                //careKitQuery.ids = [self.entityId] //Querying ids has a bug as noted here: https://github.com/carekit-apple/CareKit/issues/418#issuecomment-623724009
                careKitQuery.tags = [self.entityId]
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
                                print("Error in \(self.parseClassName).saveAndCheckRemoteID(). remoteId \(mutableOutcome.remoteID!) should equal \(self.objectId!)")
                                completion(false,error)
                                return
                            }
                        }
                        
                        //EntityIds are custom, make sure to add them as a tag for querying
                        if let outcomeTags = mutableOutcome.tags{
                            if !outcomeTags.contains(self.entityId){
                                mutableOutcome.tags!.append(self.entityId)
                                needToUpdate = true
                            }
                        }else{
                            mutableOutcome.tags = [self.entityId]
                            needToUpdate = true
                        }
                        
                        self.values.forEach{
                            for (index,value) in mutableOutcome.values.enumerated(){
                                guard let id = value.userInfo?[kPCKOutcomeValueUserInfoEntityIdKey],
                                    id == $0.entityId else{
                                    continue
                                }
                                
                                //Be sure outcomeValue has relation to outcome in userInfo (this will save when needed)
                                if mutableOutcome.values[index].userInfo![kPCKOutcomeValueUserInfoRelatedOutcomeEntityIdKey] == nil{
                                    mutableOutcome.values[index].userInfo![kPCKOutcomeValueUserInfoRelatedOutcomeEntityIdKey] = self.entityId
                                    needToUpdate = true
                                }
                                
                                //Tag associatied outcome with this outcomevalue
                                if let outcomeValueTags = mutableOutcome.values[index].tags{
                                    if !outcomeValueTags.contains(self.entityId){
                                        mutableOutcome.values[index].tags!.append(self.entityId)
                                        needToUpdate = true
                                    }
                                }else{
                                    mutableOutcome.values[index].tags = [self.entityId]
                                    needToUpdate = true
                                }
                                
                                if mutableOutcome.values[index].remoteID == nil{
                                    mutableOutcome.values[index].remoteID = $0.objectId
                                    needToUpdate = true
                                }
                                
                                guard let updatedValue = $0.compareUpdate(mutableOutcome.values[index], parse: $0, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, newClockValue: self.clock, store: store) else {continue}
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
                                    completion(true,nil)
                                case .failure(let error):
                                    print("Error updating remoteID. \(error)")
                                    completion(false,error)
                                }
                            }
                        }else{
                            completion(true,nil)
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
                                        guard let foundEntityId = $0.userInfo?[kPCKOutcomeUserInfoEntityIdKey] else{return false}
                                        if foundEntityId == self.entityId{
                                            return true
                                        }
                                        return false
                                    }
                                    
                                    if matchingOutcomes.count > 1{
                                        print("Warning in \(self.parseClassName).saveAndCheckRemoteID(), found \(matchingOutcomes.count) matching uuid \(self.uuid). There should only be 1")
                                    }

                                    guard var outcomeToUse = matchingOutcomes.first else{
                                        print("Error in \(self.parseClassName).saveAndCheckRemoteID(), found no matching Outcomes with uuid \(self.uuid). There should be 1")
                                        completion(false,nil)
                                        return
                                    }
                                    //Fix tag
                                    outcomeToUse.tags = [self.uuid,self.entityId]
                                    store.updateOutcome(outcomeToUse, callbackQueue: .global(qos: .background)){
                                        result in
                                        
                                        switch result{
                                        case .success(let foundOutcome):
                                            print("Fixed tag for \(foundOutcome)")
                                            completion(true,nil)
                                        case .failure(let error):
                                            print("Error fixing tag on \(outcomeToUse). \(error)")
                                            completion(false,error)
                                        }
                                        
                                    }
                                case .failure(let error):
                                    print("Error updating remoteID. \(error)")
                                    completion(false,error)
                                }
                            }
                        }else{
                            completion(false,error)
                        }
                    }
                }
            }else{
                print("Error in CarePlan.addToCloud(). \(String(describing: error))")
                completion(false,error)
            }
        }
    }
        
    open func copyCareKit(_ outcomeAny: OCKAnyOutcome, clone: Bool, store: OCKAnyStoreProtocol, completion: @escaping(Outcome?) -> Void){
        
        guard let _ = User.current(),
            let outcome = outcomeAny as? OCKOutcome,
            let store = store as? OCKStore else{
            completion(nil)
            return
        }
        
        guard let uuid = getUUIDFromCareKitEntity(outcome) else {
            completion(nil)
            return
        }
        self.uuid = uuid
        
        if let id = outcome.userInfo?[kPCKOutcomeUserInfoEntityIdKey] {
            self.entityId = id
        }
        
        self.taskOccurrenceIndex = outcome.taskOccurrenceIndex
        self.groupIdentifier = outcome.groupIdentifier
        self.tags = outcome.tags
        self.source = outcome.source
        self.asset = outcome.asset
        self.timezone = outcome.timezone.abbreviation()!
        self.locallyUpdatedAt = outcome.updatedDate
        self.userInfo = outcome.userInfo
        
        if clone{
            self.locallyCreatedAt = outcome.createdDate
            self.notes = outcome.notes?.compactMap{Note(careKitEntity: $0)}
            self.values = outcome.values.compactMap{OutcomeValue(careKitEntity: $0)}
        }else{
            //Only copy this over if the Local Version is older than the Parse version
            if self.locallyCreatedAt == nil {
                self.locallyCreatedAt = outcome.createdDate
            } else if self.locallyCreatedAt != nil && outcome.createdDate != nil{
                if outcome.createdDate! < self.locallyCreatedAt!{
                    self.locallyCreatedAt = outcome.createdDate
                }
            }
            self.notes = Note.updateIfNeeded(self.notes, careKit: outcome.notes)
            self.values = OutcomeValue.updateIfNeeded(self.values, careKit: outcome.values)
        }
        let test = self.createDecodedEntity()
        //ID's are the same for related Plans
        var query = OCKTaskQuery()
        query.uuids = [outcome.taskUUID]
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
                    taskQuery.whereKey(kPCKTaskEntityIdKey, equalTo: task.id)
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
                
            case .failure(let error):
                print("Error in \(self.parseClassName).copyCareKit(). \(error)")
                completion(nil)
            }
        }
    }
        
    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit()->OCKOutcome?{
        guard var outcome = createDecodedEntity() else{return nil}
        outcome.groupIdentifier = self.groupIdentifier
        outcome.tags = self.tags
        outcome.source = self.source
        outcome.userInfo = self.userInfo
        //outcome.userInfo = [kPCKOutcomeUserInfoEntityIdKey: self.entityId] //For some reason, outcome doesn't let you set the current one. Assuming this is a bug in the current CareKit
        
        outcome.taskOccurrenceIndex = self.taskOccurrenceIndex
        outcome.groupIdentifier = self.groupIdentifier
        outcome.asset = self.asset
        if let timeZone = TimeZone(abbreviation: self.timezone){
            outcome.timezone = timeZone
        }
        outcome.notes = self.notes?.compactMap{$0.convertToCareKit()}
        outcome.remoteID = self.objectId
        return outcome
    }
    
    func createDecodedEntity()->OCKOutcome?{
        guard let task = self.task,
            let taskID = UUID(uuidString: task.uuid),
            let createdDate = self.locallyCreatedAt?.timeIntervalSinceReferenceDate,
            let updatedDate = self.locallyUpdatedAt?.timeIntervalSinceReferenceDate else{
                print("Error in \(parseClassName).createDecodedEntity(). Missing either locallyCreatedAt \(String(describing: locallyCreatedAt)) or locallyUpdatedAt \(String(describing: locallyUpdatedAt))")
            return nil
        }
            
        let outcomeValues = self.values.compactMap{$0.convertToCareKit()}
        let tempEntity = OCKOutcome(taskUUID: taskID, taskOccurrenceIndex: self.taskOccurrenceIndex, values: outcomeValues)
        guard var json = getEntityAsJSONDictionary(tempEntity) else{return nil}
        json["uuid"] = self.uuid as AnyObject
        json["createdDate"] = createdDate as AnyObject
        json["updatedDate"] = updatedDate as AnyObject
        let entity:OCKOutcome!
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            entity = try JSONDecoder().decode(OCKOutcome.self, from: data)
        }catch{
            print("Error in \(parseClassName).createDecodedEntity(). \(error)")
            return nil
        }
        return entity
        /*let jsonString:String!
        do{
            let jsonData = try JSONEncoder().encode(tempEntity)
            jsonString = String(data: jsonData, encoding: .utf8)!
        }catch{
            print("Error \(error)")
            return nil
        }
        
        //Create bare CareKit entity from json
        let insertValue = "\"uuid\":\"\(self.uuid)\",\"createdDate\":\(createdDate),\"updatedDate\":\(updatedDate)"
        guard let modifiedJson = ParseCareKitUtility.insertReadOnlyKeys(insertValue, json: jsonString),
            let data = modifiedJson.data(using: .utf8) else{return nil}
        let entity:OCKOutcome!
        do {
            entity = try JSONDecoder().decode(OCKOutcome.self, from: data)
        }catch{
            print("Error in \(parseClassName).createDecodedEntity(). \(error)")
            return nil
        }
        return entity*/
    }
    
    open func getEntityAsJSONDictionary(_ entity: OCKOutcome)->[String:AnyObject]?{
        let jsonDictionary:[String:AnyObject]
        do{
            let data = try JSONEncoder().encode(entity)
            jsonDictionary = try JSONSerialization.jsonObject(with: data, options: []) as! [String:AnyObject]
        }catch{
            print("Error in \(parseClassName).getEntityAsJSONDictionary(). \(error)")
            return nil
        }
        
        return jsonDictionary
    }
    
    open func getUUIDFromCareKitEntity(_ entity: OCKOutcome)->String?{
        guard let json = getEntityAsJSONDictionary(entity) else{return nil}
        return json["uuid"] as? String
    }
    
    func stampRelationalEntities(){
        self.notes?.forEach{$0.stamp(self.clock)}
        self.values.forEach{$0.stamp(self.clock)}
    }
    
    class func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        let query = Outcome.query()!
        query.whereKey(kPCKOutcomeClockKey, greaterThanOrEqualTo: localClock)
        query.includeKeys([kPCKOutcomeTaskKey,kPCKOutcomeValuesKey,kPCKOutcomeNotesKey])
        query.findObjectsInBackground{ (objects,error) in
            guard let outcomes = objects as? [Outcome] else{
                guard let error = error as NSError?,
                    let errorDictionary = error.userInfo["error"] as? [String:Any],
                    let reason = errorDictionary["routine"] as? String else {return}
                //If the query was looking in a column that wasn't a default column, it will return nil if the table doesn't contain the custom column
                if reason == "errorMissingColumn"{
                    //Saving the new item with the custom column should resolve the issue
                    print("Warning, table Outcome either doesn't exist or is missing the column \(kPCKOutcomeClockKey). It should be fixed during the first sync of an Outcome...")
                }
                let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
                mergeRevision(revision)
                return
            }
            let pulled = outcomes.compactMap{$0.convertToCareKit()}
            let entities = pulled.compactMap{OCKEntity.outcome($0)}
            let revision = OCKRevisionRecord(entities: entities, knowledgeVector: cloudVector)
            mergeRevision(revision)
        }
    }
    
    class func pushRevision(_ store: OCKStore, overwriteRemote: Bool, cloudClock: Int, careKitEntity:OCKEntity, completion: @escaping (Error?) -> Void){
        switch careKitEntity {
        case .outcome(let careKit):
            let _ = Outcome(careKitEntity: careKit, store: store){
                copied in
                guard let parse = copied as? Outcome else{return}
                parse.clock = cloudClock //Stamp Entity
                //if careKit.deletedDate == nil{
                    parse.addToCloud(store, usingKnowledgeVector: true, overwriteRemote: overwriteRemote){
                        (success,error) in
                        if success{
                            completion(nil)
                        }else{
                            completion(error)
                        }
                    }
                /*}else{
                    parse.deleteFromCloud(store, usingKnowledgeVector: true){
                        (success,error) in
                        if success{
                            completion(nil)
                        }else{
                            completion(error)
                        }
                    }
                }*/
            }
        default:
            print("Error in Contact.pushRevision(). Received wrong type \(careKitEntity)")
            completion(nil)
        }
    }
}

