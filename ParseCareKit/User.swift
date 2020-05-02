//
//  Users.swift
//  ParseCareKit
//
//  Created by Corey Baker on 10/5/19.
//  Copyright © 2019 NetReconLab. All rights reserved.
//

import Parse
import CareKit

protocol PCKAnyUser: PCKEntity {
    func updateCloudEventually(_ patient: OCKAnyPatient, storeManager: OCKSynchronizedStoreManager)
    func deleteFromCloudEventually(_ patient: OCKAnyPatient, storeManager: OCKSynchronizedStoreManager)
}

open class User: PFUser, PCKAnyUser {
    //1 to 1 between Parse and CareStore
    @NSManaged public var alergies:[String]?
    @NSManaged public var asset:String?
    @NSManaged public var birthday:Date?
    @NSManaged public var groupIdentifier:String?
    @NSManaged public var locallyCreatedAt:Date?
    @NSManaged public var locallyUpdatedAt:Date?
    @NSManaged public var name:[String:String]
    @NSManaged public var notes:[Note]?
    @NSManaged public var sex:String?
    @NSManaged public var source:String?
    @NSManaged public var tags:[String]?
    @NSManaged public var timezone:String
    
    //Not 1 to 1
    @NSManaged public var uuid:String

    public convenience init(careKitEntity: OCKAnyPatient, storeManager: OCKSynchronizedStoreManager, completion: @escaping(PCKEntity?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, storeManager: storeManager, completion: completion)
    }
    
    open func updateCloudEventually(_ patient: OCKAnyPatient, storeManager: OCKSynchronizedStoreManager){
        guard let _ = User.current(),
            let castedPatient = patient as? OCKPatient else{
            return
        }
        
        guard let remoteID = castedPatient.remoteID else{
            
            //Check to see if this entity is already in the Cloud, but not paired locally
            let query = User.query()!
            query.whereKey(kPCKUserIdKey, equalTo: patient.id)
            query.findObjectsInBackground{
                (objects, error) in
                
                guard let foundObject = objects?.first as? User else{
                    return
                }
                self.compareUpdate(castedPatient, parse: foundObject, storeManager: storeManager)
            }
            return
        }
        
        //Get latest item from the Cloud to compare against
        let query = User.query()!
        query.whereKey(kPCKUserObjectIdKey, equalTo: remoteID)
        query.findObjectsInBackground{
            (objects, error) in
            
            guard let foundObject = objects?.first as? User else{
                return
            }
            self.compareUpdate(castedPatient, parse: foundObject, storeManager: storeManager)
        }
    }
    
    func compareUpdate(_ careKit: OCKPatient, parse: User, storeManager: OCKSynchronizedStoreManager){
        guard let careKitLastUpdated = careKit.updatedDate,
            let cloudUpdatedAt = parse.locallyUpdatedAt else{
            parse.copyCareKit(careKit, storeManager: storeManager){
                _ in
                
                //An update may occur when Internet isn't available, try to update at some point
                parse.saveEventually{
                    (success,error) in
                    
                    if !success{
                        guard let error = error else{return}
                        print("Error in User.updateCloudEventually(). \(error)")
                    }else{
                        print("Successfully updated Patient \(self) in the Cloud")
                    }
                }
            }
            return
        }
        if cloudUpdatedAt < careKitLastUpdated{
            parse.copyCareKit(careKit, storeManager: storeManager){
                _ in
                //An update may occur when Internet isn't available, try to update at some point
                parse.saveEventually{
                    (success,error) in
                    
                    if !success{
                        guard let error = error else{return}
                        print("Error in User.updateCloudEventually(). \(error)")
                    }else{
                        print("Successfully updated Patient \(self) in the Cloud")
                    }
                }
                
            }
            
        }else if cloudUpdatedAt > careKitLastUpdated{
            //The cloud version is newer than local, update the local version instead
            guard let updatedPatientFromCloud = parse.convertToCareKit() else{
                return
            }
            storeManager.store.updateAnyPatient(updatedPatientFromCloud, callbackQueue: .global(qos: .background)){
                result in
                
                switch result{
                    
                case .success(_):
                    print("Successfully updated Patient \(updatedPatientFromCloud) from the Cloud to CareStore")
                case .failure(_):
                    print("Error updating Patient \(updatedPatientFromCloud) from the Cloud to CareStore")
                }
            }
        }
    }
    
    open func deleteFromCloudEventually(_ patient: OCKAnyPatient, storeManager: OCKSynchronizedStoreManager){
        guard let _ = User.current(),
            let castedPatient = patient as? OCKPatient else{
            return
        }
        
        guard let remoteID = castedPatient.remoteID else{
            
            //Check to see if this entity is already in the Cloud, but not paired locally
            let query = User.query()!
            query.whereKey(kPCKUserIdKey, equalTo: patient.id)
            query.findObjectsInBackground{
                (objects, error) in
                
                guard let foundObject = objects?.first as? User else{
                    return
                }
                self.compareDelete(castedPatient, parse: foundObject, storeManager: storeManager)
            }
            return
        }
        
        //Get latest item from the Cloud to compare against
        let query = User.query()!
        query.whereKey(kPCKUserObjectIdKey, equalTo: remoteID)
        query.findObjectsInBackground{
            (objects, error) in
            
            guard let foundObject = objects?.first as? User else{
                return
            }
            self.compareDelete(castedPatient, parse: foundObject, storeManager: storeManager)
        }
    }
    
    func compareDelete(_ careKit: OCKPatient, parse: User, storeManager: OCKSynchronizedStoreManager){
        guard let careKitLastUpdated = careKit.updatedDate,
            let cloudUpdatedAt = parse.locallyUpdatedAt else{
            return
        }
        
        if cloudUpdatedAt <= careKitLastUpdated{
            parse.deleteInBackground{
                (success, error) in
                if !success{
                    guard let error = error else{return}
                    print("Error in User.deleteFromCloudEventually(). \(error)")
                }else{
                    print("Successfully deleted User \(self) in the Cloud")
                }
            }
        }else {
            guard let updatedCarePlanFromCloud = parse.convertToCareKit() else {return}
            storeManager.store.updateAnyPatient(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                result in
                switch result{
                case .success(_):
                    print("Successfully deleting User \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                case .failure(_):
                    print("Error deleting User \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                }
            }
        }
    }
    
    open func addToCloudInBackground(_ storeManager: OCKSynchronizedStoreManager){
        guard let _ = User.current() else{
            return
        }

        storeManager.store.fetchAnyPatient(withID: self.uuid, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let fetchedPatient):
                guard let patient = fetchedPatient as? OCKPatient else{return}
                //Check to see if already in the cloud
                let query = User.query()!
                query.whereKey(kPCKUserIdKey, equalTo: patient.id)
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
                            self.saveAndCheckRemoteID(patient, storeManager: storeManager)
                        }else{
                            //There was a different issue that we don't know how to handle
                            print("Error in \(self.parseClassName).addToCloudInBackground(). \(error.localizedDescription)")
                        }
                        return
                    }
                    //If object already in the Cloud, exit
                    if foundObjects.count > 0{
                        //Maybe this needs to be updated instead
                        self.updateCloudEventually(patient, storeManager: storeManager)
                        return
                    }
                    self.saveAndCheckRemoteID(patient, storeManager: storeManager)
                }
            case .failure(let error):
                print("Error in Contact.addToCloudInBackground(). \(error)")
            }
        }
    }
    
    func saveAndCheckRemoteID(_ careKitEntity: OCKPatient, storeManager: OCKSynchronizedStoreManager){
        self.saveEventually{
            (success, error) in
            if success{
                print("Successfully saved \(self) in Cloud.")
                //Only save data back to CarePlanStore if it's never been saved before
                if careKitEntity.remoteID == nil{
                    var updatedPatient = careKitEntity
                    updatedPatient.remoteID = self.objectId!
                    storeManager.store.updateAnyPatient(updatedPatient, callbackQueue: .global(qos: .background)){
                        result in
                        switch result{
                        case .success(_):
                            print("Successfully added Patient \(updatedPatient) to Cloud")
                        case .failure(let error):
                            print("Error in User.addToCloudInBackground() adding Patient \(updatedPatient) to Cloud. \(error)")
                        }
                    }
                }
            }else{
                guard let error = error else{
                    return
                }
                print("Error in User.addToCloudInBackground(). \(error)")
            }
        }
    }
    
    open func copyCareKit(_ patientAny: OCKAnyPatient, storeManager: OCKSynchronizedStoreManager, completion: @escaping(User?)->Void){
        
        guard let _ = User.current(),
            let patient = patientAny as? OCKPatient else{
            completion(nil)
            return
        }
        
        self.uuid = patient.id
        self.name = CareKitParsonNameComponents.familyName.convertToDictionary(patient.name)
        self.birthday = patient.birthday
        self.sex = patient.sex?.rawValue
        self.locallyUpdatedAt = patient.updatedDate
        
        //Only copy this over if the Local Version is older than the Parse version
        if self.locallyCreatedAt == nil {
            self.locallyCreatedAt = patient.createdDate
        } else if self.locallyCreatedAt != nil && patient.createdDate != nil{
            if patient.createdDate! < self.locallyCreatedAt!{
                self.locallyCreatedAt = patient.createdDate
            }
        }
        
        self.timezone = patient.timezone.abbreviation()!
        
        Note.convertCareKitArrayToParse(patient.notes, storeManager: storeManager){
            copiedNotes in
            self.notes = copiedNotes
            completion(self)
        }
    }
    
    open func convertToCareKit()->OCKPatient?{
        
        let nameComponents = CareKitParsonNameComponents.familyName.convertToPersonNameComponents(self.name)
        var patient = OCKPatient(id: self.uuid, name: nameComponents)
        
        patient.birthday = self.birthday
        patient.remoteID = self.objectId
        patient.allergies = self.alergies
        patient.groupIdentifier = self.groupIdentifier
        patient.tags = self.tags
        patient.source = self.source
        patient.asset = self.asset
        patient.notes = self.notes?.compactMap{$0.convertToCareKit()}
        if let timeZone = TimeZone(abbreviation: self.timezone){
            patient.timezone = timeZone
        }
        if let sex = self.sex{
            patient.sex = OCKBiologicalSex(rawValue: sex)
        }
        return patient
    }
}
