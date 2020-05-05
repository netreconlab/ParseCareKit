//
//  CarePlan.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 NetReconLab. All rights reserved.
//

import Parse
import CareKit


open class CarePlan: PFObject, PFSubclassing, PCKEntity {

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
    
    public static func parseClassName() -> String {
        return kPCKCarePlanClassKey
    }
    
    public convenience init(careKitEntity: OCKAnyCarePlan, storeManager: OCKSynchronizedStoreManager, completion: @escaping(PCKEntity?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, storeManager: storeManager, completion: completion)
    }
    
    open func updateCloudEventually(_ storeManager: OCKSynchronizedStoreManager){
        guard let _ = User.current(),
            let store = storeManager.store as? OCKStore else{
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
                    query.findObjectsInBackground{
                        (objects, error) in
                        guard let foundObject = objects?.first as? CarePlan else{
                            return
                        }
                        self.compareUpdate(carePlan, parse: foundObject, storeManager: storeManager)
                        
                    }
                    return
                }
                //Get latest item from the Cloud to compare against
                let query = CarePlan.query()!
                query.whereKey(kPCKCarePlanObjectIdKey, equalTo: remoteID)
                query.findObjectsInBackground{
                    (objects, error) in
                    guard let foundObject = objects?.first as? CarePlan else{
                        return
                    }
                    self.compareUpdate(carePlan, parse: foundObject, storeManager: storeManager)
                }
            case .failure(let error):
                print("Error in Contact.addToCloudInBackground(). \(error)")
            }
        }
        
    }
    
    private func compareUpdate(_ careKit: OCKCarePlan, parse: CarePlan, storeManager: OCKSynchronizedStoreManager){
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
                        print("Error in CarePlan.updateCloudEventually(). Couldn't update \(careKit)")
                    }else{
                        print("Successfully updated CarePlan \(self) in the Cloud")
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
                storeManager.store.updateAnyCarePlan(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
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
    }
    
    open func deleteFromCloudEventually(_ storeManager: OCKSynchronizedStoreManager){
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
            self.compareDelete(foundObject, storeManager: storeManager)
        }
    }
    
    func compareDelete(_ parse: CarePlan, storeManager: OCKSynchronizedStoreManager){
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
            parse.convertToCareKit(storeManager){
                converted in
                guard let updatedCarePlanFromCloud = converted else {return}
                storeManager.store.updateAnyCarePlan(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
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
    }
    
    open func addToCloudInBackground(_ storeManager: OCKSynchronizedStoreManager){
        guard let _ = User.current() else{
            return
        }
        
        let query = CarePlan.query()!
        query.whereKey(kPCKCarePlanIDKey, equalTo: self.uuid)
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
                //Only save data back to CarePlanStore if it's never been saved before
                store.fetchCarePlan(withID: self.uuid, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(var mutableEntity):
                        if mutableEntity.remoteID == nil{
                            mutableEntity.remoteID = self.objectId
                            storeManager.store.updateAnyCarePlan(mutableEntity, callbackQueue: .global(qos: .background)){
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
    
    open func copyCareKit(_ carePlanAny: OCKAnyCarePlan, storeManager: OCKSynchronizedStoreManager, completion: @escaping(CarePlan?) -> Void){
        
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
        
        Note.convertCareKitArrayToParse(carePlan.notes, storeManager: storeManager){
            copiedNotes in
            self.notes = copiedNotes
        
            guard let authorID = carePlan.patientID else{
                completion(self)
                return
            }
            //ID's are the same for related Plans
            var query = OCKPatientQuery()
            query.versionIDs = [authorID]
            storeManager.store.fetchAnyPatients(query: query, callbackQueue: .global(qos: .background)){
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
                        storeManager.store.fetchAnyPatients(query: patientQuery, callbackQueue: .global(qos: .background)){
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
    open func convertToCareKit(_ storeManager: OCKSynchronizedStoreManager, completion: @escaping(OCKCarePlan?) -> Void){
        
        guard let authorID = self.author?.uuid,
            let store = storeManager.store as? OCKStore else {return}
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
                
                var carePlan = OCKCarePlan(id: self.uuid, title: self.title, patientID: careKitAuthor.localDatabaseID)
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
            
        }
        
    }
}

