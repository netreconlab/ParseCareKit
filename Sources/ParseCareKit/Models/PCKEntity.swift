//
//  PCKEntity.swift
//  ParseCareKit
//
//  Created by Corey Baker on 4/16/23.
//  Copyright © 2023 Network Reconnaissance Lab. All rights reserved.
//

import CareKitStore
import Foundation

/// Holds one of several possible modified entities.
public enum PCKEntity: Hashable, Codable, Sendable {

    /// A patient entity.
    case patient(PCKPatient)

    /// A care plan entity.
    case carePlan(PCKCarePlan)

    /// A contact entity.
    case contact(PCKContact)

    /// A task entity.
    case task(PCKTask)

    /// A HealthKit linked task.
    case healthKitTask(PCKHealthKitTask)

    /// An outcome entity.
    case outcome(PCKOutcome)

    private enum Keys: CodingKey {
        case type
        case object
    }

    /// The type of the contained entity.
    public var entityType: EntityType {
        switch self {
        case .patient: return .patient
        case .carePlan: return .carePlan
        case .contact: return .contact
        case .task: return .task
        case .healthKitTask: return .healthKitTask
        case .outcome: return .outcome
        }
    }

    /// The underlying ParseCareKit type for the respective entity.
    public var value: any PCKVersionable {
        switch self {
        case let .patient(patient): return patient
        case let .carePlan(plan): return plan
        case let .contact(contact): return contact
        case let .task(task): return task
        case let .healthKitTask(task): return task
        case let .outcome(outcome): return outcome
        }
    }

    /// The `OCKEntity` of the `PCKEntity`.
    public func careKit() throws -> OCKEntity {
        switch self {
        case let .patient(patient):
            return OCKEntity.patient(try patient.convertToCareKit())
        case let .carePlan(plan):
            return OCKEntity.carePlan(try plan.convertToCareKit())
        case let .contact(contact):
            return OCKEntity.contact(try contact.convertToCareKit())
        case let .task(task):
            return OCKEntity.task(try task.convertToCareKit())
        case let .healthKitTask(task):
            return OCKEntity.healthKitTask(try task.convertToCareKit())
        case let .outcome(outcome):
            return OCKEntity.outcome(try outcome.convertToCareKit())
        }
    }

    /// Describes the types of entities that may be included in a revision record.
    public enum EntityType: String, Equatable, Codable, CodingKey, CaseIterable {

        /// The patient entity type
        case patient

        /// The care plan entity type
        case carePlan

        /// The contact entity type
        case contact

        /// The task entity type.
        case task

        /// The HealthKit task type.
        case healthKitTask

        /// The outcome entity type.
        case outcome
    }
}

// MARK: Encoding
public extension PCKEntity {

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(entityType, forKey: .type)
        switch self {
        case let .patient(patient): try container.encode(try patient.toPointer(), forKey: .object)
        case let .carePlan(plan): try container.encode(try plan.toPointer(), forKey: .object)
        case let .contact(contact): try container.encode(try contact.toPointer(), forKey: .object)
        case let .task(task): try container.encode(try task.toPointer(), forKey: .object)
        case let .healthKitTask(task): try container.encode(try task.toPointer(), forKey: .object)
        case let .outcome(outcome): try container.encode(try outcome.toPointer(), forKey: .object)
        }
    }
}

// MARK: Decoding
public extension PCKEntity {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        switch try container.decode(EntityType.self, forKey: .type) {
        case .patient: self = .patient(try container.decode(PCKPatient.self, forKey: .object))
        case .carePlan: self = .carePlan(try container.decode(PCKCarePlan.self, forKey: .object))
        case .contact: self = .contact(try container.decode(PCKContact.self, forKey: .object))
        case .task: self = .task(try container.decode(PCKTask.self, forKey: .object))
        case .healthKitTask: self = .healthKitTask(try container.decode(PCKHealthKitTask.self, forKey: .object))
        case .outcome: self = .outcome(try container.decode(PCKOutcome.self, forKey: .object))
        }
    }
}

// MARK: Compatability with OCKEntity
public extension OCKEntity {
    func parseEntity() throws -> PCKEntity {
        switch self {
        case let .patient(patient):
            return PCKEntity.patient(try PCKPatient.new(from: patient))
        case let .carePlan(plan):
            return PCKEntity.carePlan(try PCKCarePlan.new(from: plan))
        case let .contact(contact):
            return PCKEntity.contact(try PCKContact.new(from: contact))
        case let .task(task):
            return PCKEntity.task(try PCKTask.new(from: task))
        case let .healthKitTask(task):
            return PCKEntity.healthKitTask(try PCKHealthKitTask.new(from: task))
        case let .outcome(outcome):
            return PCKEntity.outcome(try PCKOutcome.new(from: outcome))
        }
    }
}
