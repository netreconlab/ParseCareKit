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
import os.log

/// An `Contact` is the ParseCareKit equivalent of `OCKContact`.  An `OCKContact`represents a contact that a user
/// may want to get in touch with. A contact may be a care provider, a friend, or a family
/// member. Contacts must have at least a name, and may optionally have numerous other addresses at which to be contacted.
public final class Contact: PCKVersionable {
    public internal(set) var nextVersion: Contact? {
        didSet {
            nextVersionUUID = nextVersion?.uuid
        }
    }
    
    public internal(set) var nextVersionUUID:UUID? {
        didSet {
            if nextVersionUUID != nextVersion?.uuid {
                nextVersion = nil
            }
        }
    }

    public internal(set) var previousVersion: Contact? {
        didSet {
            previousVersionUUID = previousVersion?.uuid
        }
    }
    
    public internal(set) var previousVersionUUID: UUID? {
        didSet {
            if previousVersionUUID != previousVersion?.uuid {
                previousVersion = nil
            }
        }
    }
    
    public var effectiveDate: Date?
    
    public internal(set) var uuid: UUID?
    
    var entityId: String?
    
    public internal(set) var logicalClock: Int?
    
    public internal(set) var schemaVersion: OCKSemanticVersion?
    
    public internal(set) var createdDate: Date?
    
    public internal(set) var updatedDate: Date?
    
    public internal(set) var deletedDate: Date?
    
    public var timezone: TimeZone?
    
    public var userInfo: [String : String]?
    
    public var groupIdentifier: String?
    
    public var tags: [String]?
    
    public var source: String?
    
    public var asset: String?
    
    public var notes: [Note]?
    
    public var remoteID: String?
    
    var encodingForParse: Bool = true {
        willSet {
            prepareEncodingRelational(newValue)
        }
    }
    
    public var objectId: String?
    
    public var createdAt: Date?
    
    public var updatedAt: Date?
    
    public var ACL: ParseACL? = try? ParseACL.defaultACL()
    
    /// The contact's postal address.
    public var address:OCKPostalAddress?
    
    /// Indicates if this contact is care provider or if they are a friend or family member.
    public var category:OCKContactCategory?
    
    /// The contact's name.
    public var name:PersonNameComponents
    
    /// The organization this contact belongs to.
    public var organization:String?
    
    /// A description of what this contact's role is.
    public var role:String?
    
    /// A title for this contact.
    public var title:String?
    
    /// The version in the local database for the care plan associated with this contact.
    public var carePlan:CarePlan? {
        didSet {
            carePlanUUID = carePlan?.uuid
        }
    }
    
    /// The version id in the local database for the care plan associated with this contact.
    public var carePlanUUID:UUID? {
        didSet{
            if carePlanUUID != carePlan?.uuid {
                carePlan = nil
            }
        }
    }
    
    /// An array of numbers that the contact can be messaged at.
    /// The number strings may contains non-numeric characters.
    public var messagingNumbers: [OCKLabeledValue]?

    /// An array of the contact's email addresses.
    public var emailAddresses: [OCKLabeledValue]?

    /// An array of the contact's phone numbers.
    /// The number strings may contains non-numeric characters.
    public var phoneNumbers: [OCKLabeledValue]?

    /// An array of other information that could be used reach this contact.
    public var otherContactInfo: [OCKLabeledValue]?

    /// A textual representation of this instance, suitable for debugging.
    public var localizedDescription: String {
        "\(debugDescription) title=\(String(describing: title)) role=\(String(describing: role)) organization=\(String(describing: organization)) category=\(String(describing: category)) address=\(String(describing: address)) messagingNumbers=\(String(describing: messagingNumbers)) emailAddresses=\(String(describing: emailAddresses)) phoneNumbers=\(String(describing: phoneNumbers)) otherContactInfo=\(String(describing: otherContactInfo)) carePlanUUID=\(String(describing: carePlanUUID)) carePlan=\(String(describing: carePlan))"
    }

    enum CodingKeys: String, CodingKey {
        case objectId, createdAt, updatedAt
        case uuid, entityId, schemaVersion, createdDate, updatedDate, deletedDate, timezone, userInfo, groupIdentifier, tags, source, asset, remoteID, notes, logicalClock
        case previousVersionUUID, nextVersionUUID, previousVersion, nextVersion, effectiveDate
        case carePlan, title, carePlanUUID, address, category, name, organization, role
        case emailAddresses, messagingNumbers, phoneNumbers, otherContactInfo
    }

    public func new(with careKitEntity: OCKEntity) throws -> Contact {
        
        switch careKitEntity {
        case .contact(let entity):
            return try Self.copyCareKit(entity)
        default:
            if #available(iOS 14.0, watchOS 7.0, *) {
                Logger.contact.error("new(with:) The wrong type (\(careKitEntity.entityType, privacy: .private)) of entity was passed as an argument.")
            } else {
                os_log("new(with:) The wrong type (%{private}@) of entity was passed.", log: .contact, type: .error, careKitEntity.entityType.debugDescription)
            }
            throw ParseCareKitError.classTypeNotAnEligibleType
        }
    }
    
    public func addToCloud(overwriteRemote: Bool, completion: @escaping(Result<PCKSynchronizable,Error>) -> Void){
        
        guard let _ = PCKUser.current,
              let uuid = self.uuid else{
            completion(.failure(ParseCareKitError.requiredValueCantBeUnwrapped))
            return
        }
        
        //Check to see if already in the cloud
        let query = Contact.query(kPCKObjectableUUIDKey == uuid)
        query.first(callbackQueue: .main){ result in
            
            switch result {
            
            case .success(let foundEntity):
                guard foundEntity.entityId == self.entityId else {
                    //This object has a duplicate uuid but isn't the same object
                    completion(.failure(ParseCareKitError.uuidAlreadyExists))
                    return
                }
                
                if overwriteRemote {
                    self.updateCloud(completion: completion)
                } else {
                    //This object already exists on server, ignore gracefully
                    completion(.success(foundEntity))
                }

            case .failure(let error):
                switch error.code {
                case .internalServer, .objectNotFound: //1 - this column hasn't been added. 101 - Query returned no results
                        self.save(completion: completion)
                default:
                    //There was a different issue that we don't know how to handle
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.contact.error("addToCloud(), \(error.localizedDescription, privacy: .private)")
                    } else {
                        os_log("addToCloud(), %{private}@", log: .contact, type: .error, error.localizedDescription)
                    }
                    completion(.failure( error))
                }
            }
        }
    }
    
    public func updateCloud(completion: @escaping(Result<PCKSynchronizable,Error>) -> Void){
        guard let _ = PCKUser.current,
              let uuid = self.uuid,
            let previousVersionUUID = self.previousVersionUUID else{
            completion(.failure(ParseCareKitError.requiredValueCantBeUnwrapped))
            return
        }
        
        //Check to see if this entity is already in the Cloud, but not matched locally
        let query = Contact.query(containedIn(key: kPCKObjectableUUIDKey, array: [uuid,previousVersionUUID]))
            .include([kPCKContactCarePlanKey, kPCKVersionedObjectNextKey, kPCKVersionedObjectPreviousKey, kPCKObjectableNotesKey])
        query.find(callbackQueue: .main){ results in
            
            switch results {
            
            case .success(let foundObjects):
                switch foundObjects.count{
                case 0:
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.contact.debug("updateCloud(), A previous version is suppose to exist in the Cloud, but isn't present, saving as new")
                    } else {
                        os_log("updateCloud(), A previous version is suppose to exist in the Cloud, but isn't present, saving as new", log: .contact, type: .debug)
                    }
                    self.addToCloud(overwriteRemote: false, completion: completion)
                case 1:
                    //This is the typical case
                    guard let previousVersion = foundObjects.first(where: {$0.uuid == previousVersionUUID}) else {
                        if #available(iOS 14.0, watchOS 7.0, *) {
                            Logger.contact.error("updateCloud(), Didn't find previousVersion of this UUID (\(previousVersionUUID, privacy: .private)) already exists in Cloud")
                        } else {
                            os_log("updateCloud(), Didn't find previousVersion of this UUID (%{private}) already exists in Cloud", log: .contact, type: .error, previousVersionUUID.uuidString)
                        }
                        completion(.failure(ParseCareKitError.uuidAlreadyExists))
                        return
                    }
                    var updated = self
                    updated = updated.copyRelationalEntities(previousVersion)
                    updated.addToCloud(overwriteRemote: false, completion: completion)

                default:
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.contact.error("updateCloud(), UUID (\(uuid, privacy: .private)) already exists in Cloud")
                    } else {
                        os_log("updateCloud(), UUID (%{private}) already exists in Cloud", log: .contact, type: .error, uuid.uuidString)
                    }
                    completion(.failure(ParseCareKitError.uuidAlreadyExists))
                }
            case .failure(let error):
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.contact.error("updateCloud(), \(error.localizedDescription, privacy: .private)")
                } else {
                    os_log("updateCloud(), %{private}", log: .contact, type: .error, error.localizedDescription)
                }
                completion(.failure(error))
            }
        }
    }
    
    public func pullRevisions(since localClock: Int, cloudClock: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        let query = Contact.query(kPCKObjectableClockKey >= localClock)
            .order([.ascending(kPCKObjectableClockKey), .ascending(kPCKParseCreatedAtKey)])
            .include([kPCKContactCarePlanKey, kPCKVersionedObjectNextKey, kPCKVersionedObjectPreviousKey, kPCKObjectableNotesKey])
        query.find(callbackQueue: .main){ results in
            
            switch results {
            
            case .success(let carePlans):
                let pulled = carePlans.compactMap{try? $0.convertToCareKit()}
                let entities = pulled.compactMap{OCKEntity.contact($0)}
                let revision = OCKRevisionRecord(entities: entities, knowledgeVector: cloudClock)
                mergeRevision(revision)

            case .failure(let error):
                let revision = OCKRevisionRecord(entities: [], knowledgeVector: cloudClock)
                
                switch error.code{
                case .internalServer, .objectNotFound: //1 - this column hasn't been added. 101 - Query returned no results
                    //If the query was looking in a column that wasn't a default column, it will return nil if the table doesn't contain the custom column
                    //Saving the new item with the custom column should resolve the issue
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.contact.debug("Warning, the table either doesn't exist or is missing the column \"\(kPCKObjectableClockKey, privacy: .private)\". It should be fixed during the first sync... ParseError: \(error.localizedDescription, privacy: .private)")
                    } else {
                        os_log("Warning, the table either doesn't exist or is missing the column \"%{private}\" It should be fixed during the first sync... ParseError: \"%{private}", log: .contact, type: .debug, kPCKObjectableClockKey, error.localizedDescription)
                    }
                default:
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.contact.debug("An unexpected error occured \(error.localizedDescription, privacy: .private)")
                    } else {
                        os_log("An unexpected error occured \"%{private}", log: .contact, type: .debug, error.localizedDescription)
                    }
                }
                mergeRevision(revision)
            }
        }
    }
    
    public func pushRevision(cloudClock: Int, overwriteRemote: Bool, completion: @escaping (Error?) -> Void){
        
        self.logicalClock = cloudClock //Stamp Entity
        
        guard let _ = self.previousVersionUUID else {
            self.addToCloud(overwriteRemote: overwriteRemote) { result in
                
                switch result {
                
                case .success(_):
                    completion(nil)
                case .failure(let error):
                    completion(error)
                }
            }
            return
        }
        
        self.updateCloud { result in
            
            switch result {
            
            case .success(_):
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        }
    }
    
    public class func copyValues(from other: Contact, to here: Contact) throws -> Self {
        var copy = here
        copy.copyVersionedValues(from: other)
        copy.address = other.address
        copy.category = other.category
        copy.title = other.title
        copy.name = other.name
        copy.organization = other.organization
        copy.role = other.role
        copy.carePlan = other.carePlan
        
        guard let copied = copy as? Self else {
            throw ParseCareKitError.cantCastToNeededClassType
        }
        return copied
    }

    public class func copyCareKit(_ contactAny: OCKAnyContact) throws -> Contact {
        
        guard let contact = contactAny as? OCKContact else{
            throw ParseCareKitError.cantCastToNeededClassType
        }
        let encoded = try ParseCareKitUtility.encoder().encode(contact)
        let decoded = try ParseCareKitUtility.decoder().decode(Self.self, from: encoded)
        decoded.entityId = contact.id
        return decoded
    }
    
    func prepareEncodingRelational(_ encodingForParse: Bool) {
        previousVersion?.encodingForParse = encodingForParse
        nextVersion?.encodingForParse = encodingForParse
        carePlan?.encodingForParse = encodingForParse
        notes?.forEach {
            $0.encodingForParse = encodingForParse
        }
    }

    public func convertToCareKit() throws -> OCKContact {
        self.encodingForParse = false
        let encoded = try ParseCareKitUtility.jsonEncoder().encode(self)
        return try ParseCareKitUtility.decoder().decode(OCKContact.self, from: encoded)
    }
    
    ///Link versions and related classes
    public func linkRelated(completion: @escaping(Result<Contact,Error>)->Void){
        self.linkVersions { result in
            
            var updatedContact: Contact
            
            switch result {
            
            case .success(let linked):
                updatedContact = linked
            case .failure(_):
                updatedContact = self
            }
            
            guard let carePlanUUID = self.carePlanUUID else{
                //Finished if there's no CarePlan, otherwise see if it's in the cloud
                completion(.success(updatedContact))
                return
            }
            
            CarePlan.first(carePlanUUID, relatedObject: updatedContact.carePlan) { result in
                
                if case let .success(carePlan) = result {
                    updatedContact.carePlan = carePlan
                }
                
                completion(.success(updatedContact))
            }
        }
    }
}

extension Contact {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        if encodingForParse {
            try container.encodeIfPresent(carePlan, forKey: .carePlan)
        }
        
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(carePlanUUID, forKey: .carePlanUUID)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(organization, forKey: .organization)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(emailAddresses, forKey: .emailAddresses)
        try container.encodeIfPresent(messagingNumbers, forKey: .messagingNumbers)
        try container.encodeIfPresent(phoneNumbers, forKey: .phoneNumbers)
        try container.encodeIfPresent(otherContactInfo, forKey: .otherContactInfo)
        try encodeVersionable(to: encoder)
        encodingForParse = true
    }
}
