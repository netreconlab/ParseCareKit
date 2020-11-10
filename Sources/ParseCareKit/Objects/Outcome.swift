//
//  Outcomes.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/14/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore


final public class Outcome: PCKObjectable, PCKSynchronizable {
    
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
    
    var date: Date? //Custom added, check if needed
    public var taskOccurrenceIndex: Int?
    public var values: [OutcomeValue]?
    public var task: Task? {
        didSet {
            taskUUID = task?.uuid
        }
    }
    public var taskUUID: UUID? {
        didSet {
            if taskUUID != task?.uuid {
                task = nil
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case objectId, createdAt, updatedAt
        case uuid, entityId, schemaVersion, createdDate, updatedDate, timezone, userInfo, groupIdentifier, tags, source, asset, remoteID, notes
        case task, taskUUID, taskOccurrenceIndex, values, deletedDate, date
    }

    public func new(with careKitEntity: OCKEntity) throws -> PCKSynchronizable {
        
        switch careKitEntity {
        case .outcome(let entity):
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
        
        //Make wall.logicalClock level entities compatible with Clock by setting it's initial .logicalClock to 0
        if !usingClock{
            self.logicalClock = 0
        }
        
        //Check to see if already in the cloud
        let query = Outcome.query(kPCKObjectableUUIDKey == uuid)
            .include([kPCKOutcomeValuesKey])
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
                switch error.code{
                case .internalServer: //1 - this column hasn't been added.
                    self.save(completion: completion)
                case .objectNotFound: //101 - Query returned no results
                    guard self.id.count > 0 else {
                        return
                    }
                    let query = Outcome.query(kPCKObjectableEntityIdKey == self.id, doesNotExist(key: kPCKObjectableDeletedDateKey))
                        .include([kPCKOutcomeValuesKey])
                    query.first(callbackQueue: .main){ result in
                        
                        switch result {
                        
                        case .success(let objectThatWillBeTombstoned):
                            var objectToAdd = self
                            objectToAdd = objectToAdd.copyRelational(objectThatWillBeTombstoned)
                            objectToAdd.save(completion: completion)

                        case .failure(_):
                            self.save(completion: completion)
                            completion(false,nil)
                        }
                    }
                    
                default:
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.className).addToCloud(). \(error.localizedDescription)")
                    completion(false,error)
                }
            }
        }
    }
    
    public func updateCloud(_ usingClock:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        //Handled with tombstone, marked for deletion
        completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
    }
    
    public func deleteFromCloud(_ usingClock:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        //Handled with update, marked for deletion
        completion(true,nil)
    }
    
    public func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        let query = Self.query(kPCKObjectableClockKey >= localClock)
            .order([.ascending(kPCKObjectableClockKey), .ascending(kPCKParseCreatedAtKey)])
            .include([kPCKOutcomeValuesKey])
            //.includeAll()
            //.include([kPCKOutcomeValuesKey, kPCKOutcomeTaskKey, kPCKObjectableNotesKey])
        query.find(callbackQueue: .main){ results in
            switch results {
            
            case .success(let outcomes):
                let pulled = outcomes.compactMap{try? $0.convertToCareKit()}
                let entities = pulled.compactMap{OCKEntity.outcome($0)}
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
        
        guard self.deletedDate != nil else {
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
        
        self.tombstsone(){
            (success,error) in
            if success{
                completion(nil)
            }else{
                completion(error)
            }
        }
    }
    
    public func tombstsone(completion: @escaping(Bool,Error?) -> Void){
        
        guard let _ = PCKUser.current,
              let uuid = self.uuid else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
                
        //Get latest item from the Cloud to compare against
        let query = Outcome.query(kPCKObjectableUUIDKey == uuid)
            .include([kPCKOutcomeValuesKey])
        query.first(callbackQueue: .main){ result in
            
            switch result {
            
            case .success(let foundObject):
                //CareKit causes ParseCareKit to create new ones of these, this is removing duplicates
                foundObject.values?.forEach{
                    $0.delete(callbackQueue: .main){ _ in }
                    $0.notes?.forEach{ $0.delete(callbackQueue: .main){ _ in } }
                }
                foundObject.notes?.forEach{ $0.delete(callbackQueue: .main){ _ in } } //CareKit causes ParseCareKit to create new ones of these, this is removing duplicates
                
                guard let copied = try? Self.copyValues(from: self, to: foundObject) else {
                    print("Error in \(self.className).tombstsone(). Couldn't cast to self")
                    completion(false,ParseCareKitError.cantCastToNeededClassType)
                    return
                }
                copied.save(completion: completion)
    
            case .failure(let error):
                switch error.code {
                case .internalServer, .objectNotFound: //1 - this column hasn't been added. 101 - Query returned no results
                        self.save(completion: completion)
                default:
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.className).tombstsone(). \(error.localizedDescription)")
                    completion(false,error)
                }
            }
        }
    }
    
    public class func copyValues(from other: Outcome, to here: Outcome) throws -> Self{
        var here = here
        here.copyCommonValues(from: other)
        here.taskOccurrenceIndex = other.taskOccurrenceIndex
        here.values = other.values
        here.task = other.task
        
        guard let copied = here as? Self else {
            throw ParseCareKitError.cantCastToNeededClassType
        }
        return copied
    }
        
    public class func copyCareKit(_ outcomeAny: OCKAnyOutcome) throws -> Outcome {
        
        guard let outcome = outcomeAny as? OCKOutcome else{
            throw ParseCareKitError.cantCastToNeededClassType
        }
        
        let encoded = try ParseCareKitUtility.encoder().encode(outcome)
        let decoded = try ParseCareKitUtility.decoder().decode(Self.self, from: encoded)
        decoded.entityId = outcome.id
        return decoded
    }
    
    public func copyRelational(_ parse: Outcome) -> Outcome {
        var copy = self
        copy = copy.copyRelationalEntities(parse)
        if copy.values == nil {
            copy.values = .init()
        }
        if let valuesToCopy = parse.values {
            OutcomeValue.replaceWithCloudVersion(&copy.values!, cloud: valuesToCopy)
        }
        return copy
    }
        
    public func prepareEncodingRelational(_ encodingForParse: Bool) {
        //task?.encodingForParse = encodingForParse
        values?.forEach {
            $0.encodingForParse = encodingForParse
        }
        notes?.forEach {
            $0.encodingForParse = encodingForParse
        }
    }

    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    public func convertToCareKit(fromCloud:Bool=true) throws -> OCKOutcome {
        self.encodingForParse = false
        let encoded = try ParseCareKitUtility.jsonEncoder().encode(self)
        return try ParseCareKitUtility.decoder().decode(OCKOutcome.self, from: encoded)
    }
    
    public func save(completion: @escaping(Bool,Error?) -> Void){
        guard let stamped = try? self.stampRelational() else {
            completion(false, ParseCareKitError.cantUnwrapSelf)
            return
        }
        stamped.save(callbackQueue: .main){ results in
            switch results {
            
            case .success(let saved):
                print("Successfully saved \(saved) in Cloud.")
                
                saved.linkRelated{
                    (success, linkedObject) in
                    
                    if success{
                        linkedObject.save(callbackQueue: .main){ _ in }
                    }
                    completion(true,nil)
                }
            case .failure(let error):
                print("Error in CarePlan.addToCloud(). \(error)")
                completion(false,error)
            }
        }
    }
    
    ///Link versions and related classes
    public func linkRelated(completion: @escaping(Bool,Outcome)->Void){
        guard let taskUUID = self.taskUUID,
              let taskOccurrenceIndex = self.taskOccurrenceIndex else{
            //Finished if there's no Task, otherwise see if it's in the cloud
            completion(false,self)
            return
        }
        if self.task == nil {
            Task.first(taskUUID, relatedObject: self.task, include: true){
                (isNew,foundTask) in
                
                guard let foundTask = foundTask else{
                    completion(isNew,self)
                    return
                }
                
                self.task = foundTask
                
                guard let currentTask = self.task else{
                    self.date = nil
                    completion(false,self)
                    return
                }
                
                self.date = currentTask.schedule?.event(forOccurrenceIndex: taskOccurrenceIndex)?.start
                completion(true,self)
            }
        }
    }
    
    public static func tagWithId(_ outcome: OCKOutcome)-> OCKOutcome?{
        
        //If this object has a createdDate, it's been stored locally before
        guard outcome.uuid != nil else{
            return nil
        }
        
        var mutableOutcome = outcome
       
        if mutableOutcome.tags != nil{
            if !mutableOutcome.tags!.contains(mutableOutcome.id){
                mutableOutcome.tags!.append(mutableOutcome.id)
                return mutableOutcome
            }
        }else{
            mutableOutcome.tags = [mutableOutcome.id]
            return mutableOutcome
        }
        
        return nil
    }
    
    public func stampRelational() throws -> Outcome {
        var stamped = self
        stamped = try stamped.stampRelationalEntities()
        stamped.values?.forEach{$0.stamp(stamped.logicalClock!)}
        
        return stamped
    }
    
    public static func queryNotDeleted()-> Query<Outcome>{
        let taskQuery = Task.query(doesNotExist(key: kPCKObjectableDeletedDateKey))
        // **** BAKER need to fix matchesKeyInQuery and find equivalent "queryKey" in matchesQuery
        let query = Outcome.query(doesNotExist(key: kPCKObjectableDeletedDateKey), matchesKeyInQuery(key: kPCKOutcomeTaskKey, queryKey: kPCKOutcomeTaskKey, query: taskQuery))
            .include([kPCKOutcomeValuesKey])
        return query
    }
   
    func findOutcomes() throws -> [Outcome] {
        let query = Self.queryNotDeleted()
        return try query.find()
    }
    
    public func findOutcomesInBackground(completion: @escaping([Outcome]?,Error?)->Void) {
        let query = Self.queryNotDeleted()
        query.find(callbackQueue: .main){ results in
            
            switch results {
            
            case .success(let entities):
                completion(entities, nil)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
}

extension Outcome {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if encodingForParse {
            try container.encodeIfPresent(task, forKey: .task)
            try container.encodeIfPresent(date, forKey: .date)
        }
        try container.encodeIfPresent(taskUUID, forKey: .taskUUID)
        try container.encodeIfPresent(taskOccurrenceIndex, forKey: .taskOccurrenceIndex)
        guard let valuesToEncode = values else {
            throw ParseCareKitError.requiredValueCantBeUnwrapped
        }
        try valuesToEncode.forEach { value in
            var nestedUnkeyedContainer = container.nestedUnkeyedContainer(forKey: .values)
            try nestedUnkeyedContainer.encode(value)
        }
        try container.encodeIfPresent(deletedDate, forKey: .deletedDate)
        if id.count > 0 {
            entityId = id
        }
        try encodeObjectable(to: encoder)
        encodingForParse = true
    }
}
