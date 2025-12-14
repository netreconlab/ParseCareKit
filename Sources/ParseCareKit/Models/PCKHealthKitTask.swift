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

    #if canImport(HealthKit)
    /// A structure specifying how this task is linked with HealthKit.
    public var healthKitLinkage: OCKHealthKitLinkage? {
        get {
            guard let data = healthKitLinkageString?.data(using: .utf8) else {
                return nil
            }
            return try? JSONDecoder().decode(OCKHealthKitLinkage.self,
                                             from: data)
        } set {
            guard let json = try? JSONEncoder().encode(newValue),
                    let encodedString = String(data: json, encoding: .utf8) else {
                healthKitLinkageString = nil
                return
            }
            healthKitLinkageString = encodedString
        }
    }
    #endif

    /// A string specifying how this task is linked with HealthKit.
    public var healthKitLinkageString: String?

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
        case objectId, createdAt, updatedAt,
             className, ACL, uuid
        case entityId, schemaVersion, createdDate, updatedDate,
             deletedDate, timezone, userInfo, groupIdentifier,
             tags, source, asset, remoteID, notes, logicalClock
        case previousVersionUUIDs, nextVersionUUIDs, effectiveDate
        case title, carePlan, carePlanUUID, impactsAdherence,
             instructions, schedule, healthKitLinkageString
        case previousVersions, nextVersions
        #if canImport(HealthKit)
        case healthKitLinkage
        #endif
    }

    public init() {
        ACL = PCKUtility.getDefaultACL()
    }

    public static func new(from careKitEntity: OCKEntity) throws -> PCKHealthKitTask {

        switch careKitEntity {
        case .healthKitTask(let entity):
            return try new(from: entity)
        default:
            Logger.healthKitTask.error("new(with:) The wrong type (\(careKitEntity.entityType, privacy: .private)) of entity was passed as an argument.")
            throw ParseCareKitError.classTypeNotAnEligibleType
        }
    }

    public static func copyValues(from other: PCKHealthKitTask, to here: PCKHealthKitTask) throws -> PCKHealthKitTask {
        var here = here
        here.copyVersionedValues(from: other)
        here.previousVersionUUIDs = other.previousVersionUUIDs
        here.nextVersionUUIDs = other.nextVersionUUIDs
        here.impactsAdherence = other.impactsAdherence
        here.instructions = other.instructions
        here.title = other.title
        here.schedule = other.schedule
        here.carePlan = other.carePlan
        here.carePlanUUID = other.carePlanUUID
        return here
    }

    /**
     Creates a new ParseCareKit object from a specified CareKit Task.

     - parameter from: The CareKit Task used to create the new ParseCareKit object.
     - returns: Returns a new version of `Self`
     - throws: `Error`.
    */
    public static func new(from taskAny: any OCKAnyTask) throws -> PCKHealthKitTask {

        guard let task = taskAny as? OCKHealthKitTask else {
            throw ParseCareKitError.cantCastToNeededClassType
        }

        let encoded = try PCKUtility.jsonEncoder().encode(task)
        var decoded = try PCKUtility.decoder().decode(Self.self, from: encoded)
        decoded.objectId = task.uuid.uuidString
        decoded.entityId = task.id
        decoded.carePlan = PCKCarePlan(uuid: task.carePlanUUID)
        decoded.previousVersions = task.previousVersionUUIDs.map { Pointer<Self>(objectId: $0.uuidString) }
        decoded.nextVersions = task.nextVersionUUIDs.map { Pointer<Self>(objectId: $0.uuidString) }
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

public extension PCKHealthKitTask {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.objectId = try container.decodeIfPresent(String.self, forKey: .objectId)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        self.ACL = try container.decodeIfPresent(ParseACL.self, forKey: .ACL)
        self.healthKitLinkageString = try container.decodeIfPresent(String.self, forKey: .healthKitLinkageString)
        #if canImport(HealthKit)
        if healthKitLinkageString == nil {
            self.healthKitLinkage = try container.decodeIfPresent(OCKHealthKitLinkage.self, forKey: .healthKitLinkage)
        }
        #endif
        self.carePlan = try container.decodeIfPresent(PCKCarePlan.self, forKey: .carePlan)
        self.carePlanUUID = try container.decodeIfPresent(UUID.self, forKey: .carePlanUUID)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.logicalClock = try container.decodeIfPresent(Int.self, forKey: .logicalClock)
        self.impactsAdherence = try container.decodeIfPresent(Bool.self, forKey: .impactsAdherence)
        self.instructions = try container.decodeIfPresent(String.self, forKey: .instructions)
        self.schedule = try container.decodeIfPresent(OCKSchedule.self, forKey: .schedule)
        self.entityId = try container.decodeIfPresent(String.self, forKey: .entityId)
        self.createdDate = try container.decodeIfPresent(Date.self, forKey: .createdDate)
        self.updatedDate = try container.decodeIfPresent(Date.self, forKey: .updatedDate)
        self.deletedDate = try container.decodeIfPresent(Date.self, forKey: .deletedDate)
        self.effectiveDate = try container.decodeIfPresent(Date.self, forKey: .effectiveDate)
        self.timezone = try container.decodeIfPresent(TimeZone.self, forKey: .timezone)
        self.previousVersions = try container.decodeIfPresent([Pointer<Self>].self, forKey: .previousVersions)
        self.nextVersions = try container.decodeIfPresent([Pointer<Self>].self, forKey: .nextVersions)
        self.previousVersionUUIDs = try container.decodeIfPresent([UUID].self, forKey: .previousVersionUUIDs)
        self.nextVersionUUIDs = try container.decodeIfPresent([UUID].self, forKey: .nextVersionUUIDs)
        self.userInfo = try container.decodeIfPresent([String: String].self, forKey: .userInfo)
        self.remoteID = try container.decodeIfPresent(String.self, forKey: .remoteID)
        self.source = try container.decodeIfPresent(String.self, forKey: .source)
        self.asset = try container.decodeIfPresent(String.self, forKey: .asset)
        self.schemaVersion = try container.decodeIfPresent(OCKSemanticVersion.self, forKey: .schemaVersion)
        self.groupIdentifier = try container.decodeIfPresent(String.self, forKey: .groupIdentifier)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags)
        self.notes = try container.decodeIfPresent([OCKNote].self, forKey: .notes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if encodingForParse {
            try container.encodeIfPresent(carePlan?.toPointer(), forKey: .carePlan)
            try container.encodeIfPresent(healthKitLinkageString, forKey: .healthKitLinkageString)
        } else {
            #if canImport(HealthKit)
            try container.encodeIfPresent(healthKitLinkage, forKey: .healthKitLinkage)
            #endif
        }
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(carePlanUUID, forKey: .carePlanUUID)
        try container.encodeIfPresent(impactsAdherence, forKey: .impactsAdherence)
        try container.encodeIfPresent(instructions, forKey: .instructions)
        try container.encodeIfPresent(schedule, forKey: .schedule)
        try encodeVersionable(to: encoder)
    }
}
