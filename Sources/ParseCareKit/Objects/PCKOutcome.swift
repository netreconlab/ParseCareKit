//
//  PCKOutcomes.swift
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

/// An `PCKOutcome` is the ParseCareKit equivalent of `OCKOutcome`.  An `OCKOutcome` represents the
/// outcome of an event corresponding to a task. An outcome may have 0 or more values associated with it.
/// For example, a task that asks a patient to measure their temperature will have events whose outcome
/// will contain a single value representing the patient's temperature.
public struct PCKOutcome: PCKVersionable, PCKSynchronizable {
    public var previousVersionUUIDs: [UUID]?

    public var nextVersionUUIDs: [UUID]?

    public var effectiveDate: Date?

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

    public var notes: [OCKNote]?

    public var remoteID: String?

    public var encodingForParse: Bool = true {
        willSet {
            prepareEncodingRelational(newValue)
        }
    }

    public static var className: String {
        "Outcome"
    }

    public var objectId: String?

    public var createdAt: Date?

    public var updatedAt: Date?

    public var ACL: ParseACL?

    var startDate: Date? // Custom added, check if needed

    var endDate: Date? // Custom added, check if needed

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
    public var values: [OCKOutcomeValue]?

    /// The version of the task to which this outcomes belongs.
    public var task: PCKTask? {
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

    public init() {
        previousVersionUUIDs = []
        nextVersionUUIDs = []
        ACL = PCKUtility.getDefaultACL()
    }

    enum CodingKeys: String, CodingKey {
        case objectId, createdAt, updatedAt
        case entityId, schemaVersion, createdDate, updatedDate, timezone,
             userInfo, groupIdentifier, tags, source, asset, remoteID, notes
        case previousVersionUUIDs, nextVersionUUIDs, effectiveDate
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

    public func addToCloud(completion: @escaping(Result<PCKSynchronizable, Error>) -> Void) {
        self.save(completion: completion)
    }

    public func updateCloud(completion: @escaping(Result<PCKSynchronizable, Error>) -> Void) {
        guard var previousVersionUUIDs = self.previousVersionUUIDs,
                let uuid = self.uuid else {
                    completion(.failure(ParseCareKitError.couldntUnwrapRequiredField))
            return
        }
        previousVersionUUIDs.append(uuid)

        // Check to see if this entity is already in the Cloud, but not matched locally
        let query = Self.query(containedIn(key: ParseKey.objectId, array: previousVersionUUIDs))
            .includeAll()
        query.find(callbackQueue: ParseRemote.queue) { results in

            switch results {

            case .success(let foundObjects):
                switch foundObjects.count {
                case 0:
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.outcome.debug("updateCloud(), A previous version is suppose to exist in the Cloud, but isn't present, saving as new")
                    } else {
                        os_log("updateCloud(), A previous version is suppose to exist in the Cloud, but isn't present, saving as new", log: .outcome, type: .debug)
                    }
                    self.addToCloud(completion: completion)
                case 1:
                    // This is the typical case
                    guard let previousVersion = foundObjects.first(where: {
                        guard let foundUUID = $0.uuid else {
                            return false
                        }
                        return previousVersionUUIDs.contains(foundUUID)
                    }) else {
                        if #available(iOS 14.0, watchOS 7.0, *) {
                            Logger.outcome.error("updateCloud(), Didn't find previousVersion of this UUID (\(previousVersionUUIDs, privacy: .private)) already exists in Cloud")
                        } else {
                            os_log("updateCloud(), Didn't find previousVersion of this UUID (%{private}) already exists in Cloud",
                                   log: .outcome, type: .error, previousVersionUUIDs)
                        }
                        completion(.failure(ParseCareKitError.uuidAlreadyExists))
                        return
                    }
                    var updated = self
                    updated = updated.copyRelationalEntities(previousVersion)
                    updated.addToCloud(completion: completion)

                default:
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.outcome.error("updateCloud(), UUID (\(uuid, privacy: .private)) already exists in Cloud")
                    } else {
                        os_log("updateCloud(), UUID (%{private}) already exists in Cloud",
                               log: .outcome, type: .error, uuid.uuidString)
                    }
                    completion(.failure(ParseCareKitError.uuidAlreadyExists))
                }
            case .failure(let error):
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.outcome.error("updateCloud(), \(error.localizedDescription, privacy: .private)")
                } else {
                    os_log("updateCloud(), %{private}", log: .outcome, type: .error, error.localizedDescription)
                }
                completion(.failure(error))
            }

        }
    }

    public func pullRevisions(since localClock: Int, cloudClock: OCKRevisionRecord.KnowledgeVector,
                              mergeRevision: @escaping (Result<OCKRevisionRecord, ParseError>) -> Void) {

        let query = Self.query(ObjectableKey.logicalClock >= localClock)
            .order([.ascending(ObjectableKey.logicalClock), .ascending(ParseKey.createdAt)])
            .includeAll()
        query.find(callbackQueue: ParseRemote.queue) { results in
            switch results {

            case .success(let outcomes):
                let pulled = outcomes.compactMap {try? $0.convertToCareKit()}
                let entities = pulled.compactMap {OCKEntity.outcome($0)}
                let revision = OCKRevisionRecord(entities: entities, knowledgeVector: cloudClock)
                mergeRevision(.success(revision))
            case .failure(let error):

                switch error.code {
                case .internalServer, .objectNotFound:
                    // 1 - this column hasn't been added. 101 - Query returned no results
                    // If the query was looking in a column that wasn't a default column,
                    // it will return nil if the table doesn't contain the custom column
                    // Saving the new item with the custom column should resolve the issue
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
                mergeRevision(.failure(error))
            }
        }
    }

    public func pushRevision(cloudClock: Int, completion: @escaping (Error?) -> Void) {
        var mutableOutcome = self
        mutableOutcome.logicalClock = cloudClock // Stamp Entity

        guard mutableOutcome.deletedDate != nil else {

            mutableOutcome.addToCloud { result in

                switch result {

                case .success:
                    completion(nil)
                case .failure(let error):
                    completion(error)
                }
            }
            return
        }

        mutableOutcome.updateCloud { result in

            switch result {

            case .success:
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        }
    }

    public static func copyValues(from other: PCKOutcome, to here: PCKOutcome) throws -> Self {
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
        let encoded = try PCKUtility.jsonEncoder().encode(outcome)
        var decoded = try PCKUtility.decoder().decode(Self.self, from: encoded)
        decoded.objectId = outcome.uuid.uuidString
        decoded.entityId = outcome.id
        if let acl = outcome.acl {
            decoded.ACL = acl
        } else {
            decoded.ACL = PCKUtility.getDefaultACL()
        }
        return decoded
    }

    public func copyRelational(_ parse: PCKOutcome) -> PCKOutcome {
        var copy = self
        copy = copy.copyRelationalEntities(parse)
        if copy.values == nil {
            copy.values = .init()
        }
        if let valuesToCopy = parse.values {
            copy.values = valuesToCopy
        }
        return copy
    }

    mutating public func prepareEncodingRelational(_ encodingForParse: Bool) {
        if task != nil {
            task!.encodingForParse = encodingForParse
        }
    }

    // Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    public func convertToCareKit() throws -> OCKOutcome {
        var mutableOutcome = self
        mutableOutcome.encodingForParse = false
        let encoded = try PCKUtility.jsonEncoder().encode(mutableOutcome)
        return try PCKUtility.decoder().decode(OCKOutcome.self, from: encoded)
    }

    public func save(completion: @escaping(Result<PCKSynchronizable, Error>) -> Void) {
        self.save(callbackQueue: ParseRemote.queue) { results in
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
                        linkedObject.save(callbackQueue: ParseRemote.queue) { _ in }
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

    /// Link versions and related classes
    public func linkRelated(completion: @escaping(Result<PCKOutcome, Error>) -> Void) {
        guard let taskUUID = self.taskUUID,
              let taskOccurrenceIndex = self.taskOccurrenceIndex else {
            // Finished if there's no Task, otherwise see if it's in the cloud
            completion(.failure(ParseCareKitError.requiredValueCantBeUnwrapped))
            return
        }

        var mutableOutcome = self

        PCKTask.first(taskUUID) { result in

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
                // We still keep going if the link was unsuccessfull
                completion(.success(mutableOutcome))
            }
        }
    }

    public static func tagWithId(_ outcome: OCKOutcome) -> OCKOutcome? {

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

    public static func queryNotDeleted()-> Query<PCKOutcome> {
        let taskQuery = PCKTask.query(doesNotExist(key: OutcomeKey.deletedDate))
        // **** BAKER need to fix matchesKeyInQuery and find equivalent "queryKey" in matchesQuery
        let query = Self.query(doesNotExist(key: OutcomeKey.deletedDate),
                                  matchesKeyInQuery(key: OutcomeKey.task,
                                                    queryKey: OutcomeKey.task, query: taskQuery))
            .includeAll()
        return query
    }

    func findOutcomes() throws -> [PCKOutcome] {
        let query = Self.queryNotDeleted()
        return try query.find()
    }

    public func findOutcomesInBackground(completion: @escaping([PCKOutcome]?, Error?) -> Void) {
        let query = Self.queryNotDeleted()
        query.find(callbackQueue: ParseRemote.queue) { results in

            switch results {

            case .success(let entities):
                completion(entities, nil)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
}

extension PCKOutcome {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if encodingForParse {
            try container.encodeIfPresent(task?.toPointer(), forKey: .task)
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
        try container.encodeIfPresent(effectiveDate, forKey: .effectiveDate)
        try container.encodeIfPresent(previousVersionUUIDs, forKey: .previousVersionUUIDs)
        try container.encodeIfPresent(nextVersionUUIDs, forKey: .nextVersionUUIDs)
        try encodeObjectable(to: encoder)
    }
}// swiftlint:disable:this file_length
