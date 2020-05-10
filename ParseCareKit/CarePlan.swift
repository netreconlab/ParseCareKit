//
//  CarePlan.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 NetReconLab. All rights reserved.
//

import Parse
import CareKitStore


open class CarePlan: PFObject, PFSubclassing, PCKSynchronizedEntity, PCKRemoteSynchronizedEntity {

    //Parse only
    @NSManaged public var patient:User?
    @NSManaged public var author:User?
    @NSManaged public var authorId:String?
    
    //1 to 1 between Parse and CareStore
    @NSManaged public var title:String
    @NSManaged public var groupIdentifier:String?
    @NSManaged public var tags:[String]?
    @NSManaged public var timezone:String
    @NSManaged public var asset:String?
    @NSManaged public var source:String?
    @NSManaged public var notes:[Note]?
    @NSManaged public var uuid:String
    @NSManaged public var locallyCreatedAt:Date?
    @NSManaged public var locallyUpdatedAt:Date?
    
    //Not 1 to 1 UserInfo fields on CareStore
    @NSManaged public var patientId:String?
    @NSManaged public var clock:Int
    
    public static func parseClassName() -> String {
        return kPCKCarePlanClassKey
    }
    
    public convenience init(careKitEntity: OCKAnyCarePlan, store: OCKAnyStoreProtocol, completion: @escaping(PCKSynchronizedEntity?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, store: store, completion: completion)
    }
    
    open func updateCloudEventually(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false){
        guard let _ = User.current(),
            let store = store as? OCKStore else{
            return
        }
        
        store.fetchCarePlan(withID: self.uuid, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let carePlan):
                //Check to see if already in the cloud
                guard let remoteID = carePlan.remoteID else{
                    //Check to see if this entity is already in the Cloud, but not matched locally
                    let query = CarePlan.query()!
                    query.whereKey(kPCKCarePlanIDKey, equalTo: carePlan.id)
                    query.includeKeys([kPCKCarePlanAuthorKey,kPCKCarePlanPatientKey,kPCKCarePlanNotesKey])
                    query.findObjectsInBackground{
                        (objects, error) in
                        guard let foundObject = objects?.first as? CarePlan else{
                            return
                        }
                        self.compareUpdate(carePlan, parse: foundObject, store: store)
                        
                    }
                    return
                }
                //Get latest item from the Cloud to compare against
                let query = CarePlan.query()!
                query.whereKey(kPCKCarePlanObjectIdKey, equalTo: remoteID)
                query.includeKeys([kPCKCarePlanAuthorKey,kPCKCarePlanPatientKey,kPCKCarePlanNotesKey])
                query.findObjectsInBackground{
                    (objects, error) in
                    guard let foundObject = objects?.first as? CarePlan else{
                        return
                    }
                    self.compareUpdate(carePlan, parse: foundObject, store: store)
                }
            case .failure(let error):
                print("Error in Contact.addToCloudInBackground(). \(error)")
            }
        }
        
    }
    
    private func compareUpdate(_ careKit: OCKCarePlan, parse: CarePlan, store: OCKAnyStoreProtocol){
        guard let careKitLastUpdated = careKit.updatedDate,
            let cloudUpdatedAt = parse.locallyUpdatedAt else{
            return
        }
        if cloudUpdatedAt < careKitLastUpdated{
            parse.copyCareKit(careKit, store: store){_ in
                
                //An update may occur when Internet isn't available, try to update at some point
                parse.saveAndCheckRemoteID(store){
                    (success) in
                    
                    if !success{
                        print("Error in CarePlan.updateCloudEventually(). Couldn't update \(careKit)")
                    }else{
                        print("Successfully updated CarePlan \(self) in the Cloud")
                    }
                }
            }
            
        }else if cloudUpdatedAt > careKitLastUpdated {
            //The cloud version is newer than local, update the local version instead
            guard let updatedCarePlanFromCloud = parse.convertToCareKit() else{
                return
            }
            store.updateAnyCarePlan(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                result in
                switch result{
                case .success(_):
                    print("Successfully updated CarePlan \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                case .failure(_):
                    print("Error updating CarePlan \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                }
            }
        }
    }
    
    open func deleteFromCloudEventually(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false){
        guard let _ = User.current() else{
            return
        }
       
        //Get latest item from the Cloud to compare against
        let query = CarePlan.query()!
        query.whereKey(kPCKCarePlanIDKey, equalTo: self.uuid)
        query.findObjectsInBackground{
            (objects, error) in
            guard let foundObject = objects?.first as? CarePlan else{
                return
            }
            self.compareDelete(foundObject, store: store)
        }
    }
    
    func compareDelete(_ parse: CarePlan, store: OCKAnyStoreProtocol){
        guard let careKitLastUpdated = self.locallyUpdatedAt,
            let cloudUpdatedAt = parse.locallyUpdatedAt else{
            return
        }
        
        if cloudUpdatedAt <= careKitLastUpdated{
            parse.deleteInBackground{
                (success, error) in
                if !success{
                    guard let error = error else{return}
                    print("Error in CarePlan.deleteFromCloudEventually(). \(error)")
                }else{
                    print("Successfully deleted CarePlan \(self) in the Cloud")
                }
            }
        }else {
            guard let updatedCarePlanFromCloud = parse.convertToCareKit() else {return}
            store.updateAnyCarePlan(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                result in
                switch result{
                case .success(_):
                    print("Successfully deleting CarePlan \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                case .failure(_):
                    print("Error deleting CarePlan \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                }
            }
        }
    }
    
    open func addToCloudInBackground(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false){
        guard let _ = User.current() else{
            return
        }
        
        let query = CarePlan.query()!
        query.whereKey(kPCKCarePlanIDKey, equalTo: self.uuid)
        query.includeKeys([kPCKCarePlanAuthorKey,kPCKCarePlanPatientKey,kPCKCarePlanNotesKey])
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
                    self.saveAndCheckRemoteID(store){_ in}
                }else{
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).addToCloudInBackground(). \(error.localizedDescription)")
                }
                return
            }
            //If object already in the Cloud, exit
            if foundObjects.count > 0{
                //Maybe this needs to be updated instead
                self.updateCloudEventually(store)
                
            }else{
                self.saveAndCheckRemoteID(store){_ in}
            }
        }
    }
    
    
    private func saveAndCheckRemoteID(_ store: OCKAnyStoreProtocol, completion: @escaping(Bool) -> Void){
        guard let store = store as? OCKStore else{return}
        
        self.saveEventually{(success, error) in
            if success{
                //Only save data back to CarePlanStore if it's never been saved before
                store.fetchCarePlan(withID: self.uuid, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(var mutableEntity):
                        if mutableEntity.remoteID == nil{
                            mutableEntity.remoteID = self.objectId
                            store.updateAnyCarePlan(mutableEntity, callbackQueue: .global(qos: .background)){
                                result in
                                switch result{
                                case .success(_):
                                    print("Successfully added CarePlan \(mutableEntity) to Cloud")
                                    completion(true)
                                case .failure(_):
                                    print("Error in CarePlan.saveAndCheckRemoteID() adding CarePlan \(mutableEntity) to Cloud")
                                    completion(false)
                                }
                            }
                        }else{
                            if mutableEntity.remoteID! != self.objectId{
                                print("Error in \(self.parseClassName).saveAndCheckRemoteID(). remoteId \(mutableEntity.remoteID!) should equal (self.objectId)")
                                completion(false)
                            }else{
                                completion(true)
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
                print("Error in CarePlan.saveAndCheckRemoteID(). \(error)")
                completion(false)
            }
        }
    }
    
    open func copyCareKit(_ carePlanAny: OCKAnyCarePlan, store: OCKAnyStoreProtocol, completion: @escaping(CarePlan?) -> Void){
        
        guard let _ = User.current(),
            let carePlan = carePlanAny as? OCKCarePlan else{
            completion(nil)
            return
        }
        
        self.uuid = carePlan.id
        self.title = carePlan.title
        self.groupIdentifier = carePlan.groupIdentifier
        self.tags = carePlan.tags
        self.source = carePlan.source
        self.asset = carePlan.asset
        self.timezone = carePlan.timezone.abbreviation()!
        self.locallyUpdatedAt = carePlan.updatedDate
        
        //Only copy this over if the Local Version is older than the Parse version
        if self.locallyCreatedAt == nil {
            self.locallyCreatedAt = carePlan.createdDate
        } else if self.locallyCreatedAt != nil && carePlan.createdDate != nil{
            if carePlan.createdDate! < self.locallyCreatedAt!{
                self.locallyCreatedAt = carePlan.createdDate
            }
        }
        
        Note.convertCareKitArrayToParse(carePlan.notes, store: store){
            copiedNotes in
            self.notes = copiedNotes
        
            guard let authorID = carePlan.patientUUID else{
                completion(self)
                return
            }
            //ID's are the same for related Plans
            var query = OCKPatientQuery()
            query.uuids = [authorID]
            store.fetchAnyPatients(query: query, callbackQueue: .global(qos: .background)){
                result in
                switch result{
                case .success(let authors):
                    //Should only be one patient returned
                    guard let careKitAuthor = authors.first else{
                        completion(nil)
                        return
                    }
                    self.authorId = careKitAuthor.id
                    guard let authorRemoteId = careKitAuthor.remoteID else{
                        completion(nil)
                        return
                    }
                    
                    self.author = User(withoutDataWithObjectId: authorRemoteId)
                    
                    //Search for patient
                    if let patientIdToSearchFor = carePlan.userInfo?[kPCKCarePlanUserInfoPatientIDKey]{
                        self.patientId = patientIdToSearchFor
                        var patientQuery = OCKPatientQuery()
                        patientQuery.ids = [patientIdToSearchFor]
                        store.fetchAnyPatients(query: patientQuery, callbackQueue: .global(qos: .background)){
                            result in
                            switch result{
                            case .success(let patients):
                                guard let patient = patients.first,
                                    let patientRemoteId = patient.remoteID else{
                                        completion(nil)
                                    return
                                }
                                self.patient = User(withoutDataWithObjectId: patientRemoteId)
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
        
    }
    
    //Note that CarePlans have to be saved to CareKit first in order to properly convert to CareKit
    open func convertToCareKit()->OCKCarePlan?{
        
        guard let authorID = self.author?.uuid,
            let authorUUID = UUID(uuidString: authorID) else {return nil}
        
        
        var carePlan = OCKCarePlan(id: self.uuid, title: self.title, patientUUID: authorUUID)
        carePlan.groupIdentifier = self.groupIdentifier
        carePlan.tags = self.tags
        carePlan.source = self.source
        carePlan.groupIdentifier = self.groupIdentifier
        carePlan.asset = self.asset
        carePlan.remoteID = self.objectId
        carePlan.notes = self.notes?.compactMap{$0.convertToCareKit()}
        
        if let patientUsingCarePlan = self.patient?.objectId{
            carePlan.userInfo?[kPCKCarePlanUserInfoPatientIDKey] = patientUsingCarePlan
        }
        
        if let timeZone = TimeZone(abbreviation: self.timezone){
            carePlan.timezone = timeZone
        }
        return carePlan
        /*
        var query = OCKPatientQuery()
        query.ids = [authorID]
        store.fetchPatients(query: query, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let authors):
                //Should only be one patient returned
                guard let careKitAuthor = authors.first else{
                    completion(nil)
                    return
                }
                
                var carePlan = OCKCarePlan(id: self.uuid, title: self.title, patientUUID: careKitAuthor.uuid)
                carePlan.groupIdentifier = self.groupIdentifier
                carePlan.tags = self.tags
                carePlan.source = self.source
                carePlan.groupIdentifier = self.groupIdentifier
                carePlan.asset = self.asset
                carePlan.remoteID = self.objectId
                carePlan.notes = self.notes?.compactMap{$0.convertToCareKit()}
                
                if let patientUsingCarePlan = self.patient?.objectId{
                    carePlan.userInfo?[kPCKCarePlanUserInfoPatientIDKey] = patientUsingCarePlan
                }
                
                if let timeZone = TimeZone(abbreviation: self.timezone){
                    carePlan.timezone = timeZone
                }
                
                completion(carePlan)
                    
            case .failure(_):
                completion(nil)
            }
            return
            
        }*/
        
    }
    
    open class func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        let query = CarePlan.query()!
        query.whereKey(kPCKCarePlanClockKey, greaterThanOrEqualTo: localClock)
        query.includeKeys([kPCKCarePlanAuthorKey,kPCKCarePlanPatientKey,kPCKCarePlanNotesKey])
        query.findObjectsInBackground{ (objects,error) in
            guard let carePlans = objects as? [CarePlan] else{
                guard let error = error as NSError?,
                    let errorDictionary = error.userInfo["error"] as? [String:Any],
                    let reason = errorDictionary["routine"] as? String else {return}
                //If the query was looking in a column that wasn't a default column, it will return nil if the table doesn't contain the custom column
                if reason == "errorMissingColumn"{
                    //Saving the new item with the custom column should resolve the issue
                    print("Warning, table CarePlan either doesn't exist or is missing the column \(kPCKOutcomeClockKey). It should be fixed during the first sync of an Outcome...")
                }
                let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
                mergeRevision(revision)
                return
            }
            let pulled = carePlans.compactMap{$0.convertToCareKit()}
            let entities = pulled.compactMap{OCKEntity.carePlan($0)}
            let revision = OCKRevisionRecord(entities: entities, knowledgeVector: cloudVector)
            mergeRevision(revision)
        }
    }
    
    open class func pushRevision(_ store: OCKStore, cloudClock: Int, careKitEntity:OCKEntity){
        switch careKitEntity {
        case .carePlan(let careKit):
            let _ = CarePlan(careKitEntity: careKit, store: store){
                copied in
                guard let parse = copied as? CarePlan else{return}
                parse.clock = cloudClock //Stamp Entity
                if careKit.deletedDate == nil{
                    parse.addToCloudInBackground(store, usingKnowledgeVector: true)
                }else{
                    parse.deleteFromCloudEventually(store, usingKnowledgeVector: true)
                }
            }
        default:
            print("Error in CarePlan.pushRevision(). Received wrong type \(careKitEntity)")
        }
    }
}

