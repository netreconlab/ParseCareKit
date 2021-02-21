//
//  Patients.swift
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

/// An `Patient` is the ParseCareKit equivalent of `OCKPatient`.  An `OCKPatient` represents a patient.
public struct Patient: PCKVersionable {

    public var nextVersionUUIDs: [UUID]

    public var previousVersionUUIDs: [UUID]

    public var effectiveDate: Date?

    public var uuid: UUID

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

    public var objectId: String?

    public var createdAt: Date?

    public var updatedAt: Date?

    public var ACL: ParseACL? = try? ParseACL.defaultACL()

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
        case uuid, entityId, schemaVersion, createdDate, updatedDate, deletedDate, timezone, userInfo, groupIdentifier, tags, source, asset, remoteID, notes, logicalClock
        case previousVersionUUIDs, nextVersionUUIDs, effectiveDate
        case allergies, birthday, name, sex
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(allergies, forKey: .allergies)
        try container.encodeIfPresent(birthday, forKey: .birthday)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(sex, forKey: .sex)
        try encodeVersionable(to: encoder)
    }

    public func new(with careKitEntity: OCKEntity) throws -> Patient {

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

    public func addToCloud(completion: @escaping(Result<PCKSynchronizable, Error>) -> Void) {

        //Check to see if already in the cloud
        let query = Self.query(ObjectableKey.uuid == uuid)
        query.first(callbackQueue: ParseRemoteSynchronizationManager.queue) { result in

            switch result {

            case .success(let foundEntity):
                guard foundEntity.entityId == self.entityId else {
                    //This object has a duplicate uuid but isn't the same object
                    completion(.failure(ParseCareKitError.uuidAlreadyExists))
                    return
                }
                completion(.success(foundEntity))
                /*
                if overwriteRemote {
                    self.updateCloud(completion: completion)
                } else {
                    //This object already exists on server, ignore gracefully
                    completion(.success(foundEntity))
                }*/

            case .failure(let error):

                switch error.code {
                case .internalServer, .objectNotFound: //1 - this column hasn't been added. 101 - Query returned no results
                    self.save(completion: completion)
                default:
                    //There was a different issue that we don't know how to handle
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.patient.error("addToCloud(), \(error.localizedDescription, privacy: .private)")
                    } else {
                        os_log("addToCloud(), %{private}@", log: .patient, type: .error, error.localizedDescription)
                    }
                    completion(.failure(error))
                }
                return
            }
        }
    }

    public func updateCloud(completion: @escaping(Result<PCKSynchronizable, Error>) -> Void) {
        var previousVersionUUIDs = self.previousVersionUUIDs
        previousVersionUUIDs.append(uuid)
        //Check to see if this entity is already in the Cloud, but not paired locally
        let query = Patient.query(containedIn(key: ObjectableKey.uuid, array: previousVersionUUIDs))
            .includeAll()
        query.find(callbackQueue: ParseRemoteSynchronizationManager.queue) { results in

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
                    //This is the typical case
                    guard let previousVersion = foundObjects.first(where: {previousVersionUUIDs.contains($0.uuid)}) else {
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

    public func pullRevisions(since localClock: Int, cloudClock: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (Result<OCKRevisionRecord, ParseError>) -> Void) {

        let query = Self.query(ObjectableKey.logicalClock >= localClock)
            .order([.ascending(ObjectableKey.logicalClock), .ascending(ParseKey.createdAt)])
            .includeAll()
        query.find(callbackQueue: ParseRemoteSynchronizationManager.queue) { results in
            switch results {

            case .success(let carePlans):
                let pulled = carePlans.compactMap {try? $0.convertToCareKit()}
                let entities = pulled.compactMap {OCKEntity.patient($0)}
                let revision = OCKRevisionRecord(entities: entities, knowledgeVector: cloudClock)
                mergeRevision(.success(revision))
            case .failure(let error):

                switch error.code {
                case .internalServer, .objectNotFound:
                    //1 - this column hasn't been added. 101 - Query returned no results
                    //If the query was looking in a column that wasn't a default column,
                    //it will return nil if the table doesn't contain the custom column
                    //Saving the new item with the custom column should resolve the issue
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

    public func pushRevision(cloudClock: Int, completion: @escaping (Error?) -> Void) {
        var mutatablePatient = self
        mutatablePatient.logicalClock = cloudClock //Stamp Entity

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

    public static func copyValues(from other: Patient, to here: Patient) throws -> Self {
        var here = here
        here.copyVersionedValues(from: other)
        here.name = other.name
        here.birthday = other.birthday
        here.sex = other.sex
        here.allergies = other.allergies
        return here
    }

    public static func copyCareKit(_ patientAny: OCKAnyPatient) throws -> Patient {

        guard let patient = patientAny as? OCKPatient else {
            throw ParseCareKitError.cantCastToNeededClassType
        }

        let encoded = try ParseCareKitUtility.jsonEncoder().encode(patient)
        var decoded = try ParseCareKitUtility.decoder().decode(Patient.self, from: encoded)
        decoded.entityId = patient.id
        return decoded
    }
/*
    mutating func prepareEncodingRelational(_ encodingForParse: Bool) {
        var updatedNotes = [OCKNote]()
        notes?.forEach {
            var update = $0
            update.encodingForParse = encodingForParse
            updatedNotes.append(update)
        }
        self.notes = updatedNotes
    }*/

    public func convertToCareKit() throws -> OCKPatient {
        var mutablePatient = self
        mutablePatient.encodingForParse = false
        let encoded = try ParseCareKitUtility.jsonEncoder().encode(mutablePatient)
        return try ParseCareKitUtility.decoder().decode(OCKPatient.self, from: encoded)
    }
}
