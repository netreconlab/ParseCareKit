//
//  PCKCarePlan.swift
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

/// An `PCKCarePlan` is the ParseCareKit equivalent of `OCKCarePlan`.  An `OCKCarePlan` represents
/// a set of tasks, including both interventions and assesments, that a patient is supposed to
/// complete as part of his or her treatment for a specific condition. For example, a care plan for obesity
/// may include tasks requiring the patient to exercise, record their weight, and log meals. As the care
/// plan evolves with the patient's progress, the care provider may modify the exercises and include notes each
/// time about why the changes were made.
public struct PCKCarePlan: PCKVersionable {

    public var effectiveDate: Date?

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

    public var notes: [OCKNote]?

    public var remoteID: String?

    public var encodingForParse: Bool = true {
        willSet {
            prepareEncodingRelational(newValue)
        }
    }

    public static var className: String {
        "CarePlan"
    }

    public var objectId: String?

    public var createdAt: Date?

    public var updatedAt: Date?

    public var ACL: ParseACL?

    public var score: Double?

    public var nextVersionUUIDs: [UUID]?

    public var previousVersionUUIDs: [UUID]?

    /// The patient to whom this care plan belongs.
    public var patient: PCKPatient? {
        didSet {
            patientUUID = patient?.uuid
        }
    }

    /// The UUID of the patient to whom this care plan belongs.
    public var patientUUID: UUID? {
        didSet {
            if patientUUID != patient?.uuid {
                patient = nil
            }
        }
    }

    /// A title describing this care plan.
    public var title: String?

    enum CodingKeys: String, CodingKey {
        case objectId, createdAt, updatedAt
        case entityId, schemaVersion, createdDate, updatedDate, deletedDate,
             timezone, userInfo, groupIdentifier, tags, source, asset, remoteID,
             notes, logicalClock
        case previousVersionUUIDs, nextVersionUUIDs, effectiveDate
        case title, patient, patientUUID
    }

    public init() {
        ACL = PCKUtility.getDefaultACL()
    }

    public func new(with careKitEntity: OCKEntity) throws -> PCKCarePlan {
        switch careKitEntity {
        case .carePlan(let entity):
            return try Self.copyCareKit(entity)
        default:
            if #available(iOS 14.0, watchOS 7.0, *) {
                Logger.carePlan.error("new(with:) The wrong type (\(careKitEntity.entityType, privacy: .private)) of entity was passed as an argument.")
            } else {
                os_log("new(with:) The wrong type (%{private}@) of entity was passed.",
                       log: .carePlan, type: .error, careKitEntity.entityType.debugDescription)
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
                        Logger.carePlan.debug("updateCloud(), A previous version is suppose to exist in the Cloud, but isn't present, saving as new")
                    } else {
                        os_log("updateCloud(), A previous version is suppose to exist in the Cloud, but isn't present, saving as new", log: .carePlan, type: .debug)
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
                            Logger.carePlan.error("updateCloud(), Didn't find previousVersion of this UUID (\(previousVersionUUIDs, privacy: .private)) already exists in Cloud")
                        } else {
                            os_log("updateCloud(), Didn't find previousVersion of this UUID (%{private}) already exists in Cloud",
                                   log: .carePlan, type: .error, previousVersionUUIDs)
                        }
                        completion(.failure(ParseCareKitError.uuidAlreadyExists))
                        return
                    }
                    var updated = self
                    updated = updated.copyRelationalEntities(previousVersion)
                    updated.addToCloud(completion: completion)

                default:
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.carePlan.error("updateCloud(), UUID (\(uuid, privacy: .private)) already exists in Cloud")
                    } else {
                        os_log("updateCloud(), UUID (%{private}) already exists in Cloud",
                               log: .carePlan, type: .error, uuid.uuidString)
                    }
                    completion(.failure(ParseCareKitError.uuidAlreadyExists))
                }
            case .failure(let error):
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.carePlan.error("updateCloud(), \(error.localizedDescription, privacy: .private)")
                } else {
                    os_log("updateCloud(), %{private}", log: .carePlan, type: .error, error.localizedDescription)
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

            case .success(let carePlans):
                let pulled = carePlans.compactMap {try? $0.convertToCareKit()}
                let entities = pulled.compactMap {OCKEntity.carePlan($0)}
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
                        Logger.carePlan.debug("Warning, the table either doesn't exist or is missing the column \"\(ObjectableKey.logicalClock, privacy: .private)\". It should be fixed during the first sync... ParseError: \(error.localizedDescription, privacy: .private)")
                    } else {
                        os_log("Warning, the table either doesn't exist or is missing the column \"%{private}\" It should be fixed during the first sync... ParseError: \"%{private}", log: .carePlan, type: .debug, ObjectableKey.logicalClock, error.localizedDescription)
                    }
                default:
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.carePlan.debug("An unexpected error occured \(error.localizedDescription, privacy: .private)")
                    } else {
                        os_log("An unexpected error occured \"%{private}",
                               log: .carePlan, type: .debug, error.localizedDescription)
                    }
                }
                mergeRevision(.failure(error))
            }
        }
    }

    public func pushRevision(cloudClock: Int, completion: @escaping (Error?) -> Void) {
        var mutableCarePlan = self
        mutableCarePlan.logicalClock = cloudClock // Stamp Entity

        guard mutableCarePlan.deletedDate != nil else {
            mutableCarePlan.addToCloud { result in

                switch result {

                case .success:
                    completion(nil)
                case .failure(let error):
                    completion(error)
                }
            }
            return
        }

        mutableCarePlan.updateCloud { result in

            switch result {

            case .success:
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        }
    }

    public static func copyValues(from other: PCKCarePlan, to here: PCKCarePlan) throws -> Self {
        var here = here
        here.copyVersionedValues(from: other)
        here.patient = other.patient
        here.title = other.title
        return here
    }

    public static func copyCareKit(_ carePlanAny: OCKAnyCarePlan) throws -> PCKCarePlan {

        guard let carePlan = carePlanAny as? OCKCarePlan else {
            throw ParseCareKitError.cantCastToNeededClassType
        }
        let encoded = try PCKUtility.jsonEncoder().encode(carePlan)
        var decoded = try PCKUtility.decoder().decode(Self.self, from: encoded)
        decoded.objectId = carePlan.uuid.uuidString
        decoded.entityId = carePlan.id
        if let acl = carePlan.acl {
            decoded.ACL = acl
        } else {
            decoded.ACL = PCKUtility.getDefaultACL()
        }
        return decoded
    }

    mutating func prepareEncodingRelational(_ encodingForParse: Bool) {
        if patient != nil {
            patient?.encodingForParse = encodingForParse
        }
    }

    // Note that CarePlans have to be saved to CareKit first in order to properly convert to CareKit
    public func convertToCareKit() throws -> OCKCarePlan {
        var mutableCarePlan = self
        mutableCarePlan.encodingForParse = false
        let encoded = try PCKUtility.jsonEncoder().encode(mutableCarePlan)
        return try PCKUtility.decoder().decode(OCKCarePlan.self, from: encoded)
    }

    /// Link versions and related classes
    public func linkRelated(completion: @escaping(Result<PCKCarePlan, Error>) -> Void) {
        var updatedCarePlan = self

        guard let patientUUID = self.patientUUID else {
            // Finished if there's no Patient, otherwise see if it's in the cloud
            completion(.success(updatedCarePlan))
            return
        }

        PCKPatient.first(patientUUID) { result in

            if case let .success(patient) = result {
                updatedCarePlan.patient = patient
            }

            completion(.success(updatedCarePlan))
        }
    }
}

extension PCKCarePlan {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if encodingForParse {
            try container.encodeIfPresent(patient?.toPointer(), forKey: .patient)
        }
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(patientUUID, forKey: .patientUUID)
        try encodeVersionable(to: encoder)
    }
}
