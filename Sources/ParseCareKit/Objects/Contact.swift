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


public final class Contact: PCKVersionable, PCKSynchronizable {
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
    
    public var effectiveDate: Date
    
    public internal(set) var uuid: UUID?
    
    var entityId: String?
    
    public internal(set) var logicalClock: Int?
    
    public internal(set) var schemaVersion: OCKSemanticVersion?
    
    public internal(set) var createdDate: Date?
    
    public internal(set) var updatedDate: Date?
    
    public internal(set) var deletedDate: Date?
    
    public var timezone: TimeZone
    
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
    

    //1 to 1 between Parse and CareStore
    public var address:OCKPostalAddress?
    public var category:OCKContactCategory?
    public var name:PersonNameComponents
    public var organization:String?
    public var role:String?
    public var title:String?
    public var carePlan:CarePlan? {
        didSet {
            carePlanUUID = carePlan?.uuid
        }
    }
    public var carePlanUUID:UUID? {
        didSet{
            if carePlanUUID != carePlan?.uuid {
                carePlan = nil
            }
        }
    }
    
    public var messagingNumbers: [OCKLabeledValue]?

    public var emailAddresses: [OCKLabeledValue]?

    public var phoneNumbers: [OCKLabeledValue]?

    public var otherContactInfo: [OCKLabeledValue]?

    enum CodingKeys: String, CodingKey {
        case objectId, createdAt, updatedAt
        case uuid, entityId, schemaVersion, createdDate, updatedDate, deletedDate, timezone, userInfo, groupIdentifier, tags, source, asset, remoteID, notes, logicalClock
        case previousVersionUUID, nextVersionUUID, previousVersion, nextVersion, effectiveDate
        case carePlan, title, carePlanUUID, address, category, name, organization, role
        case emailAddresses, messagingNumbers, phoneNumbers, otherContactInfo
    }

    public func new(with careKitEntity: OCKEntity) throws -> PCKSynchronizable {
        
        switch careKitEntity {
        case .contact(let entity):
            return try Self.copyCareKit(entity)
        default:
            print("Error in \(className).new(with:). The wrong type of entity was passed \(careKitEntity)")
            throw ParseCareKitError.classTypeNotAnEligibleType
        }
    }
    
    public func addToCloud(_ usingClock:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        
        guard let _ = PCKUser.current,
              let uuid = self.uuid else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if already in the cloud
        let query = Contact.query(kPCKObjectableUUIDKey == uuid)
            .includeAll()
        query.first(callbackQueue: .main){ result in
            
            switch result {
            
            case .success(let foundEntity):
                guard foundEntity.entityId == self.entityId else {
                    //This object has a duplicate uuid but isn't the same object
                    completion(false,ParseCareKitError.uuidAlreadyExists)
                    return
                }
                //This object already exists on server, ignore gracefully
                completion(true,ParseCareKitError.uuidAlreadyExists)

            case .failure(let error):
                switch error.code {
                case .internalServer, .objectNotFound: //1 - this column hasn't been added. 101 - Query returned no results
                        self.save(completion: completion)
                default:
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.className).addToCloud(). \(error.localizedDescription)")
                    completion(false, error)
                }
            }
        }
    }
    
    public func updateCloud(_ usingClock:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PCKUser.current,
              let uuid = self.uuid,
            let previousVersionUUID = self.previousVersionUUID else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if this entity is already in the Cloud, but not matched locally
        let query = Contact.query(containedIn(key: kPCKObjectableUUIDKey, array: [uuid,previousVersionUUID]))
            .includeAll()
        query.find(callbackQueue: .main){ results in
            
            switch results {
            
            case .success(let foundObjects):
                switch foundObjects.count{
                case 0:
                    print("Warning in \(self.className).updateCloud(). A previous version is suppose to exist in the Cloud, but isn't present, saving as new")
                    self.addToCloud(completion: completion)
                case 1:
                    //This is the typical case
                    guard let previousVersion = foundObjects.first(where: {$0.uuid == previousVersionUUID}) else {
                        print("Error in \(self.className).updateCloud(). Didn't find previousVersion and this UUID already exists in Cloud")
                        completion(false,ParseCareKitError.uuidAlreadyExists)
                        return
                    }
                    var updated = self
                    updated = updated.copyRelationalEntities(previousVersion)
                    updated.addToCloud(completion: completion)

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
    
    public func deleteFromCloud(_ usingClock:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        //Handled with update, marked for deletion
        completion(true,nil)
    }
    
    public func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        let query = Contact.query(kPCKObjectableClockKey >= localClock)
            .order([.ascending(kPCKObjectableClockKey), .ascending(kPCKParseCreatedAtKey)])
            .includeAll()
        query.find(callbackQueue: .main){ results in
            
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
        /*previousVersion?.encodingForParse = encodingForParse
        nextVersion?.encodingForParse = encodingForParse
        carePlan?.encodingForParse = encodingForParse*/
        notes?.forEach {
            $0.encodingForParse = encodingForParse
        }
    }

    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    public func convertToCareKit(fromCloud:Bool=true) throws -> OCKContact {
        self.encodingForParse = false
        let encoded = try ParseCareKitUtility.encoder().encode(self)
        return try ParseCareKitUtility.decoder().decode(OCKContact.self, from: encoded)
    }
    
    ///Link versions and related classes
    public func linkRelated(completion: @escaping(Bool,Contact)->Void){
        self.linkVersions {
            (isNew, linked) in
            var linkedNew = isNew
            
            guard let carePlanUUID = self.carePlanUUID else{
                //Finished if there's no CarePlan, otherwise see if it's in the cloud
                completion(linkedNew,self)
                return
            }
            
            CarePlan.first(carePlanUUID, relatedObject: linked.carePlan, include: true){
                (isNew,carePlan) in
                
                guard let carePlan = carePlan else{
                    completion(linkedNew,self)
                    return
                }
                
                linked.carePlan = carePlan
                if isNew{
                    linkedNew = true
                }
                completion(linkedNew,linked)
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
        try container.encode(name, forKey: .name)
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
