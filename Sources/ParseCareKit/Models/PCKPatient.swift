//
//  PCKPatients.swift
//  ParseCareKit
//
//  Created by Corey Baker on 10/5/19.
//  Copyright © 2019 Network Reconnaissance Lab. All rights reserved.
//

import CareKitEssentials
import CareKitStore
import Foundation
import os.log
import ParseSwift

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

    public var clock: PCKClock?

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

    public static func new(from careKitEntity: OCKEntity) throws -> PCKPatient {

        switch careKitEntity {
        case .patient(let entity):
            return try new(from: entity)
        default:
            Logger.patient.error("new(with:) The wrong type (\(careKitEntity.entityType, privacy: .private)) of entity was passed as an argument.")
            throw ParseCareKitError.classTypeNotAnEligibleType
        }
    }

    public static func copyValues(from other: PCKPatient, to here: PCKPatient) throws -> Self {
        var here = here
        here.copyVersionedValues(from: other)
        here.previousVersionUUIDs = other.previousVersionUUIDs
        here.nextVersionUUIDs = other.nextVersionUUIDs
        here.name = other.name
        here.birthday = other.birthday
        here.sex = other.sex
        here.allergies = other.allergies
        return here
    }

    /**
     Creates a new ParseCareKit object from a specified CareKit Patient.

     - parameter from: The CareKit Patient used to create the new ParseCareKit object.
     - returns: Returns a new version of `Self`
     - throws: `Error`.
    */
    public static func new(from patientAny: any OCKAnyPatient) throws -> PCKPatient {

        guard let patient = patientAny as? OCKPatient else {
            throw ParseCareKitError.cantCastToNeededClassType
        }

        let encoded = try PCKUtility.jsonEncoder().encode(patient)
        var decoded = try PCKUtility.decoder().decode(PCKPatient.self, from: encoded)
        decoded.objectId = patient.uuid.uuidString
        decoded.entityId = patient.id
        decoded.previousVersions = patient.previousVersionUUIDs.map { Pointer<Self>(objectId: $0.uuidString) }
        decoded.nextVersions = patient.nextVersionUUIDs.map { Pointer<Self>(objectId: $0.uuidString) }
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
