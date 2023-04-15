//
//  PCKPatients.swift
//  ParseCareKit
//
//  Created by Corey Baker on 10/5/19.
//  Copyright © 2019 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore
import os.log

// swiftlint:disable cyclomatic_complexity
// swiftlint:disable type_body_length
// swiftlint:disable line_length

/// An `PCKPatient` is the ParseCareKit equivalent of `OCKPatient`.  An `OCKPatient` represents a patient.
public struct PCKPatient: PCKVersionable {

    public var previousVersionUUIDs: [UUID]? {
        willSet {
            guard let newValue = newValue else {
                previousVersions = nil
                return
            }
            var newPreviousVersions = [Pointer<Self>]()
            newValue.forEach { newPreviousVersions.append(Pointer<Self>(objectId: $0.uuidString)) }
            previousVersions = newPreviousVersions
        }
    }

    public var nextVersionUUIDs: [UUID]? {
        willSet {
            guard let newValue = newValue else {
                nextVersions = nil
                return
            }
            var newNextVersions = [Pointer<Self>]()
            newValue.forEach { newNextVersions.append(Pointer<Self>(objectId: $0.uuidString)) }
            nextVersions = newNextVersions
        }
    }

    public var previousVersions: [Pointer<Self>]?

    public var nextVersions: [Pointer<Self>]?

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

    public var encodingForParse: Bool = true

    public static var className: String {
        "Patient"
    }

    public var objectId: String?

    public var createdAt: Date?

    public var updatedAt: Date?

    public var ACL: ParseACL?

    public var originalData: Data?

    /// A list of substances this patient is allergic to.
    public var allergies: [String]?

    /// The patient's birthday, used to compute their age.
    public var birthday: Date?

    /// The patient's name.
    public var name: PersonNameComponents?

    /// The patient's biological sex.
    public var sex: OCKBiologicalSex?

    enum CodingKeys: String, CodingKey {
        case objectId, createdAt, updatedAt
        case entityId, schemaVersion, createdDate, updatedDate,
             deletedDate, timezone, userInfo, groupIdentifier, tags,
             source, asset, remoteID, notes, logicalClock
        case previousVersionUUIDs, nextVersionUUIDs, effectiveDate
        case allergies, birthday, name, sex
    }

    public init() {
        ACL = PCKUtility.getDefaultACL()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(allergies, forKey: .allergies)
        try container.encodeIfPresent(birthday, forKey: .birthday)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(sex, forKey: .sex)
        try encodeVersionable(to: encoder)
    }

    public func new(with careKitEntity: OCKEntity) throws -> PCKPatient {

        switch careKitEntity {
        case .patient(let entity):
            return try Self.copyCareKit(entity)
        default:
            if #available(iOS 14.0, watchOS 7.0, *) {
                Logger.patient.error("new(with:) The wrong type (\(careKitEntity.entityType, privacy: .private)) of entity was passed as an argument.")
            } else {
                os_log("new(with:) The wrong type (%{private}@) of entity was passed.", log: .patient, type: .error, careKitEntity.entityType.debugDescription)
            }
            throw ParseCareKitError.classTypeNotAnEligibleType
        }
    }

    public func addToCloud(_ delegate: ParseRemoteDelegate? = nil,
                           completion: @escaping(Result<PCKSynchronizable, Error>) -> Void) {
        self.save(completion: completion)
    }

    public func updateCloud(_ delegate: ParseRemoteDelegate? = nil,
                            completion: @escaping(Result<PCKSynchronizable, Error>) -> Void) {
        guard var previousVersionUUIDs = self.previousVersionUUIDs,
                let uuid = self.uuid else {
                    completion(.failure(ParseCareKitError.couldntUnwrapRequiredField))
            return
        }
        previousVersionUUIDs.append(uuid)

        // Check to see if this entity is already in the Cloud, but not paired locally
        let query = PCKPatient.query(containedIn(key: ParseKey.objectId, array: previousVersionUUIDs))
            .includeAll()
        query.find(callbackQueue: ParseRemote.queue) { results in

            switch results {

            case .success(let foundObjects):
                switch foundObjects.count {
                case 0:
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.patient.debug("updateCloud(), A previous version is suppose to exist in the Cloud, but isn't present, saving as new")
                    } else {
                        os_log("updateCloud(), A previous version is suppose to exist in the Cloud, but isn't present, saving as new", log: .patient, type: .debug)
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
                            Logger.patient.error("updateCloud(), Didn't find previousVersion of this UUID (\(previousVersionUUIDs, privacy: .private)) already exists in Cloud")
                        } else {
                            os_log("updateCloud(), Didn't find previousVersion of this UUID (%{private}) already exists in Cloud", log: .patient, type: .error, previousVersionUUIDs)
                        }
                        completion(.failure(ParseCareKitError.uuidAlreadyExists))
                        return
                    }
                    var updated = self
                    updated = updated.copyRelationalEntities(previousVersion)
                    updated.addToCloud(completion: completion)

                default:
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.patient.error("updateCloud(), UUID (\(uuid, privacy: .private)) already exists in Cloud")
                    } else {
                        os_log("updateCloud(), UUID (%{private}) already exists in Cloud", log: .patient, type: .error, uuid.uuidString)
                    }
                    completion(.failure(ParseCareKitError.uuidAlreadyExists))
                }
            case .failure(let error):
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.patient.error("updateCloud(), \(error.localizedDescription, privacy: .private)")
                } else {
                    os_log("updateCloud(), %{private}", log: .patient, type: .error, error.localizedDescription)
                }
                completion(.failure(error))
            }
        }
    }

    public func pullRevisions(since localClock: Int,
                              cloudClock: OCKRevisionRecord.KnowledgeVector,
                              remoteID: String,
                              mergeRevision: @escaping (Result<OCKRevisionRecord, ParseError>) -> Void) {

        let query = Self.query(ObjectableKey.logicalClock >= localClock,
                               ObjectableKey.remoteID == remoteID)
            .order([.ascending(ObjectableKey.logicalClock), .ascending(ObjectableKey.updatedDate)])
            .includeAll()
        query.find(callbackQueue: ParseRemote.queue) { results in
            switch results {

            case .success(let patients):
                let pulled = patients.compactMap {try? $0.convertToCareKit()}
                let entities = pulled.compactMap {OCKEntity.patient($0)}
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
                        // swiftlint:disable:next line_length
                        Logger.patient.debug("Warning, the table either doesn't exist or is missing the column \"\(ObjectableKey.logicalClock, privacy: .private)\". It should be fixed during the first sync... ParseError: \(error.localizedDescription, privacy: .private)")
                    } else {
                        // swiftlint:disable:next line_length
                        os_log("Warning, the table either doesn't exist or is missing the column \"%{private}\" It should be fixed during the first sync... ParseError: \"%{private}", log: .patient, type: .debug, ObjectableKey.logicalClock, error.localizedDescription)
                    }
                default:
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        // swiftlint:disable:next line_length
                        Logger.patient.debug("An unexpected error occured \(error.localizedDescription, privacy: .private)")
                    } else {
                        os_log("An unexpected error occured \"%{private}",
                               log: .patient, type: .debug, error.localizedDescription)
                    }
                }
                mergeRevision(.failure(error))
            }
        }
    }

    public func pushRevision(_ delegate: ParseRemoteDelegate? = nil,
                             cloudClock: Int,
                             remoteID: String,
                             completion: @escaping (Error?) -> Void) {
        var mutatablePatient = self
        mutatablePatient.logicalClock = cloudClock // Stamp Entity
        mutatablePatient.remoteID = remoteID

        guard mutatablePatient.deletedDate != nil else {
            mutatablePatient.addToCloud { result in

                switch result {

                case .success:
                    completion(nil)
                case .failure(let error):
                    completion(error)
                }
            }
            return
        }

        mutatablePatient.updateCloud { result in

            switch result {

            case .success:
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        }
    }

    public static func copyValues(from other: PCKPatient, to here: PCKPatient) throws -> Self {
        var here = here
        here.copyVersionedValues(from: other)
        here.name = other.name
        here.birthday = other.birthday
        here.sex = other.sex
        here.allergies = other.allergies
        return here
    }

    public static func copyCareKit(_ patientAny: OCKAnyPatient) throws -> PCKPatient {

        guard let patient = patientAny as? OCKPatient else {
            throw ParseCareKitError.cantCastToNeededClassType
        }

        let encoded = try PCKUtility.jsonEncoder().encode(patient)
        var decoded = try PCKUtility.decoder().decode(PCKPatient.self, from: encoded)
        decoded.objectId = patient.uuid.uuidString
        decoded.entityId = patient.id
        if let acl = patient.acl {
            decoded.ACL = acl
        } else {
            decoded.ACL = PCKUtility.getDefaultACL()
        }
        return decoded
    }

    public func convertToCareKit() throws -> OCKPatient {
        var mutablePatient = self
        mutablePatient.encodingForParse = false
        let encoded = try PCKUtility.jsonEncoder().encode(mutablePatient)
        return try PCKUtility.decoder().decode(OCKPatient.self, from: encoded)
    }
}
