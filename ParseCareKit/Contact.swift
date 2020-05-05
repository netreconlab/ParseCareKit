//
//  Contact.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 NetReconLab. All rights reserved.
//

import Parse
import CareKit


open class Contact: PFObject, PFSubclassing, PCKEntity {

    //1 to 1 between Parse and CareStore
    @NSManaged public var address:[String:String]?
    @NSManaged public var asset:String?
    @NSManaged public var category:String?
    @NSManaged public var emailAddresses:[String:String]?
    @NSManaged public var groupIdentifier:String?
    @NSManaged public var locallyCreatedAt:Date?
    @NSManaged public var locallyUpdatedAt:Date?
    @NSManaged public var messagingNumbers:[String:String]?
    @NSManaged public var name:[String:String]
    @NSManaged public var notes:[Note]?
    @NSManaged public var organization:String?
    @NSManaged public var otherContactInfo:[String:String]?
    @NSManaged public var phoneNumbers:[String:String]?
    @NSManaged public var role:String?
    @NSManaged public var source:String?
    @NSManaged public var tags:[String]?
    @NSManaged public var timezone:String
    @NSManaged public var title:String?
    
    @NSManaged public var carePlan:CarePlan?
    @NSManaged public var carePlanId:String?

    //Not 1 to 1
    @NSManaged public var user:User?
    @NSManaged public var author:User
    
    //UserInfo fields on CareStore
    @NSManaged public var uuid:String //maps to id

    public static func parseClassName() -> String {
        return kPCKContactClassKey
    }

    public convenience init(careKitEntity: OCKAnyContact, storeManager: OCKSynchronizedStoreManager, completion: @escaping(PCKEntity?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, storeManager: storeManager, completion: completion)
    }
    
    open func updateCloudEventually(_ storeManager: OCKSynchronizedStoreManager){
        guard let _ = User.current() else{
            return
        }
        
        storeManager.store.fetchAnyContact(withID: self.uuid, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let fetchedContact):
                guard let contact = fetchedContact as? OCKContact else{return}
                guard let remoteID = contact.remoteID else{
                    
                    //Check to see if this entity is already in the Cloud, but not matched locally
                    let query = Contact.query()!
                    query.whereKey(kPCKContactIdKey, equalTo: contact.id)
                    query.findObjectsInBackground{
                        (objects, error) in
                        
                        guard let foundObject = objects?.first as? Contact else{
                            return
                        }
                        self.compareUpdate(contact, parse: foundObject, storeManager: storeManager)
                        
                    }
                    return
                }
                
                //Get latest item from the Cloud to compare against
                let query = Contact.query()!
                query.whereKey(kPCKContactObjectIdKey, equalTo: remoteID)
                query.includeKey(kPCKContactAuthorKey)
                query.findObjectsInBackground{
                    (objects, error) in
                    
                    guard let foundObject = objects?.first as? Contact else{
                        return
                    }
                    self.compareUpdate(contact, parse: foundObject, storeManager: storeManager)
                }
            case .failure(let error):
                print("Error adding contact to cloud \(error)")
            }
        }
    }
    
    func compareUpdate(_ careKit: OCKContact, parse: Contact, storeManager: OCKSynchronizedStoreManager){
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
                        print("Error in \(self.parseClassName).updateCloudEventually(). Couldn't update \(careKit)")
                    }else{
                        print("Successfully updated Contact \(parse) in the Cloud")
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
                storeManager.store.updateAnyContact(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(_):
                        print("Successfully updated Contact \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    case .failure(_):
                        print("Error updating Contact \(updatedCarePlanFromCloud) from the Cloud to CareStore")
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
        let query = Contact.query()!
        query.whereKey(kPCKContactIdKey, equalTo: self.uuid)
        query.includeKey(kPCKContactAuthorKey)
        query.findObjectsInBackground{
            (objects, error) in
            guard let foundObject = objects?.first as? Contact else{
                return
            }
            self.compareDelete(foundObject, storeManager: storeManager)
        }
    }
    
    func compareDelete(_ parse: Contact, storeManager: OCKSynchronizedStoreManager){
        guard let careKitLastUpdated = self.locallyUpdatedAt,
            let cloudUpdatedAt = parse.locallyUpdatedAt else{
            return
        }
        
        if cloudUpdatedAt <= careKitLastUpdated{
            parse.deleteInBackground{
                (success, error) in
                if !success{
                    guard let error = error else{return}
                    print("Error in Contact.deleteFromCloudEventually(). \(error)")
                }else{
                    print("Successfully deleted Contact \(self) in the Cloud")
                }
            }
        }else {
            parse.convertToCareKit(storeManager){
                converted in
                //The updated version in the cloud is newer, local delete has already occured, so updated the device with the newer one from the cloud
                guard let updatedCarePlanFromCloud = converted else{
                    return
                }
                storeManager.store.updateAnyContact(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                    result in
                    
                    switch result{
                        
                    case .success(_):
                        print("Successfully deleting Contact \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    case .failure(_):
                        print("Error deleting Contact \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    }
                }
            }
        }
    }
    
    open func addToCloudInBackground(_ storeManager: OCKSynchronizedStoreManager){
        
        //Check to see if already in the cloud
        let query = Contact.query()!
        query.whereKey(kPCKContactIdKey, equalTo: self.uuid)
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
    
    func saveAndCheckRemoteID(_ storeManager: OCKSynchronizedStoreManager, completion: @escaping(Bool) -> Void){
        self.saveEventually{(success, error) in
            if success{
                print("Successfully saved \(self) in Cloud.")
                //Need to save remoteId for this and all relational data
                storeManager.store.fetchAnyContact(withID: self.uuid, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(let fetchedContact):
                        guard var mutableEntity = fetchedContact as? OCKContact else{return}
                        if mutableEntity.remoteID == nil{
                            mutableEntity.remoteID = self.objectId
                            storeManager.store.updateAnyContact(mutableEntity){
                                result in
                                switch result{
                                case .success(let updatedContact):
                                    print("Updated remoteID of Contact \(updatedContact)")
                                    completion(true)
                                case .failure(let error):
                                    print("Error in Contact.saveAndCheckRemoteID() updating remoteID of Contact. \(error)")
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
                        print("Error adding contact to cloud \(error)")
                        completion(false)
                    }
                }
                
            }else{
                guard let error = error else{
                    completion(false)
                    return
                }
                print("Error in Contact.saveAndCheckRemoteID(). \(error)")
                completion(false)
            }
        }
    }
    
    open func copyCareKit(_ contactAny: OCKAnyContact, storeManager: OCKSynchronizedStoreManager, completion: @escaping(Contact?) -> Void){
        
        guard let _ = User.current(),
            let contact = contactAny as? OCKContact else{
            completion(nil)
            return
        }
        
        self.uuid = contact.id
        self.groupIdentifier = contact.groupIdentifier
        self.tags = contact.tags
        self.source = contact.source
        self.title = contact.title
        self.role = contact.role
        self.organization = contact.organization
        self.category = contact.category?.rawValue
        self.asset = contact.asset
        self.timezone = contact.timezone.abbreviation()!
        self.name = CareKitParsonNameComponents.familyName.convertToDictionary(contact.name)
        
        self.locallyUpdatedAt = contact.updatedDate
        
        //Only copy this over if the Local Version is older than the Parse version
        if self.locallyCreatedAt == nil {
            self.locallyCreatedAt = contact.createdDate
        } else if self.locallyCreatedAt != nil && contact.createdDate != nil{
            if contact.createdDate! < self.locallyCreatedAt!{
                self.locallyCreatedAt = contact.createdDate
            }
        }
        
        if let emails = contact.emailAddresses{
            var emailAddresses = [String:String]()
            
            for email in emails{
                emailAddresses[email.label] = email.value
            }
            
            self.emailAddresses = emailAddresses
        }
        
        if let others = contact.otherContactInfo{
            
            var otherContactInfo = [String:String]()
            
            for other in others{
                otherContactInfo[other.label] = other.value
            }
           
            self.otherContactInfo = otherContactInfo
        }
        
        if let numbers = contact.phoneNumbers{
            var phoneNumbers = [String:String]()
            for number in numbers{
                phoneNumbers[number.label] = number.value
            }
            
            self.phoneNumbers = phoneNumbers
        }
        
        if let numbers = contact.messagingNumbers{
            var messagingNumbers = [String:String]()
            for number in numbers{
                messagingNumbers[number.label] = number.value
            }
            
            self.messagingNumbers = messagingNumbers
        }
        
        self.address = CareKitPostalAddress.city.convertToDictionary(contact.address)
        
        guard let authorID = contact.userInfo?[kPCKContactUserInfoAuthorUserIDKey] else{
            return
        }
        var query = OCKPatientQuery(for: Date())
        query.ids = [authorID]
        
        var patientRelatedID:String? = nil
        if let relatedID = contact.userInfo?[kPCKContactUserInfoRelatedUUIDKey] {
            patientRelatedID = relatedID
            query.ids.append(relatedID)
        }
        
        storeManager.store.fetchAnyPatients(query: query, callbackQueue: .global(qos: .background)){
            result in
            
            switch result{
            case .success(let fetchedPatients):
                guard let patientsFound = fetchedPatients as? [OCKPatient] else{return}
                let foundAuthor = patientsFound.filter{$0.id == authorID}.first
                
                guard let theAuthor = foundAuthor else{return}
                
                if let authorRemoteID = theAuthor.remoteID{
                    
                    self.author = User(withoutDataWithObjectId: authorRemoteID)
                    
                    self.copyRelatedPatient(patientRelatedID, patients: patientsFound){
                        self.copyNotesAndCarePlan(contact, storeManager: storeManager){
                            completion(self)
                        }
                    }
                }else{
                    let userQuery = User.query()!
                    userQuery.whereKey(kPCKUserIdKey, equalTo: theAuthor.id)
                    userQuery.findObjectsInBackground(){
                        (objects, error) in
                        
                        guard let authorFound = objects?.first as? User else{
                            completion(self)
                            return
                        }
                        
                        self.author = authorFound
                        
                        self.copyRelatedPatient(patientRelatedID, patients: patientsFound){
                            self.copyNotesAndCarePlan(contact, storeManager: storeManager){
                                completion(self)
                            }
                        }
                    }
                }
            case .failure(_):
                completion(nil)
            }
        }
        
    }
    
    func copyRelatedPatient(_ relatedPatientID:String?, patients:[OCKPatient], completion: @escaping() -> Void){
        
        guard let id = relatedPatientID else{
            completion()
            return
        }
        
        let relatedPatient = patients.filter{$0.id == id}.first
        
        guard let patient = relatedPatient else{
            completion()
            return
        }
        
        guard let relatedRemoteId = patient.remoteID else{
            
            let query = User.query()!
            query.whereKey(kPCKUserIdKey, equalTo: patient.id)
            query.findObjectsInBackground(){
                (objects,error) in
                
                guard let found = objects?.first as? User else{
                    return
                }
                
                self.user = found
                
                completion()
                return
            }
            return
        }
            
        self.user = User.init(withoutDataWithObjectId: relatedRemoteId)
        completion()
    }
    
    func copyNotesAndCarePlan(_ contact:OCKContact, storeManager: OCKSynchronizedStoreManager, completion: @escaping() -> Void){
        
        Note.convertCareKitArrayToParse(contact.notes, storeManager: storeManager){
            copiedNotes in
            self.notes = copiedNotes
            //contactInfoDictionary[kPCKContactNotes] = copiedNotes
            guard let carePlanID = contact.carePlanID else{
                completion()
                return
            }
            //ID's are the same for related Plans
            var query = OCKCarePlanQuery()
            query.versionIDs = [carePlanID]
            storeManager.store.fetchAnyCarePlans(query: query, callbackQueue: .global(qos: .background)){
                result in
                    switch result{
                    case .success(let carePlans):
                        guard let carePlan = carePlans.first else{
                            completion()
                            return
                        }
                        self.carePlanId = carePlan.id
                        guard let carePlanRemoteID = carePlan.remoteID else{
                            
                            let carePlanQuery = CarePlan.query()!
                            carePlanQuery.whereKey(kPCKCarePlanIDKey, equalTo: carePlan.id)
                            carePlanQuery.findObjectsInBackground(){
                                (objects, error) in
                                
                                guard let carePlanFound = objects?.first as? CarePlan else{
                                    completion()
                                    return
                                }
                                
                                self.carePlan = carePlanFound
                                completion()
                            }
                            return
                        }
                        
                        self.carePlan = CarePlan(withoutDataWithObjectId: carePlanRemoteID)
                        completion()
                        
                    case .failure(_):
                        completion()
                    }
                }
            }
        }

    

    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit(_ storeManager: OCKSynchronizedStoreManager, completion: @escaping(OCKContact?) -> Void){
        
        let nameComponents = CareKitParsonNameComponents.familyName.convertToPersonNameComponents(self.name)
        var contact = OCKContact(id: self.uuid, name: nameComponents, carePlanID: nil)
        
        contact.role = self.role
        contact.title = self.title
        
        if let categoryToConvert = self.category{
            contact.category = OCKContactCategory(rawValue: categoryToConvert)
        }
        
        contact.groupIdentifier = self.groupIdentifier
        contact.tags = self.tags
        contact.source = self.source
        
        var convertedUserInfo = [
            kPCKContactUserInfoAuthorUserIDKey: self.author.uuid
        ]
        
        if let relatedUser = self.user {
            convertedUserInfo[kPCKContactUserInfoRelatedUUIDKey] = relatedUser.uuid
        }
        
        contact.userInfo = convertedUserInfo
        
        contact.organization = self.organization
        contact.address = CareKitPostalAddress.city.convertToPostalAddress(self.address)
        if let parseCategory = self.category{
            contact.category = OCKContactCategory(rawValue: parseCategory)
        }
        contact.groupIdentifier = self.groupIdentifier
        contact.asset = self.asset
        if let timeZone = TimeZone(abbreviation: self.timezone){
            contact.timezone = timeZone
        }
        //contact.effectiveDate = self.effectiveDate
        contact.address = CareKitPostalAddress.city.convertToPostalAddress(self.address)
        contact.remoteID = self.objectId
        
        if let numbers = self.phoneNumbers{
            var numbersToSave = [OCKLabeledValue]()
            for (key,value) in numbers{
                numbersToSave.append(OCKLabeledValue(label: key, value: value))
            }
            
            contact.phoneNumbers = numbersToSave
        }
        
        if let numbers = self.messagingNumbers{
            var numbersToSave = [OCKLabeledValue]()
            for (key,value) in numbers{
                numbersToSave.append(OCKLabeledValue(label: key, value: value))
            }
            
            contact.messagingNumbers = numbersToSave
        }
        
        if let labeledValues = self.emailAddresses{
            var labledValuesToSave = [OCKLabeledValue]()
            for (key,value) in labeledValues{
                labledValuesToSave.append(OCKLabeledValue(label: key, value: value))
            }
            
            contact.emailAddresses = labledValuesToSave
        }
        
        if let labeledValues = self.otherContactInfo{
            var labledValuesToSave = [OCKLabeledValue]()
            for (key,value) in labeledValues{
                labledValuesToSave.append(OCKLabeledValue(label: key, value: value))
            }
            
            contact.otherContactInfo = labledValuesToSave
        }
        
        guard let carePlanID = self.carePlan?.uuid else{
            completion(contact)
            return
        }
        //Outcomes can only be converted if they have a relationship with a task locally
        storeManager.store.fetchAnyCarePlan(withID: carePlanID){
            result in
            
            switch result{
            case .success(let fetchedCarePlan):
                
                guard let carePlan = fetchedCarePlan as? OCKCarePlan,
                    let carePlanID = carePlan.localDatabaseID else{
                    return
                }
                
                contact.carePlanID = carePlanID
                completion(contact)
                
            case .failure(_):
                completion(nil)
        
            }
        
        }
        
    }
}

