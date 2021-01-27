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
import os.log

// swiftlint:disable cyclomatic_complexity
// swiftlint:disable line_length
// swiftlint:disable type_body_length

/// An `Outcome` is the ParseCareKit equivalent of `OCKOutcome`.  An `OCKOutcome` represents the
/// outcome of an event corresponding to a task. An outcome may have 0 or more values associated with it.
/// For example, a task that asks a patient to measure their temperature will have events whose outcome
/// will contain a single value representing the patient's temperature.
public struct Outcome: PCKObjectable, PCKSynchronizable {

    public var uuid: UUID?

    public var entityId: String?

    public var logicalClock: Int?

    public var schemaVersion: OCKSemanticVersion?

    public var createdDate: Date?

    public var updatedDate: Date?

    public var timezone: TimeZone?

    public var userInfo: [String: String]?

    public var groupIdentifier: String?

    public var tags: [String]?

    public var source: String?

    public var asset: String?

    public var notes: [Note]?

    public var remoteID: String?

    public var encodingForParse: Bool = true {
        willSet {
            prepareEncodingRelational(newValue)
        }
    }

    public var objectId: String?

    public var createdAt: Date?

    public var updatedAt: Date?

    public var ACL: ParseACL? = try? ParseACL.defaultACL()

    var startDate: Date? //Custom added, check if needed

    var endDate: Date? //Custom added, check if needed

    /// The date on which this object was tombstoned. Note that objects are never actually deleted,
    /// but rather they are tombstoned and will no longer be returned from queries.
    public var deletedDate: Date?

    /// Specifies how many events occured before this outcome was created. For example, if a task is schedule to happen twice per day, then
    /// the 2nd outcome on the 2nd day will have a `taskOccurrenceIndex` of 3.
    ///
    /// - Note: The task occurrence references a specific version of a task, so if a new version the task is created, the task occurrence index
    ///  will start again from 0.
    public var taskOccurrenceIndex: Int?

    /// An array of values associated with this outcome. Most outcomes will have 0 or 1 values, but some may have more.
    /// - Examples:
    ///   - A task to call a physician might have 0 values, or 1 value containing the time stamp of when the call was placed.
    ///   - A task to walk 2,000 steps might have 1 value, with that value being the number of steps that were actually taken.
    ///   - A task to complete a survey might have multiple values corresponding to the answers to the questions in the survey.
    public var values: [OutcomeValue]?

    /// The version of the task to which this outcomes belongs.
    public var task: Task? {
        didSet {
            taskUUID = task?.uuid
        }
    }

    /// The version ID of the task to which this outcomes belongs.
    public var taskUUID: UUID? {
        didSet {
            if taskUUID != task?.uuid {
                task = nil
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case objectId, createdAt, updatedAt
        case uuid, entityId, schemaVersion, createdDate, updatedDate, timezone,
             userInfo, groupIdentifier, tags, source, asset, remoteID, notes
        case task, taskUUID, taskOccurrenceIndex, values, deletedDate, startDate, endDate
    }

    public func new(with careKitEntity: OCKEntity) throws -> Self {

        switch careKitEntity {
        case .outcome(let entity):
            return try Self.copyCareKit(entity)
        default:
            if #available(iOS 14.0, watchOS 7.0, *) {
                Logger.outcome.error("new(with:) The wrong type (\(careKitEntity.entityType, privacy: .private)) of entity was passed as an argument.")
            } else {
                os_log("new(with:) The wrong type (%{private}@) of entity was passed.",
                       log: .outcome, type: .error, careKitEntity.entityType.debugDescription)
            }
            throw ParseCareKitError.classTypeNotAnEligibleType
        }
    }

    public func addToCloud(overwriteRemote: Bool, completion: @escaping(Result<PCKSynchronizable, Error>) -> Void) {

        guard let uuid = self.uuid else {
            completion(.failure(ParseCareKitError.requiredValueCantBeUnwrapped))
            return
        }

        //Check to see if already in the cloud
        let query = Outcome.query(ObjectableKey.uuid == uuid)
        query.first(callbackQueue: ParseRemoteSynchronizationManager.queue) { result in

            switch result {

            case .success(let foundEntity):
                guard foundEntity.entityId == self.entityId else {
                    //This object has a duplicate uuid but isn't the same object
                    completion(.failure(ParseCareKitError.uuidAlreadyExists))
                    return
                }

                if overwriteRemote {
                    //The tombsone method can handle the overwrite
                    self.tombstone(completion: completion)
                } else {
                    //This object already exists on server, ignore gracefully
                    completion(.success(foundEntity))
                }

            case .failure(let error):
                switch error.code {
                case .internalServer: //1 - this column hasn't been added.
                    self.save(completion: completion)
                case .objectNotFound: //101 - Query returned no results
                    guard self.id.count > 0 else {
                        return
                    }
                    let query = Outcome.query(ObjectableKey.entityId == self.id,
                                              doesNotExist(key: OutcomeKey.deletedDate))
                        .include([OutcomeKey.values, ObjectableKey.notes])
                    query.first(callbackQueue: ParseRemoteSynchronizationManager.queue) { result in

                        switch result {

                        case .success(let objectThatWillBeTombstoned):
                            var objectToAdd = self
                            objectToAdd = objectToAdd.copyRelational(objectThatWillBeTombstoned)
                            objectToAdd.save(completion: completion)

                        case .failure:
                            self.save(completion: completion)
                        }
                    }

                default:
                    //There was a different issue that we don't know how to handle
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.outcome.error("addToCloud(), \(error.localizedDescription, privacy: .private)")
                    } else {
                        os_log("addToCloud(), %{private}@", log: .outcome, type: .error, error.localizedDescription)
                    }
                    completion(.failure(error))
                }
            }
        }
    }

    public func updateCloud(completion: @escaping(Result<PCKSynchronizable, Error>) -> Void) {
        //Handled with tombstone, marked for deletion
        completion(.failure(ParseCareKitError.requiredValueCantBeUnwrapped))
    }

    public func pullRevisions(since localClock: Int, cloudClock: OCKRevisionRecord.KnowledgeVector,
                              mergeRevision: @escaping (OCKRevisionRecord) -> Void) {

        let query = Self.query(ObjectableKey.logicalClock >= localClock)
            .order([.ascending(ObjectableKey.logicalClock), .ascending(ParseKey.createdAt)])
            .include([OutcomeKey.values, ObjectableKey.notes])
        query.find(callbackQueue: ParseRemoteSynchronizationManager.queue) { results in
            switch results {

            case .success(let outcomes):
                let pulled = outcomes.compactMap {try? $0.convertToCareKit()}
                let entities = pulled.compactMap {OCKEntity.outcome($0)}
                let revision = OCKRevisionRecord(entities: entities, knowledgeVector: cloudClock)
                mergeRevision(revision)
            case .failure(let error):
                let revision = OCKRevisionRecord(entities: [], knowledgeVector: cloudClock)

                switch error.code {
                case .internalServer, .objectNotFound:
                    //1 - this column hasn't been added. 101 - Query returned no results
                    //If the query was looking in a column that wasn't a default column,
                    //it will return nil if the table doesn't contain the custom column
                    //Saving the new item with the custom column should resolve the issue
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.outcome.debug("Warning, the table either doesn't exist or is missing the column \"\(ObjectableKey.logicalClock, privacy: .private)\". It should be fixed during the first sync... ParseError: \(error.localizedDescription, privacy: .private)")
                    } else {
                        os_log("Warning, the table either doesn't exist or is missing the column \"%{private}\" It should be fixed during the first sync... ParseError: \"%{private}", log: .outcome, type: .debug, ObjectableKey.logicalClock, error.localizedDescription)
                    }
                default:
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.outcome.debug("An unexpected error occured \(error.localizedDescription, privacy: .private)")
                    } else {
                        os_log("An unexpected error occured \"%{private}",
                               log: .outcome, type: .debug, error.localizedDescription)
                    }
                }
                mergeRevision(revision)
            }
        }
    }

    public func pushRevision(cloudClock: Int, overwriteRemote: Bool, completion: @escaping (Error?) -> Void) {
        var mutableOutcome = self
        mutableOutcome.logicalClock = cloudClock //Stamp Entity

        guard mutableOutcome.deletedDate != nil else {

            mutableOutcome.addToCloud(overwriteRemote: overwriteRemote) { result in

                switch result {

                case .success:
                    completion(nil)
                case .failure(let error):
                    completion(error)
                }
            }
            return
        }

        mutableOutcome.tombstone { result in

            switch result {

            case .success:
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        }
    }

    public func tombstone(completion: @escaping(Result<PCKSynchronizable, Error>) -> Void) {

        guard let uuid = self.uuid else {
            completion(.failure(ParseCareKitError.requiredValueCantBeUnwrapped))
            return
        }

        //Get latest item from the Cloud to compare against
        let query = Outcome.query(ObjectableKey.uuid == uuid)
            .include([OutcomeKey.values, ObjectableKey.notes])
        query.first(callbackQueue: ParseRemoteSynchronizationManager.queue) { result in

            switch result {

            case .success(let foundObject):
                //CareKit causes ParseCareKit to create new ones of these, this is removing duplicates
                try? foundObject.values?.forEach {
                    _ = try $0.notes?.deleteAll()
                }
                _ = try? foundObject.values?.deleteAll()
                _ = try? foundObject.notes?.deleteAll()

                guard let copied = try? Self.copyValues(from: self, to: foundObject) else {
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.outcome.debug("tombstone(), Couldn't cast to self")
                    } else {
                        os_log("tombstone(), Couldn't cast to self", log: .outcome, type: .debug)
                    }
                    completion(.failure(ParseCareKitError.cantCastToNeededClassType))
                    return
                }
                copied.save(completion: completion)

            case .failure(let error):
                switch error.code {

                case .internalServer, .objectNotFound:
                    //1 - this column hasn't been added. 101 - Query returned no results
                    self.save(completion: completion)

                default:
                    //There was a different issue that we don't know how to handle
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.outcome.error("updateCloud(), \(error.localizedDescription, privacy: .private)")
                    } else {
                        os_log("updateCloud(), %{private}", log: .outcome, type: .error, error.localizedDescription)
                    }
                    completion(.failure(error))
                }
            }
        }
    }

    public static func copyValues(from other: Outcome, to here: Outcome) throws -> Self {
        var here = here
        here.copyCommonValues(from: other)
        here.taskOccurrenceIndex = other.taskOccurrenceIndex
        here.values = other.values
        here.task = other.task
        return here
    }

    public static func copyCareKit(_ outcomeAny: OCKAnyOutcome) throws -> Self {

        guard let outcome = outcomeAny as? OCKOutcome else {
            throw ParseCareKitError.cantCastToNeededClassType
        }
        let encoded = try ParseCareKitUtility.jsonEncoder().encode(outcome)
        var decoded = try ParseCareKitUtility.decoder().decode(Self.self, from: encoded)
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

    mutating public func prepareEncodingRelational(_ encodingForParse: Bool) {
        if task != nil {
            task!.encodingForParse = encodingForParse
        }
        var updatedValues = [OutcomeValue]()
        values?.forEach {
            var update = $0
            update.encodingForParse = encodingForParse
            updatedValues.append(update)
        }
        values = updatedValues
        var updatedNotes = [Note]()
        notes?.forEach {
            var update = $0
            update.encodingForParse = encodingForParse
            updatedNotes.append(update)
        }
        self.notes = updatedNotes
    }

    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    public func convertToCareKit() throws -> OCKOutcome {
        var mutableOutcome = self
        mutableOutcome.encodingForParse = false
        let encoded = try ParseCareKitUtility.jsonEncoder().encode(mutableOutcome)
        return try ParseCareKitUtility.decoder().decode(OCKOutcome.self, from: encoded)
    }

    public func save(completion: @escaping(Result<PCKSynchronizable, Error>) -> Void) {
        guard let stamped = try? self.stampRelational() else {
            completion(.failure(ParseCareKitError.cantUnwrapSelf))
            return
        }
        stamped.save(callbackQueue: ParseRemoteSynchronizationManager.queue) { results in
            switch results {

            case .success(let saved):
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.outcome.debug("save(), Object: \(saved, privacy: .private)")
                } else {
                    os_log("save(), Object: %{private}", log: .outcome, type: .debug, saved.description)
                }

                saved.linkRelated { result in

                    switch result {

                    case .success(let linkedObject):
                        linkedObject.save(callbackQueue: ParseRemoteSynchronizationManager.queue) { _ in }
                        completion(.success(linkedObject))

                    case .failure:
                        completion(.success(saved))
                    }
                }
            case .failure(let error):
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.outcome.error("save(), \(error.localizedDescription, privacy: .private)")
                } else {
                    os_log("save(), %{private}", log: .outcome, type: .error, error.localizedDescription)
                }
                completion(.failure(error))
            }
        }
    }

    ///Link versions and related classes
    public func linkRelated(completion: @escaping(Result<Outcome, Error>) -> Void) {
        guard let taskUUID = self.taskUUID,
              let taskOccurrenceIndex = self.taskOccurrenceIndex else {
            //Finished if there's no Task, otherwise see if it's in the cloud
            completion(.failure(ParseCareKitError.requiredValueCantBeUnwrapped))
            return
        }

        var mutableOutcome = self

        Task.first(taskUUID/*, relatedObject: self.task*/) { result in

            switch result {

            case .success(let foundTask):

                mutableOutcome.task = foundTask

                guard let currentTask = mutableOutcome.task else {
                    mutableOutcome.startDate = nil
                    mutableOutcome.endDate = nil
                    completion(.success(mutableOutcome))
                    return
                }

                mutableOutcome.startDate = currentTask.schedule?.event(forOccurrenceIndex: taskOccurrenceIndex)?.start
                mutableOutcome.endDate = currentTask.schedule?.event(forOccurrenceIndex: taskOccurrenceIndex)?.end
                completion(.success(mutableOutcome))

            case .failure:
                //We still keep going if the link was unsuccessfull
                completion(.success(mutableOutcome))
            }
        }
    }

    public static func tagWithId(_ outcome: OCKOutcome) -> OCKOutcome? {

        //If this object has a createdDate, it's been stored locally before
        guard outcome.uuid != nil else {
            return nil
        }

        var mutableOutcome = outcome

        if mutableOutcome.tags != nil {
            if !mutableOutcome.tags!.contains(mutableOutcome.id) {
                mutableOutcome.tags!.append(mutableOutcome.id)
                return mutableOutcome
            }
        } else {
            mutableOutcome.tags = [mutableOutcome.id]
            return mutableOutcome
        }

        return nil
    }

    public func stampRelational() throws -> Outcome {
        var stamped = self
        stamped = try stamped.stampRelationalEntities()
        var updatedOutcomeValues = [OutcomeValue]()
        stamped.values?.forEach {
            var update = $0
            update.stamp(stamped.logicalClock!)
            updatedOutcomeValues.append(update)
        }
        stamped.values = updatedOutcomeValues

        return stamped
    }

    public static func queryNotDeleted()-> Query<Outcome> {
        let taskQuery = Task.query(doesNotExist(key: OutcomeKey.deletedDate))
        // **** BAKER need to fix matchesKeyInQuery and find equivalent "queryKey" in matchesQuery
        let query = Outcome.query(doesNotExist(key: OutcomeKey.deletedDate),
                                  matchesKeyInQuery(key: OutcomeKey.task,
                                                    queryKey: OutcomeKey.task, query: taskQuery))
            .include([OutcomeKey.values, ObjectableKey.notes])
        return query
    }

    func findOutcomes() throws -> [Outcome] {
        let query = Self.queryNotDeleted()
        return try query.find()
    }

    public func findOutcomesInBackground(completion: @escaping([Outcome]?, Error?) -> Void) {
        let query = Self.queryNotDeleted()
        query.find(callbackQueue: ParseRemoteSynchronizationManager.queue) { results in

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
            try container.encodeIfPresent(startDate, forKey: .startDate)
            try container.encodeIfPresent(endDate, forKey: .endDate)
            if id.count > 0 {
                try container.encodeIfPresent(id, forKey: .entityId)
            }
        }
        try container.encodeIfPresent(taskUUID, forKey: .taskUUID)
        try container.encodeIfPresent(taskOccurrenceIndex, forKey: .taskOccurrenceIndex)
        try container.encodeIfPresent(values, forKey: .values)
        try container.encodeIfPresent(deletedDate, forKey: .deletedDate)
        try encodeObjectable(to: encoder)
    }
}// swiftlint:disable:this file_length
