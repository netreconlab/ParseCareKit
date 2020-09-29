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


public class Outcome: PCKObject, PCKRemoteSynchronized {

    public var taskOccurrenceIndex: Int?
    public var values: [OutcomeValue]?
    var task: Task? {
        didSet {
            taskUUID = task?.uuid
        }
    }
    var taskUUID: UUID? {
        didSet {
            if taskUUID != task?.uuid {
                task = nil
            }
        }
    }
    var date: Date?
    /*
    public internal(set) var taskUUID:UUID? {
        get {
            if task?.uuid != nil{
                return UUID(uuidString: task!.uuid!)
            }else if taskUUIDString != nil {
                return UUID(uuidString: taskUUIDString!)
            }else{
                return nil
            }
        }
        set{
            taskUUIDString = newValue?.uuidString
            if newValue?.uuidString != task?.uuid{
                task = nil
            }
        }
    }*/

    override init() {
        super.init()
    }

    public convenience init?(careKitEntity: OCKAnyOutcome) {
        self.init()
        do {
            _ = try self.copyCareKit(careKitEntity)
        } catch {
            return nil
        }
    }
    
    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
    
    enum CodingKeys: String, CodingKey {
        case task, taskUUID, taskOccurrenceIndex, values, date
    }
    
    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        if encodingForParse {
            try container.encode(task, forKey: .task)
        }
        try container.encode(taskUUID, forKey: .taskUUID)
        try container.encode(taskOccurrenceIndex, forKey: .taskOccurrenceIndex)
        try container.encode(values, forKey: .values)
        try container.encode(date, forKey: .date)
    }
    
    public func new() -> PCKSynchronized {
        return Outcome()
    }
    
    public func new(with careKitEntity: OCKEntity)->PCKSynchronized?{
        
        switch careKitEntity {
        case .outcome(let entity):
            return Outcome(careKitEntity: entity)
        default:
            print("Error in \(className).new(with:). The wrong type of entity was passed \(careKitEntity)")
            return nil
        }
    }
    
    open func addToCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
            
        guard let _ = PCKUser.current,
              let uuid = self.uuid else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Make wall.logicalClock level entities compatible with KnowledgeVector by setting it's initial .logicalClock to 0
        if !usingKnowledgeVector{
            self.logicalClock = 0
        }
        
        //Check to see if already in the cloud
        let query = Outcome.query(kPCKObjectableUUIDKey == uuid)
        query.first(callbackQueue: .global(qos: .background)){ result in
            
            switch result {
            
            case .success(_):
                completion(false,ParseCareKitError.uuidAlreadyExists)
            case .failure(let error):
                switch error.code{
                case .internalServer: //1 - this column hasn't been added.
                    self.save(self, completion: completion)
                case .objectNotFound: //101 - Query returned no results
                    var query = Outcome.query(kPCKObjectableEntityIdKey == self.entityId, doesNotExist(key: kPCKObjectableDeletedDateKey))
                    query.include([kPCKOutcomeTaskKey,kPCKOutcomeValuesKey,kPCKObjectableNotesKey])
                    
                    query.first(callbackQueue: .global(qos: .background)){ result in
                        
                        switch result {
                        
                        case .success(let objectThatWillBeTombstoned):
                            self.copyRelationalEntities(objectThatWillBeTombstoned)
                            self.save(self, completion: completion)

                        case .failure(_):
                            self.save(self, completion: completion)
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
    
    open func updateCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        //Handled with tombstone, marked for deletion
        completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
    }
    
    open func deleteFromCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        //Handled with update, marked for deletion
        completion(true,nil)
    }
    
    public func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        var query = Self.query(kPCKObjectableClockKey >= localClock)
        query.order([.ascending(kPCKObjectableClockKey), .ascending(kPCKParseCreatedAtKey)])
        query.include([kPCKOutcomeTaskKey,kPCKOutcomeValuesKey,kPCKObjectableNotesKey])
        query.find(callbackQueue: .global(qos: .background)){ results in
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
        var query = Outcome.query(kPCKObjectableUUIDKey == uuid)
        query.include([kPCKOutcomeValuesKey,kPCKObjectableNotesKey])
        query.first(callbackQueue: .global(qos: .background)){ result in
            
            switch result {
            
            case .success(let foundObject):
                //CareKit causes ParseCareKit to create new ones of these, this is removing duplicates
                foundObject.values?.forEach{
                    $0.delete(callbackQueue: .global(qos: .background)){ _ in }
                    $0.notes?.forEach{ $0.delete(callbackQueue: .global(qos: .background)){ _ in } }
                }
                foundObject.notes?.forEach{ $0.delete(callbackQueue: .global(qos: .background)){ _ in } } //CareKit causes ParseCareKit to create new ones of these, this is removing duplicates
                foundObject.copyCommonValues(from: self)
                foundObject.save(foundObject, completion: completion)
    
            case .failure(let error):
                switch error.code {
                case .internalServer, .objectNotFound: //1 - this column hasn't been added. 101 - Query returned no results
                        self.save(self, completion: completion)
                default:
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.className).addToCloud(). \(error.localizedDescription)")
                    completion(false,error)
                }
            }
        }
    }
    
    open override func copyCommonValues(from other: PCKObject){
        super.copyCommonValues(from: other)
        guard let other = other as? Outcome else{return}
        self.taskOccurrenceIndex = other.taskOccurrenceIndex
        self.values = other.values
        self.task = other.task
    }
        
    open func copyCareKit(_ outcomeAny: OCKAnyOutcome) throws -> Outcome {
        
        guard let _ = PCKUser.current,
            let outcome = outcomeAny as? OCKOutcome else{
            throw ParseCareKitError.cantCastToNeededClassType
        }
        
        let encoded = try JSONEncoder().encode(outcome)
        let decoded = try JSONDecoder().decode(Self.self, from: encoded)
        self.copyCommonValues(from: decoded)
        self.entityId = outcome.id
        return self
        /*
        if let uuid = outcome.uuid?.uuidString{
            self.uuid = uuid
        }else{
            print("Warning in \(className).copyCareKit(). Entity missing uuid: \(outcome)")
        }
        
        if let schemaVersion = Outcome.getSchemaVersionFromCareKitEntity(outcome){
            self.schemaVersion = schemaVersion
        }else{
            print("Warning in \(className).copyCareKit(). Entity missing schemaVersion: \(outcome)")
        }
        
        self.entityId = outcome.id
        self.taskOccurrenceIndex = outcome.taskOccurrenceIndex
        self.groupIdentifier = outcome.groupIdentifier
        self.tags = outcome.tags
        self.source = outcome.source
        self.asset = outcome.asset
        self.timezone = outcome.timezone.abbreviation()!
        self.updatedDate = outcome.updatedDate
        self.userInfo = outcome.userInfo
        self.taskUUID = outcome.taskUUID
        self.deletedDate = outcome.deletedDate
        self.remoteID = outcome.remoteID
        self.createdDate = outcome.createdDate
        self.notes = outcome.notes?.compactMap{Note(careKitEntity: $0)}
        self.values = outcome.values.compactMap{OutcomeValue(careKitEntity: $0)}
        
        return self*/
    }
    
    open override func copyRelationalEntities(_ parse: PCKObject) {
        guard let parse = parse as? Outcome else{return}
        super.copyRelationalEntities(parse)
        if self.values == nil {
            self.values = .init()
        }
        if parse.values != nil {
            OutcomeValue.replaceWithCloudVersion(&self.values!, cloud: parse.values!)
        }
    }
        
    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit(fromCloud:Bool=true) throws -> OCKOutcome {
        /*
        guard self.canConvertToCareKit() == true,
            let _ = self.taskUUID,
            let taskOccurrenceIndex = self.taskOccurrenceIndex,
            let values = self.values else{
            print("Error in \(className).convertToCareKit(). Must contain task with a uuid in \(self)")
            return nil
        }*/
        self.encodingForParse = false
        let encoded = try JSONEncoder().encode(self)
        self.encodingForParse = true
        return try JSONDecoder().decode(OCKOutcome.self, from: encoded)
        
        /*
        //Create bare Entity and replace contents with Parse contents
        let outcomeValues = values.compactMap{$0.convertToCareKit()}
        var outcome = OCKOutcome(taskUUID: taskUUID, taskOccurrenceIndex: taskOccurrenceIndex, values: outcomeValues)
        
        if fromCloud{
            guard let decodedOutcome = decodedCareKitObject(outcome) else{
                print("Error in \(className). Couldn't decode entity \(self)")
                return nil
            }
            outcome = decodedOutcome
        }
        
        outcome.groupIdentifier = self.groupIdentifier
        outcome.tags = self.tags
        outcome.remoteID = self.remoteID
        outcome.source = self.source
        outcome.userInfo = self.userInfo
        outcome.taskOccurrenceIndex = taskOccurrenceIndex
        outcome.groupIdentifier = self.groupIdentifier
        outcome.asset = self.asset
        if let timeZone = TimeZone(abbreviation: self.timezone!){
            outcome.timezone = timeZone
        }
        outcome.notes = self.notes?.compactMap{$0.convertToCareKit()}
        return outcome*/
    }
    
    ///Link versions and related classes
    public func linkRelated(completion: @escaping(Bool,Outcome)->Void){
        guard let taskUUID = self.taskUUID,
              let taskOccurrenceIndex = self.taskOccurrenceIndex else{
            //Finished if there's no Task, otherwise see if it's in the cloud
            completion(false,self)
            return
        }
        
        self.first(taskUUID, classType: Task(), relatedObject: self.task, include: true){
            (isNew,task) in
            
            guard let task = task else{
                completion(isNew,self)
                return
            }
            
            self.task = task
            
            guard let currentTask = self.task else{
                self.date = nil
                completion(false,self)
                return
            }
            
            let schedule = currentTask.makeSchedule()
            self.date = schedule?.event(forOccurrenceIndex: taskOccurrenceIndex)?.start
            completion(true,self)
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
    
    open override func stampRelationalEntities() -> Bool {
        let successful = super.stampRelationalEntities()
        if successful{
            self.values?.forEach{$0.stamp(self.logicalClock!)}
        }
        return successful
    }
    
    public static func queryNotDeleted()-> Query<Outcome>{
        let taskQuery = Task.query(doesNotExist(key: kPCKObjectableDeletedDateKey))
        // **** BAKER need to fix matchesKeyInQuery and find equivalent "queryKey" in matchesQuery
        var query = Outcome.query(doesNotExist(key: kPCKObjectableDeletedDateKey), matchesKeyInQuery(key: kPCKOutcomeTaskKey, queryKey: kPCKOutcomeTaskKey, query: taskQuery))
        query.include([kPCKOutcomeTaskKey,kPCKOutcomeValuesKey,kPCKObjectableNotesKey])
        return query
    }
   
    func findOutcomes() throws -> [Outcome] {
        let query = Self.queryNotDeleted()
        return try query.find()
    }
    
    public func findOutcomesInBackground(completion: @escaping([Outcome]?,Error?)->Void) {
        let query = Self.queryNotDeleted()
        query.find(callbackQueue: .global(qos: .background)){ results in
            
            switch results {
            
            case .success(let entities):
                completion(entities, nil)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
}

