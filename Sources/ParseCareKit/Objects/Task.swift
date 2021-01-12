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
import os.log

// swiftlint:disable line_length
// swiftlint:disable cyclomatic_complexity
// swiftlint:disable function_body_length
// swiftlint:disable type_body_length

/// An `Task` is the ParseCareKit equivalent of `OCKTask`.  An `OCKTask` represents some task or action that a
/// patient is supposed to perform. Tasks are optionally associable with an `OCKCarePlan` and must have a unique
/// id and schedule. The schedule determines when and how often the task should be performed, and the
/// `impactsAdherence` flag may be used to specify whether or not the patients adherence to this task will affect
/// their daily completion rings.
public final class Task: PCKVersionable {

    public var nextVersion: Task? {
        didSet {
            nextVersionUUID = nextVersion?.uuid
        }
    }

    public var nextVersionUUID: UUID? {
        didSet {
            if nextVersionUUID != nextVersion?.uuid {
                nextVersion = nil
            }
        }
    }

    public var previousVersion: Task? {
        didSet {
            previousVersionUUID = previousVersion?.uuid
        }
    }

    public var previousVersionUUID: UUID? {
        didSet {
            if previousVersionUUID != previousVersion?.uuid {
                previousVersion = nil
            }
        }
    }

    public var effectiveDate: Date?

    public var uuid: UUID?

    public var entityId: String?

    public var logicalClock: Int?

    public var schemaVersion: OCKSemanticVersion?

    public var createdDate: Date?

    public var updatedDate: Date?

    public var deletedDate: Date?

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

    /// If true, completion of this task will be factored into the patient's overall adherence. True by default.
    public var impactsAdherence: Bool?

    /// Instructions about how this task should be performed.
    public var instructions: String?

    /// A title that will be used to represent this task to the patient.
    public var title: String?

    /// A schedule that specifies how often this task occurs.
    public var schedule: OCKSchedule?

    /// The care plan to which this task belongs.
    public var carePlan: CarePlan? {
        didSet {
            carePlanUUID = carePlan?.uuid
        }
    }

    /// The UUID of the care plan to which this task belongs.
    public var carePlanUUID: UUID? {
        didSet {
            if carePlanUUID != carePlan?.uuid {
                carePlan = nil
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case objectId, createdAt, updatedAt
        case uuid, entityId, schemaVersion, createdDate, updatedDate, deletedDate, timezone, userInfo, groupIdentifier, tags, source, asset, remoteID, notes, logicalClock
        case previousVersionUUID, nextVersionUUID, previousVersion, nextVersion, effectiveDate
        case title, carePlan, carePlanUUID, impactsAdherence, instructions, schedule
    }

    public func new(with careKitEntity: OCKEntity) throws -> Task {

        switch careKitEntity {
        case .task(let entity):
            return try Self.copyCareKit(entity)
        default:
            if #available(iOS 14.0, watchOS 7.0, *) {
                Logger.task.error("new(with:) The wrong type (\(careKitEntity.entityType, privacy: .private)) of entity was passed as an argument.")
            } else {
                os_log("new(with:) The wrong type (%{private}@) of entity was passed.", log: .task, type: .error, careKitEntity.entityType.debugDescription)
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
        let query = Task.query(ObjectableKey.uuid == uuid)
        query.first(callbackQueue: ParseRemoteSynchronizationManager.queue) { result in

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
                case .internalServer, .objectNotFound:
                    //1 - this column hasn't been added. 101 - Query returned no results
                    self.save(completion: completion)
                default:
                    //There was a different issue that we don't know how to handle
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.task.error("addToCloud(), \(error.localizedDescription, privacy: .private)")
                    } else {
                        os_log("addToCloud(), %{private}@", log: .task, type: .error, error.localizedDescription)
                    }
                    completion(.failure(error))
                }
                return
            }
        }
    }

    public func updateCloud(completion: @escaping(Result<PCKSynchronizable, Error>) -> Void) {
        guard let uuid = self.uuid,
            let previousVersionUUID = self.previousVersionUUID else {
            completion(.failure(ParseCareKitError.requiredValueCantBeUnwrapped))
            return
        }

        //Check to see if this entity is already in the Cloud, but not matched locally
        let query = Task.query(containedIn(key: ObjectableKey.uuid, array: [uuid, previousVersionUUID]))
            .include([TaskKey.carePlan, VersionableKey.next, VersionableKey.previous, ObjectableKey.notes])
        query.find(callbackQueue: ParseRemoteSynchronizationManager.queue) { results in

            switch results {

            case .success(let foundObjects):
                switch foundObjects.count {
                case 0:
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.task.debug("updateCloud(), A previous version is suppose to exist in the Cloud, but isn't present, saving as new")
                    } else {
                        os_log("updateCloud(), A previous version is suppose to exist in the Cloud, but isn't present, saving as new", log: .task, type: .debug)
                    }
                    self.addToCloud(overwriteRemote: false, completion: completion)
                case 1:
                    //This is the typical case
                    guard let previousVersion = foundObjects.first(where: {$0.uuid == previousVersionUUID}) else {
                        if #available(iOS 14.0, watchOS 7.0, *) {
                            Logger.task.error("updateCloud(), Didn't find previousVersion of this UUID (\(previousVersionUUID, privacy: .private)) already exists in Cloud")
                        } else {
                            os_log("updateCloud(), Didn't find previousVersion of this UUID (%{private}) already exists in Cloud", log: .task, type: .error, previousVersionUUID.uuidString)
                        }
                        completion(.failure(ParseCareKitError.uuidAlreadyExists))
                        return
                    }
                    var updated = self
                    updated = updated.copyRelationalEntities(previousVersion)
                    updated.addToCloud(overwriteRemote: false, completion: completion)

                default:
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.task.error("updateCloud(), UUID (\(uuid, privacy: .private)) already exists in Cloud")
                    } else {
                        os_log("updateCloud(), UUID (%{private}) already exists in Cloud",
                               log: .task, type: .error, uuid.uuidString)
                    }
                    completion(.failure(ParseCareKitError.uuidAlreadyExists))
                }
            case .failure(let error):
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.task.error("updateCloud(), \(error.localizedDescription, privacy: .private)")
                } else {
                    os_log("updateCloud(), %{private}", log: .task, type: .error, error.localizedDescription)
                }
                completion(.failure(error))
            }
        }
    }

    public func pullRevisions(since localClock: Int, cloudClock: OCKRevisionRecord.KnowledgeVector,
                              mergeRevision: @escaping (OCKRevisionRecord) -> Void) {

        let query = Task.query(ObjectableKey.logicalClock >= localClock)
            .order([.ascending(ObjectableKey.logicalClock), .ascending(ParseKey.createdAt)])
            .include([VersionableKey.next, VersionableKey.previous, ObjectableKey.notes])
        query.find(callbackQueue: ParseRemoteSynchronizationManager.queue) { results in
            switch results {

            case .success(let tasks):
                let pulled = tasks.compactMap {try? $0.convertToCareKit()}
                let entities = pulled.compactMap {OCKEntity.task($0)}
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
                        Logger.task.debug("Warning, the table either doesn't exist or is missing the column \"\(ObjectableKey.logicalClock, privacy: .private)\". It should be fixed during the first sync... ParseError: \(error.localizedDescription, privacy: .private)")
                    } else {
                        os_log("Warning, the table either doesn't exist or is missing the column \"%{private}\" It should be fixed during the first sync... ParseError: \"%{private}", log: .task, type: .debug, ObjectableKey.logicalClock, error.localizedDescription)
                    }
                default:
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.task.debug("An unexpected error occured \(error.localizedDescription, privacy: .private)")
                    } else {
                        os_log("An unexpected error occured \"%{private}",
                               log: .task, type: .debug, error.localizedDescription)
                    }
                }
                mergeRevision(revision)
            }
        }
    }

    public func pushRevision(cloudClock: Int, overwriteRemote: Bool, completion: @escaping (Error?) -> Void) {

        self.logicalClock = cloudClock //Stamp Entity

        guard self.previousVersionUUID != nil else {
            self.addToCloud(overwriteRemote: overwriteRemote) { result in

                switch result {

                case .success:
                    completion(nil)
                case .failure(let error):
                    completion(error)
                }
            }
            return
        }

        self.updateCloud { result in

            switch result {

            case .success:
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        }
    }

    public class func copyValues(from other: Task, to here: Task) throws -> Task {
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

        guard let task = taskAny as? OCKTask else {
            throw ParseCareKitError.cantCastToNeededClassType
        }

        let encoded = try ParseCareKitUtility.jsonEncoder().encode(task)
        let decoded = try ParseCareKitUtility.decoder().decode(Self.self, from: encoded)
        decoded.entityId = task.id
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

    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    public func convertToCareKit() throws -> OCKTask {
        self.encodingForParse = false
        let encoded = try ParseCareKitUtility.jsonEncoder().encode(self)
        return try ParseCareKitUtility.decoder().decode(OCKTask.self, from: encoded)
    }

    ///Link versions and related classes
    public func linkRelated(completion: @escaping(Result<Task, Error>) -> Void) {

        self.linkVersions { result in

            var updatedTask: Task

            switch result {

            case .success(let linked):
                updatedTask = linked

            case .failure:
                updatedTask = self
            }

            guard let carePlanUUID = self.carePlanUUID else {
                //Finished if there's no CarePlan, otherwise see if it's in the cloud
                completion(.success(updatedTask))
                return
            }

            CarePlan.first(carePlanUUID, relatedObject: updatedTask.carePlan) { result in

                if case let .success(carePlan) = result {
                    updatedTask.carePlan = carePlan
                }

                completion(.success(updatedTask))
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
            try container.encodeIfPresent(carePlan, forKey: .carePlan)
        }
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(carePlanUUID, forKey: .carePlanUUID)
        try container.encodeIfPresent(impactsAdherence, forKey: .impactsAdherence)
        try container.encodeIfPresent(instructions, forKey: .instructions)
        try container.encodeIfPresent(schedule, forKey: .schedule)
        try encodeVersionable(to: encoder)
        encodingForParse = true
    }
}
