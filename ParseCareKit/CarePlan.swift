//
//  CarePlan.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore


open class CarePlan: PFObject, PFSubclassing, PCKSynchronizedEntity, PCKRemoteSynchronizedEntity {

    //Parse only
    @NSManaged public var being:Being?
    @NSManaged public var author:Being?
    
    //1 to 1 between Parse and CareStore
    @NSManaged public var title:String
    @NSManaged public var deletedDate:Date?
    @NSManaged public var effectiveDate:Date
    @NSManaged public var groupIdentifier:String?
    @NSManaged public var tags:[String]?
    @NSManaged public var timezone:String
    @NSManaged public var asset:String?
    @NSManaged public var source:String?
    @NSManaged public var notes:[Note]?
    @NSManaged public var uuid:String
    @NSManaged public var nextVersionUUID:String?
    @NSManaged public var previousVersionUUID:String?
    @NSManaged public var locallyCreatedAt:Date?
    @NSManaged public var locallyUpdatedAt:Date?
    @NSManaged public var userInfo:[String:String]?
    
    //Not 1 to 1 UserInfo fields on CareStore
    @NSManaged public var entityId:String //maps to id
    @NSManaged public var clock:Int
    
    public static func parseClassName() -> String {
        return kPCKCarePlanClassKey
    }
    
    public convenience init(careKitEntity: OCKAnyCarePlan, store: OCKAnyStoreProtocol, completion: @escaping(PCKSynchronizedEntity?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, clone: true, store: store, completion: completion)
    }
    
    open func updateCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current(),
            let store = store as? OCKStore,
            let carePlanUUID = UUID(uuidString: self.uuid) else{
            completion(false,nil)
            return
        }
        var careKitQuery = OCKCarePlanQuery()
        careKitQuery.uuids = [carePlanUUID]
        
        store.fetchCarePlans(query: careKitQuery, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let carePlans):
                
                guard let carePlan = carePlans.first else{
                    completion(false,nil)
                    return
                }
                
                //Check to see if already in the cloud
                guard let remoteID = carePlan.remoteID else{
                    //Check to see if this entity is already in the Cloud, but not matched locally
                    let query = CarePlan.query()!
                    query.whereKey(kPCKCarePlanUUIDKey, equalTo: carePlanUUID.uuidString)
                    query.includeKeys([kPCKCarePlanAuthorKey,kPCKCarePlanPatientKey,kPCKCarePlanNotesKey])
                    query.getFirstObjectInBackground(){
                        (object, error) in
                        guard let foundObject = object as? CarePlan else{
                            completion(false,nil)
                            return
                        }
                        self.compareUpdate(carePlan, parse: foundObject, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, store: store, completion: completion)
                        
                    }
                    return
                }
                //Get latest item from the Cloud to compare against
                let query = CarePlan.query()!
                query.whereKey(kPCKCarePlanObjectIdKey, equalTo: remoteID)
                query.includeKeys([kPCKCarePlanAuthorKey,kPCKCarePlanPatientKey,kPCKCarePlanNotesKey])
                query.getFirstObjectInBackground(){
                    (object, error) in
                    guard let foundObject = object as? CarePlan else{
                        completion(false,error)
                        return
                    }
                    self.compareUpdate(carePlan, parse: foundObject, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, store: store, completion: completion)
                }
            case .failure(let error):
                print("Error in Contact.addToCloud(). \(error)")
                completion(false,error)
            }
        }
        
    }
    
    private func compareUpdate(_ careKit: OCKCarePlan, parse: CarePlan, usingKnowledgeVector: Bool, overwriteRemote: Bool,  store: OCKStore, completion: @escaping(Bool,Error?) -> Void){
        if !usingKnowledgeVector{
            guard let careKitLastUpdated = careKit.updatedDate,
                let cloudUpdatedAt = parse.locallyUpdatedAt else{
                    completion(false,nil)
                return
            }
            if ((cloudUpdatedAt < careKitLastUpdated) || overwriteRemote){
                parse.copyCareKit(careKit, clone: overwriteRemote, store: store){_ in
                    parse.saveAndCheckRemoteID(store){
                        (success,error) in
                        if !success{
                            print("Error in CarePlan.updateCloud(). Couldn't update \(careKit)")
                        }else{
                            print("Successfully updated CarePlan \(self) in the Cloud")
                        }
                        completion(success,error)
                    }
                }
            }else if ((cloudUpdatedAt > careKitLastUpdated) || !overwriteRemote) {
                //The cloud version is newer than local, update the local version instead
                guard let updatedCarePlanFromCloud = parse.convertToCareKit() else{
                    completion(false,nil)
                    return
                }
                store.updateAnyCarePlan(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(_):
                        print("Successfully updated CarePlan \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                        completion(true,nil)
                    case .failure(let error):
                        print("Error updating CarePlan \(updatedCarePlanFromCloud) from the Cloud to CareStore")
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
                    parse.saveAndCheckRemoteID(store){
                        (success,error) in
                        
                        if !success{
                            print("Error in CarePlan.updateCloud(). Couldn't update \(careKit)")
                        }else{
                            print("Successfully updated CarePlan \(self) in the Cloud")
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
        guard let _ = PFUser.current(),
            let store = store as? OCKStore else{
                completion(false,nil)
            return
        }
       
        //Get latest item from the Cloud to compare against
        let query = CarePlan.query()!
        query.whereKey(kPCKCarePlanUUIDKey, equalTo: self.uuid)
        query.getFirstObjectInBackground{
            (object, error) in
            guard let foundObject = object as? CarePlan else{
                completion(false,error)
                return
            }
            self.compareDelete(foundObject, store: store, completion: completion)
        }
    }
    
    func compareDelete(_ parse: CarePlan, store: OCKStore, completion: @escaping(Bool,Error?) -> Void){
        guard let careKitLastUpdated = self.locallyUpdatedAt,
            let cloudUpdatedAt = parse.locallyUpdatedAt else{
                completion(false,nil)
            return
        }
        
        if cloudUpdatedAt <= careKitLastUpdated{
            parse.deleteInBackground{
                (success, error) in
                if !success{
                    print("Error in CarePlan.deleteFromCloud(). \(String(describing: error))")
                }else{
                    print("Successfully deleted CarePlan \(self) in the Cloud")
                }
                completion(success,error)
            }
        }else {
            guard let updatedCarePlanFromCloud = parse.convertToCareKit() else {
                completion(false,nil)
                return
            }
            store.updateAnyCarePlan(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                result in
                switch result{
                case .success(_):
                    print("Successfully deleting CarePlan \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    completion(true,nil)
                case .failure(let error):
                    print("Error deleting CarePlan \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    completion(false,error)
                }
            }
        }
    }
    
    open func addToCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current() else{
            completion(false,nil)
            return
        }
        
        let query = CarePlan.query()!
        query.whereKey(kPCKCarePlanUUIDKey, equalTo: self.uuid)
        query.includeKeys([kPCKCarePlanAuthorKey,kPCKCarePlanPatientKey,kPCKCarePlanNotesKey])
        query.findObjectsInBackground(){
            (objects, parseError) in
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
                        self.clock = 0
                    }
                    self.saveAndCheckRemoteID(store,completion: completion)
                }else{
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).addToCloud(). \(error.localizedDescription)")
                    completion(false,nil)
                }
                return
            }
            //If object already in the Cloud, exit
            if foundObjects.count > 0{
                //Maybe this needs to be updated instead
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
        guard let store = store as? OCKStore,
            let carePlanUUID = UUID(uuidString: self.uuid) else{
            completion(false,nil)
            return
        }
        stampRelationalEntities()
        self.saveInBackground{(success, error) in
            if success{
                //Only save data back to CarePlanStore if it's never been saved before
                var careKitQuery = OCKCarePlanQuery()
                careKitQuery.uuids = [carePlanUUID]
                store.fetchCarePlans(query: careKitQuery, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(let entities):
                        guard var mutableEntity = entities.first else{
                            completion(false, nil)
                            return
                        }
                        if mutableEntity.remoteID == nil{
                            mutableEntity.remoteID = self.objectId
                            store.updateAnyCarePlan(mutableEntity, callbackQueue: .global(qos: .background)){
                                result in
                                switch result{
                                case .success(_):
                                    print("Successfully added CarePlan \(mutableEntity) to Cloud")
                                    completion(true, nil)
                                case .failure(_):
                                    print("Error in CarePlan.saveAndCheckRemoteID() adding CarePlan \(mutableEntity) to Cloud")
                                    completion(false, error)
                                }
                            }
                        }else{
                            if mutableEntity.remoteID! != self.objectId{
                                print("Error in \(self.parseClassName).saveAndCheckRemoteID(). remoteId \(mutableEntity.remoteID!) should equal \(self.objectId!)")
                                completion(false, error)
                            }else{
                                completion(true, nil)
                            }
                        }
                    case .failure(let error):
                        print("Error in Contact.addToCloud(). \(error)")
                        completion(false, error)
                    }
                }
            }else{
                /*guard let unwrappedError = error else{
                    completion(false, error)
                    return
                }*/
                print("Error in CarePlan.saveAndCheckRemoteID(). \(String(describing: error))")
                completion(false, error)
            }
        }
    }
    
    open func copyCareKit(_ carePlanAny: OCKAnyCarePlan, clone: Bool, store: OCKAnyStoreProtocol, completion: @escaping(CarePlan?) -> Void){
        
        guard let _ = PFUser.current(),
            let carePlan = carePlanAny as? OCKCarePlan,
            let store = store as? OCKStore else{
            completion(nil)
            return
        }
        guard let uuid = carePlan.uuid?.uuidString else{
            print("Error in \(parseClassName). Entity missing uuid: \(carePlan)")
            completion(nil)
            return
        }
        self.uuid = uuid
        self.previousVersionUUID = carePlan.nextVersionUUID?.uuidString
        self.nextVersionUUID = carePlan.previousVersionUUID?.uuidString
        self.entityId = carePlan.id
        self.deletedDate = carePlan.deletedDate
        self.title = carePlan.title
        self.groupIdentifier = carePlan.groupIdentifier
        self.tags = carePlan.tags
        self.source = carePlan.source
        self.asset = carePlan.asset
        self.timezone = carePlan.timezone.abbreviation()!
        self.effectiveDate = carePlan.effectiveDate
        self.locallyUpdatedAt = carePlan.updatedDate
        self.userInfo = carePlan.userInfo
        if clone{
            self.locallyCreatedAt = carePlan.createdDate
            self.notes = carePlan.notes?.compactMap{Note(careKitEntity: $0)}
        }else{
            //Only copy this over if the Local Version is older than the Parse version
            if self.locallyCreatedAt == nil {
                self.locallyCreatedAt = carePlan.createdDate
            } else if self.locallyCreatedAt != nil && carePlan.createdDate != nil{
                if carePlan.createdDate! < self.locallyCreatedAt!{
                    self.locallyCreatedAt = carePlan.createdDate
                }
            }
            self.notes = Note.updateIfNeeded(self.notes, careKit: carePlan.notes)
        }
        
        guard let authorID = carePlan.patientUUID else{
            completion(self)
            return
        }
        //ID's are the same for related Plans
        var query = OCKPatientQuery()
        query.uuids = [authorID]
        store.fetchPatients(query: query, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let authors):
                //Should only be one patient returned
                guard let careKitAuthor = authors.first else{
                    completion(nil)
                    return
                }
                
                guard let authorRemoteId = careKitAuthor.remoteID else{
                    completion(nil)
                    return
                }
                
                self.author = Being(withoutDataWithObjectId: authorRemoteId)
                
                //Search for being
                if let patientUUIDToSearchFor = carePlan.userInfo?[kPCKCarePlanUserInfoBeingUUIDKey]{
                   
                    guard let potentialBeingUUID = UUID(uuidString: patientUUIDToSearchFor) else{
                        completion(self)
                        return
                    }
                    
                    var patientQuery = OCKPatientQuery()
                    patientQuery.uuids = [potentialBeingUUID]
                    store.fetchAnyPatients(query: patientQuery, callbackQueue: .global(qos: .background)){
                        result in
                        switch result{
                        case .success(let patients):
                            guard let patient = patients.first,
                                let patientRemoteId = patient.remoteID else{
                                    completion(nil)
                                return
                            }
                            self.being = Being(withoutDataWithObjectId: patientRemoteId)
                            completion(self)
                        case .failure(_):
                            completion(nil)
                        }
                    }
                }else{
                    completion(self)
                }
            case .failure(_):
                completion(nil)
            }
        }
    }
    
    //Note that CarePlans have to be saved to CareKit first in order to properly convert to CareKit
    open func convertToCareKit()->OCKCarePlan?{
        
        guard var carePlan = createDecodedEntity() else{return nil}
        carePlan.groupIdentifier = self.groupIdentifier
        carePlan.tags = self.tags
        carePlan.effectiveDate = self.effectiveDate
        carePlan.source = self.source
        carePlan.groupIdentifier = self.groupIdentifier
        carePlan.asset = self.asset
        carePlan.remoteID = self.objectId
        carePlan.notes = self.notes?.compactMap{$0.convertToCareKit()}
        carePlan.userInfo = self.userInfo
        if let timeZone = TimeZone(abbreviation: self.timezone){
            carePlan.timezone = timeZone
        }
        return carePlan
    }
    
    open class func getEntityAsJSONDictionary(_ entity: OCKCarePlan)->[String:Any]?{
        let jsonDictionary:[String:Any]
        do{
            let data = try JSONEncoder().encode(entity)
            jsonDictionary = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers,.mutableLeaves]) as! [String:Any]
        }catch{
            print("Error in CarePlan.getEntityAsJSONDictionary(). \(error)")
            return nil
        }
        
        return jsonDictionary
    }
    
    open func createDecodedEntity()->OCKCarePlan?{
        guard let authorID = self.author?.uuid,
            let authorUUID = UUID(uuidString: authorID),
            let createdDate = self.locallyCreatedAt?.timeIntervalSinceReferenceDate,
            let updatedDate = self.locallyUpdatedAt?.timeIntervalSinceReferenceDate else{
                print("Error in \(parseClassName).createDecodedEntity(). Missing either locallyCreatedAt \(String(describing: locallyCreatedAt)) or locallyUpdatedAt \(String(describing: locallyUpdatedAt))")
            return nil
        }
            
        let tempEntity = OCKCarePlan(id: self.entityId, title: self.title, patientUUID: authorUUID)
        //Create bare CareKit entity from json
        guard var json = CarePlan.getEntityAsJSONDictionary(tempEntity) else{return nil}
        json["uuid"] = self.uuid
        json["createdDate"] = createdDate
        json["updatedDate"] = updatedDate
        if let deletedDate = self.deletedDate?.timeIntervalSinceReferenceDate{
            json["deletedDate"] = deletedDate
        }
        if let previous = self.previousVersionUUID{
            json["previousVersionUUID"] = previous
        }
        if let next = self.nextVersionUUID{
            json["nextVersionUUID"] = next
        }
        let entity:OCKCarePlan!
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            let jsonString = String(data: data, encoding: .utf8)!
            print(jsonString)
            entity = try JSONDecoder().decode(OCKCarePlan.self, from: data)
        }catch{
            print("Error in \(parseClassName).createDecodedEntity(). \(error)")
            return nil
        }
        return entity
    }
    
    func stampRelationalEntities(){
        self.notes?.forEach{$0.stamp(self.clock)}
    }
    
    class func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        let query = CarePlan.query()!
        query.whereKey(kPCKCarePlanClockKey, greaterThanOrEqualTo: localClock)
        query.includeKeys([kPCKCarePlanAuthorKey,kPCKCarePlanPatientKey,kPCKCarePlanNotesKey])
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
                    print("Warning, table CarePlan either doesn't exist or is missing the column \(kPCKOutcomeClockKey). It should be fixed during the first sync of an Outcome...")
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
    
    class func pushRevision(_ store: OCKStore, overwriteRemote: Bool, cloudClock: Int, careKitEntity:OCKEntity, completion: @escaping (Error?) -> Void){
        switch careKitEntity {
        case .carePlan(let careKit):
            let _ = CarePlan(careKitEntity: careKit, store: store){
                copied in
                guard let parse = copied as? CarePlan else{
                    completion(nil)
                    return
                }
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
            print("Error in CarePlan.pushRevision(). Received wrong type \(careKitEntity)")
            completion(nil)
        }
    }
}

