//
//  CarePlan.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 NetReconLab. All rights reserved.
//

import Parse
import CareKit

protocol PCKAnyCarePlan: PCKEntity {
    func addToCloudInBackground(_ storeManager: OCKSynchronizedStoreManager)
    func updateCloudEventually(_ carePlan: OCKAnyCarePlan, storeManager: OCKSynchronizedStoreManager)
    func deleteFromCloudEventually(_ carePlan: OCKAnyCarePlan, storeManager: OCKSynchronizedStoreManager)
}

open class CarePlan: PFObject, PFSubclassing, PCKAnyCarePlan {

    //Parse only
    @NSManaged public var userUploadedToCloud:User?
    @NSManaged public var userDeliveredToDestination:User?
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
    
    //SOSDatabase info
    @NSManaged public var sosDeliveredToDestinationAt:Date? //When was the outcome posted D2D
    
    public static func parseClassName() -> String {
        return kPCKCarePlanClassKey
    }
    
    public convenience init(careKitEntity: OCKAnyCarePlan, storeManager: OCKSynchronizedStoreManager, completion: @escaping(PCKEntity?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, storeManager: storeManager, completion: completion)
    }
    
    open func updateCloudEventually(_ carePlan: OCKAnyCarePlan, storeManager: OCKSynchronizedStoreManager){
        guard let _ = User.current(),
            let castedCarePlan = carePlan as? OCKCarePlan else{
            return
        }
        guard let remoteID = castedCarePlan.remoteID else{
            
            //Check to see if this entity is already in the Cloud, but not matched locally
            let query = CarePlan.query()!
            query.whereKey(kPCKCarePlanIDKey, equalTo: carePlan.id)
            query.findObjectsInBackground{
                (objects, error) in
                guard let foundObject = objects?.first as? CarePlan else{
                    return
                }
                self.compareUpdate(castedCarePlan, parse: foundObject, storeManager: storeManager)
                
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
            self.compareUpdate(castedCarePlan, parse: foundObject, storeManager: storeManager)
        }
    }
    
    private func compareUpdate(_ careKit: OCKCarePlan, parse: CarePlan, storeManager: OCKSynchronizedStoreManager){
        guard let careKitLastUpdated = careKit.updatedDate,
            let cloudUpdatedAt = parse.locallyUpdatedAt else{
            return
        }
        if cloudUpdatedAt < careKitLastUpdated{
            self.copyCareKit(careKit, storeManager: storeManager){returnedCarePlan in
                
                guard let copiedCarePlan = returnedCarePlan else{
                    return
                }
                
                //An update may occur when Internet isn't available, try to update at some point
                copiedCarePlan.saveEventually{
                    (success,error) in
                    
                    if !success{
                        guard let error = error else{return}
                        print("Error in CarePlan.updateCloudEventually(). \(error)")
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
    
    open func deleteFromCloudEventually(_ carePlan: OCKAnyCarePlan, storeManager: OCKSynchronizedStoreManager){
        guard let _ = User.current(),
            let castedCarePlan = carePlan as? OCKCarePlan else{
            return
        }
        guard let remoteID = castedCarePlan.remoteID else{
            //Check to see if this entity is already in the Cloud, but not matched locally
            let query = CarePlan.query()!
            query.whereKey(kPCKCarePlanIDKey, equalTo: carePlan.id)
            query.findObjectsInBackground{
                (objects, error) in
                guard let foundObject = objects?.first as? CarePlan else{
                    return
                }
                self.compareDelete(castedCarePlan, parse: foundObject, storeManager: storeManager)
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
            self.compareDelete(castedCarePlan, parse: foundObject, storeManager: storeManager)
        }
    }
    
    func compareDelete(_ careKit: OCKCarePlan, parse: CarePlan, storeManager: OCKSynchronizedStoreManager){
        guard let careKitLastUpdated = careKit.updatedDate,
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
        storeManager.store.fetchAnyCarePlan(withID: self.uuid, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let fetchedCarePlan):
                guard let carePlan = fetchedCarePlan as? OCKCarePlan else{return}
                //Check to see if already in the cloud
                let query = CarePlan.query()!
                query.whereKey(kPCKCarePlanIDKey, equalTo: carePlan.id)
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
                            self.saveAndCheckRemoteID(carePlan, storeManager: storeManager)
                        }else{
                            //There was a different issue that we don't know how to handle
                            print("Error in \(self.parseClassName).addToCloudInBackground(). \(error.localizedDescription)")
                        }
                        return
                    }
                    //If object already in the Cloud, exit
                    if foundObjects.count > 0{
                        //Maybe this needs to be updated instead
                        self.updateCloudEventually(carePlan, storeManager: storeManager)
                        return
                    }
                    self.saveAndCheckRemoteID(carePlan, storeManager: storeManager)
                }
            case .failure(let error):
                print("Error in Contact.addToCloudInBackground(). \(error)")
            }
        }
    }
    
    
    private func saveAndCheckRemoteID(_ careKitEntity: OCKCarePlan, storeManager: OCKSynchronizedStoreManager){
        self.saveEventually{(success, error) in
            if success{
                //Only save data back to CarePlanStore if it's never been saved before
                if careKitEntity.remoteID == nil{
                    //Make a mutable version of the CarePlan
                    var mutableEntity = careKitEntity
                    mutableEntity.remoteID = self.objectId
                    storeManager.store.updateAnyCarePlan(mutableEntity, callbackQueue: .global(qos: .background)){
                        result in
                        switch result{
                        case .success(_):
                            print("Successfully added CarePlan \(mutableEntity) to Cloud")
                        case .failure(_):
                            print("Error in CarePlan.saveAndCheckRemoteID() adding CarePlan \(mutableEntity) to Cloud")
                        }
                    }
                }
            }else{
                guard let error = error else{
                    return
                }
                print("Error in CarePlan.saveAndCheckRemoteID(). \(error)")
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
        
        guard let authorID = self.author?.uuid else {return}
        var query = OCKPatientQuery()
        query.ids = [authorID]
        storeManager.store.fetchAnyPatients(query: query, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let authors):
                //Should only be one patient returned
                guard let careKitAuthor = authors.first as? OCKPatient else{
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

