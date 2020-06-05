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
    @NSManaged public var role:String?
    @NSManaged public var title:String?
    @NSManaged var carePlan:CarePlan?
    @NSManaged var carePlanUUIDString:String?
    
    public var carePlanUUID:UUID? {
        get {
            if carePlan != nil{
                return UUID(uuidString: carePlan!.uuid)
            }else if carePlanUUIDString != nil {
                return UUID(uuidString: carePlanUUIDString!)
            }else{
                return nil
            }
        }
        set{
            carePlanUUIDString = newValue?.uuidString
            if newValue?.uuidString != carePlan?.uuid{
                carePlan = nil
            }
        }
    }
    
    public var currentCarePlan: CarePlan?{
        get{
            return carePlan
        }
        set{
            carePlan = newValue
            carePlanUUIDString = newValue?.uuid
        }
    }
    
    @NSManaged var emailAddressesArray:[String]?
    @NSManaged var messagingNumbersArray:[String]?
    @NSManaged var otherContactInfoArray:[String]?
    @NSManaged var phoneNumbersArray:[String]?
    
    var messagingNumbers: [OCKLabeledValue]? {
        get {
            do{
                return try messagingNumbersArray?.asDecodedLabeledValues()
            }
            catch{
                return nil
            }
        }
        set {
            do {
                try messagingNumbersArray = newValue?.asEncodedStringArray()
            }catch{
                print(error)
            }
        }
    }

    var emailAddresses: [OCKLabeledValue]? {
        get {
            do{
                return try emailAddressesArray?.asDecodedLabeledValues()
            }
            catch{
                return nil
            }
        }
        set {
            do {
                try emailAddressesArray = newValue?.asEncodedStringArray()
            }catch{
                print(error)
            }
        }
    }

    var phoneNumbers: [OCKLabeledValue]? {
        get {
            do{
                return try phoneNumbersArray?.asDecodedLabeledValues()
            }
            catch{
                return nil
            }
        }
        set {
            do {
                try phoneNumbersArray = newValue?.asEncodedStringArray()
            }catch{
                print(error)
            }
        }
    }

    var otherContactInfo: [OCKLabeledValue]? {
        get {
            do{
                return try otherContactInfoArray?.asDecodedLabeledValues()
            }
            catch{
                return nil
            }
        }
        set {
            do {
                try otherContactInfoArray = newValue?.asEncodedStringArray()
            }catch{
                print(error)
            }
        }
    }
    
    public static func parseClassName() -> String {
        return kPCKContactClassKey
    }

    public convenience init(careKitEntity: OCKAnyContact) {
        self.init()
        _ = self.copyCareKit(careKitEntity)
    }
    
    open func new() -> PCKSynchronized {
        return Contact()
    }
    
    open func new(with careKitEntity: OCKEntity)-> PCKSynchronized?{
        
        switch careKitEntity {
        case .contact(let entity):
            return Contact(careKitEntity: entity)
            
        default:
            print("Error in \(parseClassName).new(with:). The wrong type of entity was passed \(careKitEntity)")
            return nil
        }
    }
    
    public func addToCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        
        guard let _ = PFUser.current() else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if already in the cloud
        let query = Contact.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: self.uuid)
        query.getFirstObjectInBackground(){
            (object, error) in
            
            guard let _ = object as? Contact else{
                guard let parseError = error as NSError? else{
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).addToCloud(). \(String(describing: error?.localizedDescription))")
                    completion(false,error)
                    return
                }
                
                switch parseError.code{
                    case 1,101: //1 - this column hasn't been added. 101 - Query returned no results
                        self.save(self, completion: completion)
                default:
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).addToCloud(). \(String(describing: error?.localizedDescription))")
                    completion(false,error)
                }
                return
            }
            
            completion(false,ParseCareKitError.uuidAlreadyExists)
        }
    }
    
    public func updateCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current(),
            let previousContactUUIDString = self.previousVersionUUID?.uuidString else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if this entity is already in the Cloud, but not matched locally
        let query = Contact.query()!
        query.whereKey(kPCKObjectUUIDKey, containedIn: [self.uuid,previousContactUUIDString])
        query.includeKeys([kPCKContactCarePlanKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.findObjectsInBackground(){
            (objects, error) in
            
            guard let foundObjects = objects as? [Contact] else{
                print("Error in \(self.parseClassName).updateCloud(). \(String(describing: error?.localizedDescription))")
                completion(false,error)
                return
            }
            
            switch foundObjects.count{
            case 0:
                print("Warning in \(self.parseClassName).updateCloud(). A previous version is suppose to exist in the Cloud, but isn't present, saving as new")
                self.addToCloud(completion: completion)
            case 1:
                //This is the typical case
                guard let previousVersion = foundObjects.filter({$0.uuid == previousContactUUIDString}).first else {
                    print("Error in \(self.parseClassName).updateCloud(). Didn't find previousVersion and this UUID already exists in Cloud")
                    completion(false,ParseCareKitError.uuidAlreadyExists)
                    return
                }
                self.copyRelationalEntities(previousVersion)
                self.addToCloud(completion: completion)

            default:
                print("Error in \(self.parseClassName).updateCloud(). UUID already exists in Cloud")
                completion(false,ParseCareKitError.uuidAlreadyExists)
            }
        }
    }
    
    public func deleteFromCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        //Handled with update, marked for deletion
        completion(true,nil)
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
    
    public func pushRevision(_ overwriteRemote: Bool, cloudClock: Int, completion: @escaping (Error?) -> Void){
        
        self.logicalClock = cloudClock //Stamp Entity
        
        guard let _ = self.previousVersionUUID else{
            self.addToCloud(true, overwriteRemote: overwriteRemote){
                (success,error) in
                if success{
                    completion(nil)
                }else{
                    completion(error)
                }
            }
            return
        }
        
        self.updateCloud(true, overwriteRemote: overwriteRemote){
            (success,error) in
            if success{
                completion(nil)
            }else{
                completion(error)
            }
        }
    }
    
    open override func copy(_ parse: PCKObject){
        super.copy(parse)
        guard let parse = parse as? Contact else{return}
        self.address = parse.address
        self.category = parse.category
        self.title = parse.title
        self.name = parse.name
        self.organization = parse.organization
        self.role = parse.role
        self.currentCarePlan = parse.currentCarePlan
        self.carePlanUUID = parse.carePlanUUID
    }

    open func copyCareKit(_ contactAny: OCKAnyContact)-> Contact?{
        
        guard let _ = PFUser.current(),
            let contact = contactAny as? OCKContact else{
            return nil
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
        self.createdDate = contact.createdDate
        self.notes = contact.notes?.compactMap{Note(careKitEntity: $0)}
        self.emailAddresses = contact.emailAddresses
        self.otherContactInfo = contact.otherContactInfo
        self.phoneNumbers = contact.phoneNumbers
        self.messagingNumbers = contact.messagingNumbers
        self.address = CareKitPostalAddress.city.convertToDictionary(contact.address)
        self.remoteID = contact.remoteID
        
        self.carePlanUUID = contact.carePlanUUID
        self.previousVersionUUID = contact.previousVersionUUID
        self.nextVersionUUID = contact.nextVersionUUID
        return self
    }
    
    
    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit(fromCloud:Bool=true)->OCKContact?{
        
        //Create bare Entity and replace contents with Parse contents
        let nameComponents = CareKitPersonNameComponents.familyName.convertToPersonNameComponents(self.name)
        
        var contact = OCKContact(id: self.entityId, name: nameComponents, carePlanUUID: self.carePlanUUID)
        
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
        contact.remoteID = self.remoteID
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
        contact.phoneNumbers = self.phoneNumbers
        contact.messagingNumbers = self.messagingNumbers
        contact.emailAddresses = self.emailAddresses
        contact.otherContactInfo = self.otherContactInfo
        if let effectiveDate = self.effectiveDate{
            contact.effectiveDate = effectiveDate
        }
        return contact
    }
    
    ///Link versions and related classes
    public override func linkRelated(completion: @escaping(Bool,Contact)->Void){
        super.linkRelated(){
            (isNew, _) in
            var linkedNew = isNew
            
            guard let carePlanUUID = self.carePlanUUID else{
                //Finished if there's no CarePlan, otherwise see if it's in the cloud
                completion(linkedNew,self)
                return
            }
            
            self.getFirstPCKObject(carePlanUUID, classType: CarePlan(), relatedObject: self.carePlan, includeKeys: true){
                (isNew,carePlan) in
                
                guard let carePlan = carePlan as? CarePlan else{
                    completion(linkedNew,self)
                    return
                }
                
                self.carePlan = carePlan
                if isNew{
                    linkedNew = true
                }
                completion(linkedNew,self)
            }
        }
    }
}


private extension Dictionary where Key == String, Value == String {
    func asLabeledValues() -> [OCKLabeledValue] {
        let sortedKeys = keys.sorted()
        return sortedKeys.map { OCKLabeledValue(label: $0, value: self[$0]!) }
    }
}

public extension Array where Element == String {
    func asDecodedLabeledValues() throws -> [OCKLabeledValue]{
        var labeled = [OCKLabeledValue]()
        try self.forEach{
            guard let data = $0.data(using: .utf8) else{
                print("Error in asDecodedLabeledValues(). Coudn't get string as utf8. \($0)")
                return
            }
            labeled.append(try JSONDecoder().decode(OCKLabeledValue.self, from: data))
        }
        return labeled
    }
}

public extension Array where Element == OCKLabeledValue {
    func asDictionary() -> [String: String] {
        var dictionary = [String: String]()
        for labeledValue in self {
            dictionary[labeledValue.label] = labeledValue.value
        }
        return dictionary
    }
    
    func asEncodedStringArray() throws -> [String] {
        var stringArray = [String]()
        try self.forEach{
            let data = try JSONEncoder().encode($0)
            guard let string = String(data: data, encoding: .utf8) else{
                print("Error in asEncodedStringArray(). Coudn't encode as utf8. \($0)")
                return
            }
            stringArray.append(string)
        }
        
        return stringArray
    }
}

