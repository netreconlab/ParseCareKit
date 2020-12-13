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
public final class Patient: PCKVersionable {
    public internal(set) var nextVersion: Patient? {
        didSet {
            nextVersionUUID = nextVersion?.uuid
        }
    }

    public internal(set) var nextVersionUUID: UUID? {
        didSet {
            if nextVersionUUID != nextVersion?.uuid {
                nextVersion = nil
            }
        }
    }

    public internal(set) var previousVersion: Patient? {
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

    public var effectiveDate: Date?

    public internal(set) var uuid: UUID?

    var entityId: String?

    public internal(set) var logicalClock: Int?

    public internal(set) var schemaVersion: OCKSemanticVersion?

    public internal(set) var createdDate: Date?

    public internal(set) var updatedDate: Date?

    public internal(set) var deletedDate: Date?

    public var timezone: TimeZone?

    public var userInfo: [String: String]?

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

    public var ACL: ParseACL?

    /// A list of substances this patient is allergic to.
    public var allergies: [String]?

    /// The patient's birthday, used to compute their age.
    public var birthday: Date?

    /// The patient's name.
    public var name: PersonNameComponents?

    /// The patient's biological sex.
    public var sex: OCKBiologicalSex?

    /// A textual representation of this instance, suitable for debugging.
    public var localizedDescription: String {
        "\(debugDescription) name=\(String(describing: name)) birthday=\(String(describing: birthday)) sex=\(String(describing: sex)) allergies=\(String(describing: allergies))"
    }

    enum CodingKeys: String, CodingKey {
        case objectId, createdAt, updatedAt
        case uuid, entityId, schemaVersion, createdDate, updatedDate, deletedDate, timezone, userInfo, groupIdentifier, tags, source, asset, remoteID, notes, logicalClock
        case previousVersionUUID, nextVersionUUID, previousVersion, nextVersion, effectiveDate
        case allergies, birthday, name, sex
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(allergies, forKey: .allergies)
        try container.encodeIfPresent(birthday, forKey: .birthday)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(sex, forKey: .sex)
        try encodeVersionable(to: encoder)
        encodingForParse = true
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

    public func addToCloud(overwriteRemote: Bool, completion: @escaping(Result<PCKSynchronizable, Error>) -> Void) {
        guard PCKUser.current != nil,
              let uuid = self.uuid else {
            completion(.failure(ParseCareKitError.requiredValueCantBeUnwrapped))
            return
        }

        //Check to see if already in the cloud
        let query = Self.query(ObjectableKey.uuid == uuid)
        query.first(callbackQueue: .main) { result in

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
        guard PCKUser.current != nil,
              let uuid = self.uuid,
            let previousVersionUUID = self.previousVersionUUID else {
            completion(.failure(ParseCareKitError.requiredValueCantBeUnwrapped))
            return
        }

        //Check to see if this entity is already in the Cloud, but not paired locally
        let query = Patient.query(containedIn(key: ObjectableKey.uuid, array: [uuid, previousVersionUUID]))
            .include([VersionableKey.next, VersionableKey.previous, ObjectableKey.notes])
        query.find(callbackQueue: .main) { results in

            switch results {

            case .success(let foundObjects):
                switch foundObjects.count {
                case 0:
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.patient.debug("updateCloud(), A previous version is suppose to exist in the Cloud, but isn't present, saving as new")
                    } else {
                        os_log("updateCloud(), A previous version is suppose to exist in the Cloud, but isn't present, saving as new", log: .patient, type: .debug)
                    }
                    self.addToCloud(overwriteRemote: false, completion: completion)
                case 1:
                    //This is the typical case
                    guard let previousVersion = foundObjects.first(where: {$0.uuid == previousVersionUUID}) else {
                        if #available(iOS 14.0, watchOS 7.0, *) {
                            Logger.patient.error("updateCloud(), Didn't find previousVersion of this UUID (\(previousVersionUUID, privacy: .private)) already exists in Cloud")
                        } else {
                            os_log("updateCloud(), Didn't find previousVersion of this UUID (%{private}) already exists in Cloud", log: .patient, type: .error, previousVersionUUID.uuidString)
                        }
                        completion(.failure(ParseCareKitError.uuidAlreadyExists))
                        return
                    }
                    var updated = self
                    updated = updated.copyRelationalEntities(previousVersion)
                    updated.addToCloud(overwriteRemote: false, completion: completion)

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

    public func pullRevisions(since localClock: Int, cloudClock: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void) {

        let query = Self.query(ObjectableKey.logicalClock >= localClock)
            .order([.ascending(ObjectableKey.logicalClock), .ascending(ParseKey.createdAt)])
            .include([VersionableKey.next, VersionableKey.previous, ObjectableKey.notes])
        query.find(callbackQueue: .main) { results in
            switch results {

            case .success(let carePlans):
                let pulled = carePlans.compactMap {try? $0.convertToCareKit()}
                let entities = pulled.compactMap {OCKEntity.patient($0)}
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
                mergeRevision(revision)
            }
        }
    }

    public func pushRevision(cloudClock: Int, overwriteRemote: Bool, completion: @escaping (Error?) -> Void) {

        self.logicalClock = cloudClock //Stamp Entity

        guard self.previousVersionUUID != nil else {
            self.addToCloud(overwriteRemote: false) { result in

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

    public class func copyValues(from other: Patient, to here: Patient) throws -> Self {
        var here = here
        here.copyVersionedValues(from: other)
        here.name = other.name
        here.birthday = other.birthday
        here.sex = other.sex
        here.allergies = other.allergies
        guard let copied = here as? Self else {
            throw ParseCareKitError.cantCastToNeededClassType
        }
        return copied
    }

    public class func copyCareKit(_ patientAny: OCKAnyPatient) throws -> Patient {

        guard let patient = patientAny as? OCKPatient else {
            throw ParseCareKitError.cantCastToNeededClassType
        }

        let encoded = try ParseCareKitUtility.encoder().encode(patient)
        let decoded = try ParseCareKitUtility.decoder().decode(Patient.self, from: encoded)
        decoded.entityId = patient.id
        decoded.ACL = try? ParseACL.defaultACL()
        return decoded
    }

    func prepareEncodingRelational(_ encodingForParse: Bool) {
        previousVersion?.encodingForParse = encodingForParse
        nextVersion?.encodingForParse = encodingForParse
        notes?.forEach {
            $0.encodingForParse = encodingForParse
        }
    }

    public func convertToCareKit() throws -> OCKPatient {
        self.encodingForParse = false
        let encoded = try ParseCareKitUtility.jsonEncoder().encode(self)
        return try ParseCareKitUtility.decoder().decode(OCKPatient.self, from: encoded)
    }
}
