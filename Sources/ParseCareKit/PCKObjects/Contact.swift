//
//  Contact.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore


public class Contact: PCKVersionedObject, PCKRemoteSynchronized {

    //1 to 1 between Parse and CareStore
    public var address:OCKPostalAddress?
    public var category:OCKContactCategory?
    public var name:PersonNameComponents?
    public var organization:String?
    public var role:String?
    public var title:String?
    var carePlan:CarePlan? {
        didSet {
            carePlanUUID = carePlan?.uuid
        }
    }
    var carePlanUUID:UUID? {
        didSet{
            if carePlanUUID != carePlan?.uuid {
                carePlan = nil
            }
        }
    }
    /*
    var emailAddressesArray:[String]?
    var messagingNumbersArray:[String]?
    var otherContactInfoArray:[String]?
    var phoneNumbersArray:[String]?*/
    
    var messagingNumbers: [OCKLabeledValue]? /*{
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
    }*/

    var emailAddresses: [OCKLabeledValue]? /*{
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
    }*/

    var phoneNumbers: [OCKLabeledValue]? /*{
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
    }*/

    var otherContactInfo: [OCKLabeledValue]? /*{
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
    }*/
    
    public convenience init?(careKitEntity: OCKAnyContact) {
        self.init()
        do {
            _ = try self.copyCareKit(careKitEntity)
        } catch {
            return nil
        }
    }
    
    public override init() {
        super.init()
    }

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    enum CodingKeys: String, CodingKey {
        case carePlan, title, carePlanUUID, address, category, name, organization, role
        case emailAddresses, messagingNumbers, phoneNumbers, otherContactInfo
    }
    
    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        if encodingForParse {
            try container.encode(carePlan, forKey: .carePlan)
        }
        
        try container.encode(title, forKey: .title)
        try container.encode(carePlanUUID, forKey: .carePlanUUID)
        try container.encode(address, forKey: .address)
        try container.encode(category, forKey: .category)
        try container.encode(name, forKey: .name)
        try container.encode(organization, forKey: .organization)
        try container.encode(role, forKey: .role)
        try container.encode(emailAddresses, forKey: .emailAddresses)
        try container.encode(messagingNumbers, forKey: .messagingNumbers)
        try container.encode(phoneNumbers, forKey: .phoneNumbers)
        try container.encode(otherContactInfo, forKey: .otherContactInfo)
    }
    
    open func new() -> PCKSynchronized {
        return Contact()
    }
    
    open func new(with careKitEntity: OCKEntity)-> PCKSynchronized?{
        
        switch careKitEntity {
        case .contact(let entity):
            return Contact(careKitEntity: entity)
            
        default:
            print("Error in \(className).new(with:). The wrong type of entity was passed \(careKitEntity)")
            return nil
        }
    }
    
    public func addToCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        
        guard let _ = PCKUser.current,
              let uuid = self.uuid else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if already in the cloud
        let query = Contact.query(kPCKObjectableUUIDKey == uuid)
        query.first(callbackQueue: .global(qos: .background)){ result in
            
            switch result {
            
            case .success(_):
                completion(false,ParseCareKitError.uuidAlreadyExists)

            case .failure(let error):
                switch error.code {
                case .internalServer, .objectNotFound: //1 - this column hasn't been added. 101 - Query returned no results
                        self.save(self, completion: completion)
                default:
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.className).addToCloud(). \(error.localizedDescription)")
                    completion(false, error)
                }
            }
        }
    }
    
    public func updateCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PCKUser.current,
              let uuid = self.uuid,
            let previousVersionUUID = self.previousVersionUUID else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if this entity is already in the Cloud, but not matched locally
        var query = Contact.query(containedIn(key: kPCKObjectableUUIDKey, array: [uuid,previousVersionUUID]))
        query.include([kPCKContactCarePlanKey,kPCKObjectableNotesKey,
                       kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.find(callbackQueue: .global(qos: .background)){ results in
            
            switch results {
            
            case .success(let foundObjects):
                switch foundObjects.count{
                case 0:
                    print("Warning in \(self.className).updateCloud(). A previous version is suppose to exist in the Cloud, but isn't present, saving as new")
                    self.addToCloud(completion: completion)
                case 1:
                    //This is the typical case
                    guard let previousVersion = foundObjects.filter({$0.uuid == previousVersionUUID}).first else {
                        print("Error in \(self.className).updateCloud(). Didn't find previousVersion and this UUID already exists in Cloud")
                        completion(false,ParseCareKitError.uuidAlreadyExists)
                        return
                    }
                    self.copyRelationalEntities(previousVersion)
                    self.addToCloud(completion: completion)

                default:
                    print("Error in \(self.className).updateCloud(). UUID already exists in Cloud")
                    completion(false,ParseCareKitError.uuidAlreadyExists)
                }
            case .failure(let error):
                print("Error in \(self.className).updateCloud(). \(error.localizedDescription))")
                completion(false,error)
            }
        }
    }
    
    public func deleteFromCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        //Handled with update, marked for deletion
        completion(true,nil)
    }
    
    public func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        var query = Contact.query(kPCKObjectableClockKey >= localClock)
        query.order([.ascending(kPCKObjectableClockKey), .ascending(kPCKParseCreatedAtKey)])
        query.include([kPCKContactCarePlanKey,kPCKObjectableNotesKey,
        kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.find(callbackQueue: .global(qos: .background)){ results in
            
            switch results {
            
            case .success(let carePlans):
                let pulled = carePlans.compactMap{try? $0.convertToCareKit()}
                let entities = pulled.compactMap{OCKEntity.contact($0)}
                let revision = OCKRevisionRecord(entities: entities, knowledgeVector: cloudVector)
                mergeRevision(revision)

            case .failure(let error):
                let revision = OCKRevisionRecord(entities: [], knowledgeVector: cloudVector)
                
                switch error.code{
                case .internalServer, .objectNotFound: //1 - this column hasn't been added. 101 - Query returned no results
                    //If the query was looking in a column that wasn't a default column, it will return nil if the table doesn't contain the custom column
                    //Saving the new item with the custom column should resolve the issue
                    print("Warning, table CarePlan either doesn't exist or is missing the column \(kPCKObjectableClockKey). It should be fixed during the first sync of an Outcome... \(error.localizedDescription)")
                default:
                    print("An unexpected error occured \(error.localizedDescription)")
                }
                mergeRevision(revision)
            }
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
    
    open override func copyCommonValues(from other: PCKObject){
        super.copyCommonValues(from: other)
        guard let other = other as? Contact else{return}
        self.address = other.address
        self.category = other.category
        self.title = other.title
        self.name = other.name
        self.organization = other.organization
        self.role = other.role
        self.carePlan = other.carePlan
    }

    open func copyCareKit(_ contactAny: OCKAnyContact) throws -> Contact {
        
        guard let _ = PCKUser.current,
            let contact = contactAny as? OCKContact else{
            throw ParseCareKitError.cantCastToNeededClassType
        }
        let encoded = try JSONEncoder().encode(contact)
        let decoded = try JSONDecoder().decode(Self.self, from: encoded)
        self.copyCommonValues(from: decoded)
        self.entityId = contact.id
        return self
        /*
        if let uuid = contact.uuid?.uuidString{
            self.uuid = uuid
        }else{
            print("Warning in \(className).copyCareKit(). Entity missing uuid: \(contact)")
        }
        
        if let schemaVersion = Contact.getSchemaVersionFromCareKitEntity(contact){
            self.schemaVersion = schemaVersion
        }else{
            print("Warning in \(className).copyCareKit(). Entity missing schemaVersion: \(contact)")
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
        self.timezone = contact.timezone.abbreviation()!
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
        return self*/
    }
    
    
    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit(fromCloud:Bool=true) throws -> OCKContact {
        self.encodingForParse = false
        let encoded = try JSONEncoder().encode(self)
        self.encodingForParse = true
        return try JSONDecoder().decode(OCKContact.self, from: encoded)
        /*
        //Create bare Entity and replace contents with Parse contents
        let nameComponents = CareKitPersonNameComponents.familyName.convertToPersonNameComponents(name)
        
        var contact = OCKContact(id: self.entityId!, name: nameComponents, carePlanUUID: self.carePlanUUID)
        
        if fromCloud{
            guard let decodedContact = decodedCareKitObject(contact) else{
                print("Error in \(className). Couldn't decode entity \(self)")
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
        if let timeZone = TimeZone(abbreviation: self.timezone!){
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
        return contact*/
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
            
            self.first(carePlanUUID, classType: CarePlan(), relatedObject: self.carePlan, include: true){
                (isNew,carePlan) in
                
                guard let carePlan = carePlan else{
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

