//
//  Task.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore


public final class Task: PCKVersionable, PCKSynchronizable {

    public internal(set) var nextVersion: Task? {
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

    public internal(set) var previousVersion: Task? {
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
    

    public var impactsAdherence:Bool?
    public var instructions:String?
    public var title:String?
    public var schedule: OCKSchedule?
    public var carePlan:CarePlan? {
        didSet {
            carePlanUUID = carePlan?.uuid
        }
    }
    public var carePlanUUID:UUID? {
        didSet {
            if carePlanUUID != carePlan?.uuid {
                carePlan = nil
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case uuid, schemaVersion, createdDate, updatedDate, deletedDate, timezone, userInfo, groupIdentifier, tags, source, asset, remoteID, notes, logicalClock
        case previousVersionUUID, nextVersionUUID, effectiveDate
        case title, carePlan, carePlanUUID, impactsAdherence, instructions, schedule
    }
    
    public func new(with careKitEntity: OCKEntity) throws ->PCKSynchronizable {
        
        switch careKitEntity {
        case .task(let entity):
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
        let query = Task.query(kPCKObjectableUUIDKey == uuid)
        query.first(callbackQueue: .global(qos: .background)){ result in
            
            switch result {
            
            case .success(_):
                completion(false,ParseCareKitError.uuidAlreadyExists)
            case .failure(let error):
                switch error.code {
                case .internalServer, .objectNotFound: //1 - this column hasn't been added. 101 - Query returned no results
                        self.save(completion: completion)
                default:
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.className).addToCloud(). \(error.localizedDescription)")
                    completion(false,error)
                }
                return
            }
        }
    }
    
    public func updateCloud(_ usingClock:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PCKUser.current,
              let uuid = self.uuid,
            let previousPatientUUID = self.previousVersionUUID else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if this entity is already in the Cloud, but not matched locally
        let query = Task.query(containedIn(key: kPCKObjectableUUIDKey, array: [uuid,previousPatientUUID]))
        _ = query.include([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectableNotesKey,
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
                    guard let previousVersion = foundObjects.first(where: {$0.uuid == previousPatientUUID}) else {
                        print("Error in \(self.className).updateCloud(). Didn't find previousVersion and this UUID already exists in Cloud")
                        completion(false,ParseCareKitError.uuidAlreadyExists)
                        return
                    }
                    var updated = self
                    updated = updated.copyRelational(previousVersion)
                    updated.addToCloud(completion: completion)

                default:
                    print("Error in \(self.className).updateCloud(). UUID already exists in Cloud")
                    completion(false,ParseCareKitError.uuidAlreadyExists)
                }
            case .failure(let error):
                print("Error in \(self.className).updateCloud(). \(String(describing: error.localizedDescription))")
                completion(false,error)
            }
        }
    }
    
    public func deleteFromCloud(_ usingClock:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        //Handled with update, marked for deletion
        completion(true,nil)
    }
    
    public func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        let query = Task.query(kPCKObjectableClockKey >= localClock)
        _ = query.order([.ascending(kPCKObjectableClockKey), .ascending(kPCKParseCreatedAtKey)])
        _ = query.include([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectableNotesKey,
                           kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.find(callbackQueue: .global(qos: .background)){ results in
            switch results {
            
            case .success(let tasks):
                let pulled = tasks.compactMap{try? $0.convertToCareKit()}
                let entities = pulled.compactMap{OCKEntity.task($0)}
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
    
    public class func copyValues(from other: Task, to here: Task) throws -> Self {
        var here = here
        here.copyVersionedValues(from: other)
        
        here.impactsAdherence = other.impactsAdherence
        here.instructions = other.instructions
        here.title = other.title
        here.schedule = other.schedule
        here.carePlan = other.carePlan
        here.carePlanUUID = other.carePlanUUID
        
        guard let copied = here as? Self else {
            throw ParseCareKitError.cantCastToNeededClassType
        }
        return copied
    }
    
    
    public class func copyCareKit(_ taskAny: OCKAnyTask) throws -> Task {
        
        guard let _ = PCKUser.current,
            let task = taskAny as? OCKTask else{
            throw ParseCareKitError.cantCastToNeededClassType
        }
        
        let encoded = try ParseCareKitUtility.encoder().encode(task)
        let decoded = try ParseCareKitUtility.decoder().decode(Self.self, from: encoded)
        decoded.entityId = task.id
        return decoded
    }
    
    public func copyRelational(_ parse: Task) -> Task {
        var copy = self
        copy = copy.copyRelationalEntities(parse)
        return copy
    }

    func prepareEncodingRelational(_ encodingForParse: Bool) {
        previousVersion?.encodingForParse = encodingForParse
        nextVersion?.encodingForParse = encodingForParse
        carePlan?.encodingForParse = encodingForParse
        notes?.forEach {
            $0.encodingForParse = encodingForParse
        }
    }

    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    public func convertToCareKit(fromCloud:Bool=true) throws -> OCKTask {
        self.encodingForParse = false
        let encoded = try ParseCareKitUtility.encoder().encode(self)
        return try ParseCareKitUtility.decoder().decode(OCKTask.self, from: encoded)
    }
    
    ///Link versions and related classes
    public func linkRelated(completion: @escaping(Bool,Task)->Void){
        
        self.linkVersions(){
            (isNew, linkedObject) in
            var linkedNew = isNew
        
            guard let carePlanUUID = self.carePlanUUID else {
                //Finished if there's no CarePlan, otherwise see if it's in the cloud
                completion(linkedNew,self)
                return
            }
            
            CarePlan.first(carePlanUUID, relatedObject: linkedObject.carePlan, include: true){
                (isNew,carePlan) in
                
                guard let carePlan = carePlan else{
                    completion(linkedNew,self)
                    return
                }
                
                linkedObject.carePlan = carePlan
                if isNew{
                    linkedNew = true
                }
                completion(linkedNew,linkedObject)
            }
        }
    }
    
    public func stampRelational() throws -> Task {
        var stamped = self
        stamped = try stamped.stampRelationalEntities()
        //stamped.elements?.forEach{$0.stamp(self.logicalClock!)}
        
        return stamped
    }
}

extension Task {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if encodingForParse {
            try container.encode(carePlan, forKey: .carePlan)
        }
        try container.encode(title, forKey: .title)
        try container.encode(carePlanUUID, forKey: .carePlanUUID)
        try container.encode(impactsAdherence, forKey: .impactsAdherence)
        try container.encode(instructions, forKey: .instructions)
        try container.encode(schedule, forKey: .schedule)
        try encodeVersionable(to: encoder)
        encodingForParse = true
    }
}

