//
//  Contact.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore


open class Contact: PCKVersionedObject, PCKRemoteSynchronized {

    //1 to 1 between Parse and CareStore
    @NSManaged public var address:[String:String]?
    @NSManaged public var category:String?
    @NSManaged public var name:[String:String]
    @NSManaged public var organization:String?
    @NSManaged public var emailAddressesDictionary:[String:String]?
    @NSManaged public var messagingNumbersDictionary:[String:String]?
    @NSManaged public var otherContactInfoDictionary:[String:String]?
    @NSManaged public var phoneNumbersDictionary:[String:String]?
    @NSManaged public var role:String?
    @NSManaged public var title:String?
    @NSManaged public var carePlan:CarePlan?
    
    var messagingNumbers: [OCKLabeledValue]? {
        get { messagingNumbersDictionary?.asLabeledValues() }
        set { messagingNumbersDictionary = newValue?.asDictionary() }
    }

    var emailAddresses: [OCKLabeledValue]? {
        get { emailAddressesDictionary?.asLabeledValues() }
        set { emailAddressesDictionary = newValue?.asDictionary() }
    }

    var phoneNumbers: [OCKLabeledValue]? {
        get { phoneNumbersDictionary?.asLabeledValues() }
        set { phoneNumbersDictionary = newValue?.asDictionary() }
    }

    var otherContactInfo: [OCKLabeledValue]? {
        get { otherContactInfoDictionary?.asLabeledValues() }
        set { otherContactInfoDictionary = newValue?.asDictionary() }
    }
    
    public static func parseClassName() -> String {
        return kPCKContactClassKey
    }

    public convenience init(careKitEntity: OCKAnyContact, store: OCKAnyStoreProtocol, completion: @escaping(PCKObject?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, clone: true, store: store, completion: completion)
    }
    
    public func new() -> PCKRemoteSynchronized {
        return CarePlan()
    }
    
    public func new(with careKitEntity: OCKEntity, store: OCKStore, completion: @escaping(PCKRemoteSynchronized?)-> Void){
        switch careKitEntity {
        case .contact(let entity):
            self.copyCareKit(entity, clone: true, store: store, completion: completion)
        default:
            print("Error in \(parseClassName).new(with:). The wrong type of entity was passed \(careKitEntity)")
        }
    }
    
    public func addToCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        
        guard let contactUUID = UUID(uuidString: self.uuid) else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if already in the cloud
        let query = Contact.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: contactUUID.uuidString)
        query.includeKeys([kPCKContactCarePlanKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
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
                        self.logicalClock = 0
                    }
                    PCKObject.saveAndCheckRemoteID(self, store: store, completion: completion)
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
                    self.logicalClock = 0
                }
                PCKObject.saveAndCheckRemoteID(self, store: store, completion: completion)
            }
        }
    }
    
    public func updateCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current(),
            let store = store as? OCKStore,
            let contactUUID = UUID(uuidString: self.uuid) else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        var careKitQuery = OCKContactQuery()
        careKitQuery.uuids = [contactUUID]
        
        store.fetchContacts(query: careKitQuery, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let contacts):
                
                guard let contact = contacts.first else{
                    completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                    return
                }
                    
                guard let remoteID = contact.remoteID else{
                    
                    //Check to see if this entity is already in the Cloud, but not matched locally
                    let query = Contact.query()!
                    query.whereKey(kPCKObjectUUIDKey, equalTo: contactUUID.uuidString)
                    query.includeKeys([kPCKContactCarePlanKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
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
                query.whereKey(kPCKParseObjectIdKey, equalTo: remoteID)
                query.includeKeys([kPCKContactCarePlanKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
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
    
    public func deleteFromCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current(),
            let store = store as? OCKStore,
            let contactUUID = UUID(uuidString: self.uuid) else{
                completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Get latest item from the Cloud to compare against
        let query = Contact.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: contactUUID.uuidString)
        query.getFirstObjectInBackground(){
            (object, error) in
            guard let foundObject = object as? Contact else{
                completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                return
            }
            self.compareDelete(foundObject, store: store, completion: completion)
        }
    }
    
    public func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        let query = Contact.query()!
        query.whereKey(kPCKObjectClockKey, greaterThanOrEqualTo: localClock)
        query.includeKeys([kPCKContactCarePlanKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
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
                    print("Warning, table Contact either doesn't exist or is missing the column \(kPCKObjectClockKey). It should be fixed during the first sync of an Outcome...")
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
    
    public func pushRevision(_ store: OCKStore, overwriteRemote: Bool, cloudClock: Int, completion: @escaping (Error?) -> Void){
        self.logicalClock = cloudClock //Stamp Entity
        if self.deletedDate == nil{
            self.addToCloud(store, usingKnowledgeVector: true, overwriteRemote: overwriteRemote){
                (success,error) in
                if success{
                    completion(nil)
                }else{
                    completion(error)
                }
            }
        }else{
            self.deleteFromCloud(store, usingKnowledgeVector: true){
                (success,error) in
                if success{
                    completion(nil)
                }else{
                    completion(error)
                }
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
        
        if let uuid = contact.uuid?.uuidString{
            self.uuid = uuid
        }else{
            print("Warning in \(parseClassName).copyCareKit(). Entity missing uuid: \(contact)")
        }
        
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
        self.timezoneIdentifier = contact.timezone.abbreviation()!
        self.name = CareKitPersonNameComponents.familyName.convertToDictionary(contact.name)
        self.updatedDate = contact.updatedDate
        self.userInfo = contact.userInfo
        
        if clone{
            self.createdDate = contact.createdDate
            self.notes = contact.notes?.compactMap{Note(careKitEntity: $0)}
        }else{
            //Only copy this over if the Local Version is older than the Parse version
            if self.createdDate == nil {
                self.createdDate = contact.createdDate
            } else if self.createdDate != nil && contact.createdDate != nil{
                if contact.createdDate! < self.createdDate!{
                    self.createdDate = contact.createdDate
                }
            }
            self.notes = Note.updateIfNeeded(self.notes, careKit: contact.notes)
        }
        
        self.emailAddresses = contact.emailAddresses
        self.otherContactInfo = contact.otherContactInfo
        self.phoneNumbers = contact.phoneNumbers
        self.messagingNumbers = contact.messagingNumbers
        self.address = CareKitPostalAddress.city.convertToDictionary(contact.address)
        
        //Setting up CarePlan query
        var uuidsToQuery = [UUID]()
        if let previousUUID = contact.previousVersionUUID{
            uuidsToQuery.append(previousUUID)
        }else{
            self.previous = nil
        }
        if let nextUUID = contact.nextVersionUUID{
            uuidsToQuery.append(nextUUID)
        }else{
            self.next = nil
        }
        
        if uuidsToQuery.isEmpty{
            self.previous = nil
            self.next = nil
            
            guard let carePlanUUID = contact.uuid else{
                completion(self)
                return
            }
            self.fetchRelatedCarePlan(carePlanUUID, store: store){
                carePlan in
                if carePlan != nil && contact.carePlanUUID != nil{
                    self.carePlan = carePlan
                    completion(self)
                }else if carePlan == nil && contact.carePlanUUID == nil{
                    completion(self)
                }else{
                    completion(nil)
                }
            }
        }else{
            var query = OCKContactQuery()
            query.uuids = uuidsToQuery
            store.fetchContacts(query: query, callbackQueue: .global(qos: .background)){
                results in
                switch results{
                    
                case .success(let entities):
                    let previousRemoteId = entities.filter{$0.uuid == contact.previousVersionUUID}.first?.remoteID
                    if previousRemoteId != nil && contact.previousVersionUUID != nil{
                        self.previous = Contact(withoutDataWithObjectId: previousRemoteId!)
                    }else if previousRemoteId == nil && contact.previousVersionUUID == nil{
                        self.previous = nil
                    }else{
                        completion(nil)
                        return
                    }
                    
                    let nextRemoteId = entities.filter{$0.uuid == contact.nextVersionUUID}.first?.remoteID
                    if nextRemoteId != nil{
                        self.next = Contact(withoutDataWithObjectId: nextRemoteId!)
                    }
                case .failure(let error):
                    print("Error in \(self.parseClassName).copyCareKit(). Error \(error)")
                    self.previous = nil
                    self.next = nil
                }
                
                guard let carePlanUUID = contact.uuid else{
                    completion(self)
                    return
                }
                self.fetchRelatedCarePlan(carePlanUUID, store: store){
                    carePlan in
                    if carePlan != nil && contact.carePlanUUID != nil{
                        self.carePlan = carePlan
                        completion(self)
                    }else if carePlan == nil && contact.carePlanUUID == nil{
                        completion(self)
                    }else{
                        completion(nil)
                    }
                }
            }
        }
    }
    
    
    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit(fromCloud:Bool=true)->OCKContact?{
        
        //Create bare Entity and replace contents with Parse contents
        let nameComponents = CareKitPersonNameComponents.familyName.convertToPersonNameComponents(self.name)
        var contact = OCKContact(id: self.entityId, name: nameComponents, carePlanUUID: nil)
        
        if fromCloud{
            guard let decodedContact = decodedCareKitObject(contact) else{
                print("Error in \(parseClassName). Couldn't decode entity \(self)")
                return nil
            }
            contact = decodedContact
        }
        
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
        if let timeZone = TimeZone(abbreviation: self.timezoneIdentifier){
            contact.timezone = timeZone
        }
        
        contact.address = CareKitPostalAddress.city.convertToPostalAddress(self.address)
        contact.remoteID = self.objectId
        contact.phoneNumbers = self.phoneNumbers
        contact.messagingNumbers = self.messagingNumbers
        contact.emailAddresses = self.emailAddresses
        contact.otherContactInfo = self.otherContactInfo
        
        guard let carePlanID = self.carePlan?.uuid,
            let carePlanUUID = UUID(uuidString: carePlanID) else{
            return contact
        }
        contact.carePlanUUID = carePlanUUID
        return contact
    }
}


private extension Dictionary where Key == String, Value == String {
    func asLabeledValues() -> [OCKLabeledValue] {
        let sortedKeys = keys.sorted()
        return sortedKeys.map { OCKLabeledValue(label: $0, value: self[$0]!) }
    }
}

private extension Array where Element == OCKLabeledValue {
    func asDictionary() -> [String: String] {
        var dictionary = [String: String]()
        for labeldValue in self {
            dictionary[labeldValue.label] = labeldValue.value
        }
        return dictionary
    }
}

