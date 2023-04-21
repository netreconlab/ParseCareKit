//
//  PCKHealthKitTask.swift
//  ParseCareKit
//
//  Created by Corey Baker on 2/20/21.
//  Copyright © 2021 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore
import os.log

// swiftlint:disable line_length
// swiftlint:disable cyclomatic_complexity
// swiftlint:disable function_body_length
// swiftlint:disable type_body_length

/// An `PCKHealthKitTask` is the ParseCareKit equivalent of `OCKHealthKitTask`.  An `OCKHealthKitTask` represents some task or action that a
/// patient is supposed to perform. Tasks are optionally associable with an `OCKCarePlan` and must have a unique
/// id and schedule. The schedule determines when and how often the task should be performed, and the
/// `impactsAdherence` flag may be used to specify whether or not the patients adherence to this task will affect
/// their daily completion rings.
public struct PCKHealthKitTask: PCKVersionable {

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
        "HealthKitTask"
    }

    public var objectId: String?

    public var createdAt: Date?

    public var updatedAt: Date?

    public var ACL: ParseACL?

    public var originalData: Data?

    /// A structure specifying how this task is linked with HealthKit.
    public var healthKitLinkage: OCKHealthKitLinkage?

    /// If true, completion of this task will be factored into the patient's overall adherence. True by default.
    public var impactsAdherence: Bool?

    /// Instructions about how this task should be performed.
    public var instructions: String?

    /// A title that will be used to represent this task to the patient.
    public var title: String?

    /// A schedule that specifies how often this task occurs.
    public var schedule: OCKSchedule?

    /// The care plan to which this task belongs.
    public var carePlan: PCKCarePlan? {
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
        case entityId, schemaVersion, createdDate, updatedDate,
             deletedDate, timezone, userInfo, groupIdentifier,
             tags, source, asset, remoteID, notes, logicalClock
        case previousVersionUUIDs, nextVersionUUIDs, effectiveDate
        case title, carePlan, carePlanUUID, impactsAdherence, instructions, schedule, healthKitLinkage
    }

    public init() {
        ACL = PCKUtility.getDefaultACL()
    }

    public func new(with careKitEntity: OCKEntity) throws -> PCKHealthKitTask {

        switch careKitEntity {
        case .healthKitTask(let entity):
            return try Self.copyCareKit(entity)
        default:
            Logger.healthKitTask.error("new(with:) The wrong type (\(careKitEntity.entityType, privacy: .private)) of entity was passed as an argument.")
            throw ParseCareKitError.classTypeNotAnEligibleType
        }
    }

    public static func copyValues(from other: PCKHealthKitTask, to here: PCKHealthKitTask) throws -> PCKHealthKitTask {
        var here = here
        here.copyVersionedValues(from: other)

        here.impactsAdherence = other.impactsAdherence
        here.instructions = other.instructions
        here.title = other.title
        here.schedule = other.schedule
        here.carePlan = other.carePlan
        here.carePlanUUID = other.carePlanUUID
        return here
    }

    public static func copyCareKit(_ taskAny: OCKAnyTask) throws -> PCKHealthKitTask {

        guard let task = taskAny as? OCKHealthKitTask else {
            throw ParseCareKitError.cantCastToNeededClassType
        }

        let encoded = try PCKUtility.jsonEncoder().encode(task)
        var decoded = try PCKUtility.decoder().decode(Self.self, from: encoded)
        decoded.objectId = task.uuid.uuidString
        decoded.entityId = task.id
        decoded.carePlan = PCKCarePlan(uuid: task.carePlanUUID)
        if let acl = task.acl {
            decoded.ACL = acl
        } else {
            decoded.ACL = PCKUtility.getDefaultACL()
        }
        return decoded
    }

    mutating func prepareEncodingRelational(_ encodingForParse: Bool) {
        if carePlan != nil {
            carePlan?.encodingForParse = encodingForParse
        }
    }

    // Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    public func convertToCareKit() throws -> OCKHealthKitTask {
        var mutableTask = self
        mutableTask.encodingForParse = false
        let encoded = try PCKUtility.jsonEncoder().encode(mutableTask)
        return try PCKUtility.decoder().decode(OCKHealthKitTask.self, from: encoded)
    }
}

extension PCKHealthKitTask {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if encodingForParse {
            try container.encodeIfPresent(carePlan?.toPointer(), forKey: .carePlan)
        }
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(carePlanUUID, forKey: .carePlanUUID)
        try container.encodeIfPresent(impactsAdherence, forKey: .impactsAdherence)
        try container.encodeIfPresent(instructions, forKey: .instructions)
        try container.encodeIfPresent(schedule, forKey: .schedule)
        try container.encodeIfPresent(healthKitLinkage, forKey: .healthKitLinkage)
        try encodeVersionable(to: encoder)
    }
}
