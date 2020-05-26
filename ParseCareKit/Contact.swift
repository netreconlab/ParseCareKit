//
//  Contact.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore


open class Contact: PFObject, PFSubclassing, PCKSynchronizedEntity, PCKRemoteSynchronizedEntity {

    //1 to 1 between Parse and CareStore
    @NSManaged public var address:[String:String]?
    @NSManaged public var asset:String?
    @NSManaged public var category:String?
    @NSManaged public var deletedDate:Date?
    @NSManaged public var effectiveDate:Date
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
    @NSManaged public var userInfo:[String:String]?
    @NSManaged public var carePlan:CarePlan?
    @NSManaged public var uuid:String
    @NSManaged public var nextVersionUUID:String?
    @NSManaged public var previousVersionUUID:String?
    @NSManaged public var entityId:String //maps to id
    
    //Not 1 to 1
    @NSManaged public var patient:Patient?
    @NSManaged public var patientEntityId:String?
    @NSManaged public var author:Patient
    @NSManaged public var clock:Int
    

    public static func parseClassName() -> String {
        return kPCKContactClassKey
    }

    public convenience init(careKitEntity: OCKAnyContact, store: OCKAnyStoreProtocol, completion: @escaping(PCKSynchronizedEntity?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, clone: true, store: store, completion: completion)
    }
    
    open func updateCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current(),
            let store = store as? OCKStore,
            let contactUUID = UUID(uuidString: self.uuid) else{
            completion(false,nil)
            return
        }
        
        var careKitQuery = OCKContactQuery()
        careKitQuery.uuids = [contactUUID]
        
        store.fetchContacts(query: careKitQuery, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let contacts):
                
                guard let contact = contacts.first else{
                    completion(false,nil)
                    return
                }
                    
                guard let remoteID = contact.remoteID else{
                    
                    //Check to see if this entity is already in the Cloud, but not matched locally
                    let query = Contact.query()!
                    query.whereKey(kPCKContactUUIDKey, equalTo: contactUUID.uuidString)
                    query.includeKeys([kPCKContactAuthorKey,kPCKContactPatientKey,kPCKContactCarePlanKey,kPCKCarePlanNotesKey])
                    query.getFirstObjectInBackground(){
                        (object, error) in
                        
                        guard let foundObject = object as? Contact else{
                            completion(false,error)
                            return
                        }
                        self.compareUpdate(contact, parse: foundObject, store: store, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
                    }
                    return
                }
                
                //Get latest item from the Cloud to compare against
                let query = Contact.query()!
                query.whereKey(kPCKContactObjectIdKey, equalTo: remoteID)
                query.includeKeys([kPCKContactAuthorKey,kPCKContactPatientKey,kPCKContactCarePlanKey,kPCKCarePlanNotesKey])
                query.includeKey(kPCKContactAuthorKey)
                query.getFirstObjectInBackground(){
                    (object, error) in
                    
                    guard let foundObject = object as? Contact else{
                        completion(false,error)
                        return
                    }
                    self.compareUpdate(contact, parse: foundObject, store: store, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
                }
            case .failure(let error):
                print("Error adding contact to cloud \(error)")
                completion(false,error)
            }
        }
    }
    
    func compareUpdate(_ careKit: OCKContact, parse: Contact, store: OCKStore, usingKnowledgeVector: Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void){
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
                            print("Error in \(self.parseClassName).updateCloud(). Couldn't update \(careKit)")
                        }else{
                            print("Successfully updated Contact \(parse) in the Cloud")
                        }
                        completion(success,error)
                    }
                }
            }else if ((cloudUpdatedAt > careKitLastUpdated) || overwriteRemote) {
                //The cloud version is newer than local, update the local version instead
                guard let updatedCarePlanFromCloud = parse.convertToCareKit() else{
                    completion(false,nil)
                    return
                }
                store.updateAnyContact(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(_):
                        print("Successfully updated Contact \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                        completion(true,nil)
                    case .failure(let error):
                        print("Error updating Contact \(updatedCarePlanFromCloud) from the Cloud to CareStore")
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
                            print("Error in \(self.parseClassName).updateCloud(). Couldn't update \(careKit)")
                        }else{
                            print("Successfully updated Contact \(parse) in the Cloud")
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
            let store = store as? OCKStore,
            let contactUUID = UUID(uuidString: self.uuid) else{
                completion(false,nil)
            return
        }
        
        //Get latest item from the Cloud to compare against
        let query = Contact.query()!
        query.whereKey(kPCKContactUUIDKey, equalTo: contactUUID.uuidString)
        query.getFirstObjectInBackground(){
            (object, error) in
            guard let foundObject = object as? Contact else{
                completion(false,nil)
                return
            }
            self.compareDelete(foundObject, store: store, completion: completion)
        }
    }
    
    func compareDelete(_ parse: Contact, store: OCKStore, completion: @escaping(Bool,Error?) -> Void){
        guard let careKitLastUpdated = self.locallyUpdatedAt,
            let cloudUpdatedAt = parse.locallyUpdatedAt else{
                completion(false,nil)
            return
        }
        
        if cloudUpdatedAt <= careKitLastUpdated{
            parse.deleteInBackground{
                (success, error) in
                if !success{
                    guard let error = error else{return}
                    print("Error in Contact.deleteFromCloud(). \(error)")
                }else{
                    print("Successfully deleted Contact \(self) in the Cloud")
                }
                completion(success,error)
            }
        }else {
            //The updated version in the cloud is newer, local delete has already occured, so updated the device with the newer one from the cloud
            guard let updatedCarePlanFromCloud = parse.convertToCareKit() else{
                completion(false,nil)
                return
            }
            store.updateAnyContact(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                result in
                
                switch result{
                    
                case .success(_):
                    print("Successfully deleting Contact \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    completion(true,nil)
                case .failure(let error):
                    print("Error deleting Contact \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    completion(false,error)
                }
            }
        }
    }
    
    open func addToCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        
        guard let contactUUID = UUID(uuidString: self.uuid) else{
            completion(false,nil)
            return
        }
        
        //Check to see if already in the cloud
        let query = Contact.query()!
        query.whereKey(kPCKContactUUIDKey, equalTo: contactUUID.uuidString)
        query.includeKeys([kPCKContactAuthorKey,kPCKContactPatientKey,kPCKContactCarePlanKey,kPCKCarePlanNotesKey])
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
                    self.saveAndCheckRemoteID(store, completion: completion)
                }else{
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).addToCloud(). \(error.localizedDescription)")
                    completion(false,error)
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
    
    func saveAndCheckRemoteID(_ store: OCKAnyStoreProtocol, completion: @escaping(Bool,Error?) -> Void){
        guard let store = store as? OCKStore,
            let contactUUID = UUID(uuidString: self.uuid) else{
            completion(false,nil)
            return
        }
        stampRelationalEntities()
        self.saveInBackground{(success, error) in
            if success{
                print("Successfully saved \(self) in Cloud.")
                //Need to save remoteId for this and all relational data
                var careKitQuery = OCKContactQuery()
                careKitQuery.uuids = [contactUUID]
                store.fetchContacts(query: careKitQuery, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(let entities):
                        guard var mutableEntity = entities.first else{
                            completion(false,nil)
                            return
                        }
                        if mutableEntity.remoteID == nil{
                            mutableEntity.remoteID = self.objectId
                            store.updateAnyContact(mutableEntity){
                                result in
                                switch result{
                                case .success(let updatedContact):
                                    print("Updated remoteID of Contact \(updatedContact)")
                                    completion(true,nil)
                                case .failure(let error):
                                    print("Error in Contact.saveAndCheckRemoteID() updating remoteID of Contact. \(error)")
                                    completion(false,error)
                                }
                            }
                        }else{
                            if mutableEntity.remoteID! != self.objectId{
                                print("Error in \(self.parseClassName).saveAndCheckRemoteID(). remoteId \(mutableEntity.remoteID!) should equal \(self.objectId!)")
                                completion(false,nil)
                            }else{
                                completion(true,nil)
                            }
                        }
                        
                    case .failure(let error):
                        print("Error adding contact to cloud \(error)")
                        completion(false,error)
                    }
                }
                
            }else{
                print("Error in Contact.saveAndCheckRemoteID(). \(String(describing: error))")
                completion(false,error)
            }
        }
    }
    
    open func copyCareKit(_ contactAny: OCKAnyContact, clone: Bool, store: OCKAnyStoreProtocol, completion: @escaping(Contact?) -> Void){
        
        guard let _ = PFUser.current(),
            let contact = contactAny as? OCKContact,
            let store = store as? OCKStore else{
            completion(nil)
            return
        }
        guard let uuid = contact.uuid?.uuidString else{
            print("Error in \(parseClassName). Entity missing uuid: \(contact)")
            completion(nil)
            return
        }
        self.uuid = uuid
        self.previousVersionUUID = contact.nextVersionUUID?.uuidString
        self.nextVersionUUID = contact.previousVersionUUID?.uuidString
        self.entityId = contact.id
        self.deletedDate = contact.deletedDate
        self.groupIdentifier = contact.groupIdentifier
        self.tags = contact.tags
        self.source = contact.source
        self.title = contact.title
        self.role = contact.role
        self.organization = contact.organization
        self.category = contact.category?.rawValue
        self.asset = contact.asset
        self.timezone = contact.timezone.abbreviation()!
        self.name = CareKitPersonNameComponents.familyName.convertToDictionary(contact.name)
        self.locallyUpdatedAt = contact.updatedDate
        self.userInfo = contact.userInfo
        
        if clone{
            self.locallyCreatedAt = contact.createdDate
            self.notes = contact.notes?.compactMap{Note(careKitEntity: $0)}
        }else{
            //Only copy this over if the Local Version is older than the Parse version
            if self.locallyCreatedAt == nil {
                self.locallyCreatedAt = contact.createdDate
            } else if self.locallyCreatedAt != nil && contact.createdDate != nil{
                if contact.createdDate! < self.locallyCreatedAt!{
                    self.locallyCreatedAt = contact.createdDate
                }
            }
            self.notes = Note.updateIfNeeded(self.notes, careKit: contact.notes)
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
        
        guard let authorUUIDString = contact.userInfo?[kPCKContactUserInfoAuthorUUIDKey],
            let authorUUID = UUID(uuidString: authorUUIDString) else{
            completion(self)
            return
        }
        var query = OCKPatientQuery(for: Date())
        query.uuids = [authorUUID]
        
        var patientRelatedUUID:UUID? = nil
        if let relatedPatientUUIDString = contact.userInfo?[kPCKContactUserInfoRelatedUUIDKey] {
            if let relatedPatientUUID = UUID(uuidString: relatedPatientUUIDString){
                patientRelatedUUID = relatedPatientUUID
                query.uuids.append(relatedPatientUUID)
            }
        }
        
        store.fetchPatients(query: query, callbackQueue: .global(qos: .background)){
            result in
            
            switch result{
            case .success(let patientsFound):
                let foundAuthor = patientsFound.filter{$0.uuid == authorUUID}.first
                guard let theAuthor = foundAuthor else{return}
                
                if let authorRemoteID = theAuthor.remoteID{
                    
                    self.author = Patient(withoutDataWithObjectId: authorRemoteID)
                    self.copyRelatedPatient(patientRelatedUUID, patients: patientsFound){
                        _ in
                        self.copyCarePlan(contact, store: store){
                            _ in
                            completion(self)
                        }
                    }
                }else{
                    let userQuery = Patient.query()!
                    userQuery.whereKey(kPCKPatientUUIDKey, equalTo: authorUUID)
                    userQuery.getFirstObjectInBackground(){
                        (object, error) in
                        
                        guard let authorFound = object as? Patient else{
                            completion(self)
                            return
                        }
                        
                        self.author = authorFound
                        
                        self.copyRelatedPatient(patientRelatedUUID, patients: patientsFound){
                            _ in
                            self.copyCarePlan(contact, store: store){
                                _ in
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
    
    func copyRelatedPatient(_ relatedPatientUUID:UUID?, patients:[OCKPatient], completion: @escaping(Patient?) -> Void){
        
        guard let uuid = relatedPatientUUID else{
            completion(nil)
            return
        }
        
        let relatedPatient = patients.filter{$0.uuid == uuid}.first
        
        guard let patient = relatedPatient else{
            completion(nil)
            return
        }
        
        guard let relatedRemoteId = patient.remoteID else{
            
            let query = Patient.query()!
            query.whereKey(kPCKPatientUUIDKey, equalTo: uuid.uuidString)
            query.getFirstObjectInBackground(){
                (object,error) in
                
                guard let found = object as? Patient else{
                    completion(nil)
                    return
                }
                
                self.patient = found
                
                completion(self.patient)
                return
            }
            return
        }
            
        self.patient = Patient.init(withoutDataWithObjectId: relatedRemoteId)
        completion(self.patient)
    }
    
    func copyCarePlan(_ contact:OCKContact, store: OCKStore, completion: @escaping(CarePlan?) -> Void){
        
        //contactInfoDictionary[kPCKContactNotes] = copiedNotes
        guard let carePlanUUID = contact.carePlanUUID else{
            completion(nil)
            return
        }
        //ID's are the same for related Plans
        var query = OCKCarePlanQuery()
        query.uuids = [carePlanUUID]
        store.fetchCarePlans(query: query, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let carePlans):
                guard let carePlan = carePlans.first,
                    let carePlanRemoteID = carePlan.remoteID else{
                    
                    let carePlanQuery = CarePlan.query()!
                    carePlanQuery.whereKey(kPCKCarePlanUUIDKey, equalTo: carePlanUUID.uuidString)
                    carePlanQuery.getFirstObjectInBackground(){
                        (object, error) in
                        
                        guard let carePlanFound = object as? CarePlan else{
                            completion(nil)
                            return
                        }
                        
                        self.carePlan = carePlanFound
                        completion(carePlanFound)
                    }
                    return
                }
                self.carePlan = CarePlan(withoutDataWithObjectId: carePlanRemoteID)
                completion(self.carePlan)
                
            case .failure(let error):
                print("Error in Contact.copyCarePlan(). \(error)")
                completion(nil)
            }
        }
    }

    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit()->OCKContact?{
        
        guard var contact = createDecodedEntity() else{return nil}
        contact.role = self.role
        contact.title = self.title
        
        if let categoryToConvert = self.category{
            contact.category = OCKContactCategory(rawValue: categoryToConvert)
        }
        
        contact.groupIdentifier = self.groupIdentifier
        contact.tags = self.tags
        contact.source = self.source
        contact.userInfo = self.userInfo
        
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
        
        guard let carePlanID = self.carePlan?.uuid,
            let carePlanUUID = UUID(uuidString: carePlanID) else{
            return contact
        }
        contact.carePlanUUID = carePlanUUID
        return contact
    }
    
    open class func getEntityAsJSONDictionary(_ entity: OCKContact)->[String:Any]?{
        let jsonDictionary:[String:Any]
        do{
            let data = try JSONEncoder().encode(entity)
            jsonDictionary = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers,.mutableLeaves]) as! [String:Any]
        }catch{
            print("Error in Contact.getEntityAsJSONDictionary(). \(error)")
            return nil
        }
        
        return jsonDictionary
    }
    
    open func createDecodedEntity()->OCKContact?{
        guard let createdDate = self.locallyCreatedAt?.timeIntervalSinceReferenceDate,
            let updatedDate = self.locallyUpdatedAt?.timeIntervalSinceReferenceDate else{
                print("Error in \(parseClassName).createDecodedEntity(). Missing either locallyCreatedAt \(String(describing: locallyCreatedAt)) or locallyUpdatedAt \(String(describing: locallyUpdatedAt))")
            return nil
        }
            
        let nameComponents = CareKitPersonNameComponents.familyName.convertToPersonNameComponents(self.name)
        let tempEntity = OCKContact(id: self.entityId, name: nameComponents, carePlanUUID: nil)
        //Create bare CareKit entity from json
        guard var json = Contact.getEntityAsJSONDictionary(tempEntity) else{return nil}
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
        let entity:OCKContact!
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            entity = try JSONDecoder().decode(OCKContact.self, from: data)
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
        
        let query = Contact.query()!
        query.whereKey(kPCKContactClockKey, greaterThanOrEqualTo: localClock)
        query.includeKeys([kPCKContactAuthorKey,kPCKContactPatientKey,kPCKContactCarePlanKey,kPCKCarePlanNotesKey])
        query.findObjectsInBackground{ (objects,error) in
            guard let carePlans = objects as? [Contact] else{
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
                    print("Warning, table Contact either doesn't exist or is missing the column \(kPCKOutcomeClockKey). It should be fixed during the first sync of an Outcome...")
                }
                mergeRevision(revision)
                return
            }
            let pulled = carePlans.compactMap{$0.convertToCareKit()}
            let entities = pulled.compactMap{OCKEntity.contact($0)}
            let revision = OCKRevisionRecord(entities: entities, knowledgeVector: cloudVector)
            mergeRevision(revision)
        }
    }
    
    class func pushRevision(_ store: OCKStore, overwriteRemote: Bool, cloudClock: Int, careKitEntity:OCKEntity, completion: @escaping (Error?) -> Void){
        switch careKitEntity {
        case .contact(let careKit):
            let _ = Contact(careKitEntity: careKit, store: store){
                copied in
                guard let parse = copied as? Contact else{
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
            print("Error in Contact.pushRevision(). Received wrong type \(careKitEntity)")
            completion(nil)
        }
    }
}

