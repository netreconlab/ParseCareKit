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

    public var originalData: Data?

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
            Logger.carePlan.error("new(with:) The wrong type (\(careKitEntity.entityType, privacy: .private)) of entity was passed as an argument.")
            throw ParseCareKitError.classTypeNotAnEligibleType
        }
    }

    public static func copyValues(from other: PCKCarePlan, to here: PCKCarePlan) throws -> Self {
        var here = here
        here.copyVersionedValues(from: other)
        here.previousVersionUUIDs = other.previousVersionUUIDs
        here.nextVersionUUIDs = other.nextVersionUUIDs
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
        decoded.patient = PCKPatient(uuid: carePlan.patientUUID)
        decoded.previousVersions = carePlan.previousVersionUUIDs.map { Pointer<Self>(objectId: $0.uuidString) }
        decoded.nextVersions = carePlan.nextVersionUUIDs.map { Pointer<Self>(objectId: $0.uuidString) }
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
