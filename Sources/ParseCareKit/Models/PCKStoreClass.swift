//
//  PCKStoreClass.swift
//  ParseCareKit
//
//  Created by Corey Baker on 4/17/23.
//  Copyright © 2023 Network Reconnaissance Lab. All rights reserved.
//

import CareKitStore
import Foundation
import os.log

// swiftlint:disable line_length

/// Types of ParseCareKit classes.
public enum PCKStoreClass: String, Hashable, CaseIterable, Sendable {
    /// The ParseCareKit equivalent of `OCKPatient`.
    case patient
    /// The ParseCareKit equivalent of `OCKCarePlan`.
    case carePlan
    /// The ParseCareKit equivalent of `OCKContact`.
    case contact
    /// The ParseCareKit equivalent of `OCKTask`.
    case task
    /// The ParseCareKit equivalent of `OCKHealthKitTask`.
    case healthKitTask
    /// The ParseCareKit equivalent of `OCKOutcome`.
    case outcome

    func getDefault() -> any PCKVersionable.Type {
        switch self {
        case .patient:
            return PCKPatient.self
        case .carePlan:
            return PCKCarePlan.self
        case .contact:
            return PCKContact.self
        case .task:
            return PCKTask.self
        case .healthKitTask:
            return PCKHealthKitTask.self
        case .outcome:
            return PCKOutcome.self
        }
    }

    static func replaceRemoteConcreteClasses(_ newClasses: [PCKStoreClass: any PCKVersionable.Type]) throws -> [PCKStoreClass: any PCKVersionable.Type] {
        var updatedClasses = try getConcrete()

        for (key, value) in newClasses {
            if isCorrectType(key, check: value) {
                updatedClasses[key] = value
            } else {
                Logger.pullRevisions.debug("PCKStoreClass.replaceRemoteConcreteClasses(). Discarding class for `\(key.rawValue, privacy: .private)` because it's of the wrong type. All classes need to subclass a PCK concrete type. If you are trying to map a class to a OCKStore concreate type, pass it to `customClasses` instead. This class is not compatibile")
            }
        }
        return updatedClasses
    }

    static func getConcrete() throws -> [PCKStoreClass: any PCKVersionable.Type] {

        var concreteClasses: [PCKStoreClass: any PCKVersionable.Type] = [
            .carePlan: PCKStoreClass.carePlan.getDefault(),
            .contact: PCKStoreClass.contact.getDefault(),
            .outcome: PCKStoreClass.outcome.getDefault(),
            .patient: PCKStoreClass.patient.getDefault(),
            .task: PCKStoreClass.task.getDefault(),
            .healthKitTask: PCKStoreClass.healthKitTask.getDefault()
        ]

        for (key, value) in concreteClasses {
            // swiftlint:disable for_where
            if !isCorrectType(key, check: value) {
                concreteClasses.removeValue(forKey: key)
            }
        }

        // Ensure all default classes are created
        guard concreteClasses.count == Self.allCases.count else {
            throw ParseCareKitError.couldntCreateConcreteClasses
        }

        return concreteClasses
    }

    static func replaceConcreteClasses(_ newClasses: [PCKStoreClass: any PCKVersionable.Type]) throws -> [PCKStoreClass: any PCKVersionable.Type] {
        var updatedClasses = try getConcrete()

        for (key, value) in newClasses {
            if isCorrectType(key, check: value) {
                updatedClasses[key] = value
            } else {
                Logger.pullRevisions.debug("PCKStoreClass.replaceConcreteClasses(). Discarding class for `\(key.rawValue, privacy: .private)` because it's of the wrong type. All classes need to subclass a PCK concrete type. If you are trying to map a class to a OCKStore concreate type, pass it to `customClasses` instead. This class is not compatibile")
            }
        }
        return updatedClasses
    }

    static func isCorrectType(_ type: PCKStoreClass, check: any PCKVersionable.Type) -> Bool {
        switch type {
        case .carePlan:
            return check is PCKCarePlan.Type
        case .contact:
            return check is PCKContact.Type
        case .outcome:
            return check is PCKOutcome.Type
        case .patient:
            return check is PCKPatient.Type
        case .task:
            return check is PCKTask.Type
        case .healthKitTask:
            return check is PCKHealthKitTask.Type
        }
    }
}
