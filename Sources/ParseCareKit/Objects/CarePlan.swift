//
//  CarePlan.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore


public final class CarePlan: PCKVersionable, PCKSynchronizable {
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
    

    public internal(set) var nextVersion: CarePlan? {
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

    public internal(set) var previousVersion: CarePlan? {
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

    public var patient:Patient? {
        didSet {
            patientUUID = patient?.uuid
        }
    }
    
    public var patientUUID:UUID? {
        didSet{
            if patientUUID != patient?.uuid {
                patient = nil
            }
        }
    }
    
    public var title:String?
    
    enum CodingKeys: String, CodingKey {
        case objectId, createdAt, updatedAt
        case uuid, entityId, schemaVersion, createdDate, updatedDate, deletedDate, timezone, userInfo, groupIdentifier, tags, source, asset, remoteID, notes, logicalClock
        case previousVersionUUID, nextVersionUUID, effectiveDate
        case title, patient, patientUUID
    }

    public func new(with careKitEntity: OCKEntity) throws -> PCKSynchronizable {
        switch careKitEntity {
        case .carePlan(let entity):
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
        
        let query = Self.query(kPCKObjectableUUIDKey == uuid)
            .includeAll()
        query.first(callbackQueue: .main){
            result in
            
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
                    completion(false,error)
                }
            }
        }
    }
    
    public func updateCloud(_ usingClock:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PCKUser.current,
              let uuid = self.uuid,
            let previousCarePlanUUID = self.previousVersionUUID else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if this entity is already in the Cloud, but not matched locally
        let query = Self.query(containedIn(key: kPCKObjectableUUIDKey, array: [uuid, previousCarePlanUUID]))
            .includeAll()
        query.find(callbackQueue: .main) {
            results in
            
            switch results {
            
            case .success(let foundObjects):
                switch foundObjects.count{
                case 0:
                    print("Warning in \(self.className).updateCloud(). A previous version is suppose to exist in the Cloud, but isn't present, saving as new")
                    self.addToCloud(completion: completion)
                case 1:
                    //This is the typical case
                    guard let previousVersion = foundObjects.first(where: {$0.uuid == self.previousVersionUUID}) else {
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
                print("Error in \(self.className).updateCloud(). \(error.localizedDescription)")
                completion(false,error)
            }
            
        }
    }
    
    public func deleteFromCloud(_ usingClock:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        //Handled with update, marked for deletion
        completion(true,nil)
    }
    
    public func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        let query = Self.query(kPCKObjectableClockKey >= localClock)
            .order([.ascending(kPCKObjectableClockKey), .ascending(kPCKParseCreatedAtKey)])
            .includeAll()
        query.find(callbackQueue: .main){ results in
            
            switch results {
            
            case .success(let carePlans):
                let pulled = carePlans.compactMap{try? $0.convertToCareKit()}
                let entities = pulled.compactMap{OCKEntity.carePlan($0)}
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
    
    public static func copyValues(from other: CarePlan, to here: CarePlan) throws -> Self {
        var here = here
        here.copyVersionedValues(from: other)
        //guard let other = other as? CarePlan else{return}
        here.patient = other.patient
        here.title = other.title
        guard let copied = here as? Self else {
            throw ParseCareKitError.cantCastToNeededClassType
        }
        return copied
    }
    
    public class func copyCareKit(_ carePlanAny: OCKAnyCarePlan) throws -> CarePlan {
        
        guard let _ = PCKUser.current,
            let carePlan = carePlanAny as? OCKCarePlan else{
            throw ParseCareKitError.cantCastToNeededClassType
        }
        let encoded = try ParseCareKitUtility.encoder().encode(carePlan)
        let decoded = try ParseCareKitUtility.decoder().decode(Self.self, from: encoded)
        decoded.entityId = carePlan.id
        return decoded
    }

    func prepareEncodingRelational(_ encodingForParse: Bool) {
        /*previousVersion?.encodingForParse = encodingForParse
        nextVersion?.encodingForParse = encodingForParse
        patient?.encodingForParse = encodingForParse*/
        notes?.forEach {
            $0.encodingForParse = encodingForParse
        }
    }
    
    //Note that CarePlans have to be saved to CareKit first in order to properly convert to CareKit
    public func convertToCareKit(fromCloud:Bool=true) throws -> OCKCarePlan {
        self.encodingForParse = false
        let encoded = try ParseCareKitUtility.encoder().encode(self)
        return try ParseCareKitUtility.decoder().decode(OCKCarePlan.self, from: encoded)
    }
    
    ///Link versions and related classes
    public func linkRelated(completion: @escaping(Bool,CarePlan)->Void){
        self.linkVersions {
            (isNew, linked) in
            
            var linkedNew = isNew
            
            guard let patientUUID = self.patientUUID else{
                //Finished if there's no CarePlan, otherwise see if it's in the cloud
                completion(linkedNew,self)
                return
            }
            
            Patient.first(patientUUID, relatedObject: linked.patient, include: true){ (isNew,patient) in
                
                guard let patient = patient else{
                    completion(linkedNew,self)
                    return
                }
                
                linked.patient = patient
                if self.patient != nil{
                    linkedNew = true
                }
                completion(linkedNew,linked)
            }
        }
    }
}

extension CarePlan {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if encodingForParse {
            try container.encodeIfPresent(patient, forKey: .patient)
        }
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(patientUUID, forKey: .patientUUID)
        try encodeVersionable(to: encoder)
        encodingForParse = true
    }
}
