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
public enum PCKStoreClass: String {
    /// The ParseCareKit equivalent of `OCKCarePlan`.
    case carePlan
    /// The ParseCareKit equivalent of `OCKContact`.
    case contact
    /// The ParseCareKit equivalent of `OCKOutcome`.
    case outcome
    /// The ParseCareKit equivalent of `OCKPatient`.
    case patient
    /// The ParseCareKit equivalent of `OCKTask`.
    case task
    /// The ParseCareKit equivalent of `OCKHealthKitTask`.
    case healthKitTask

    func getDefault() throws -> PCKSynchronizable {
        switch self {
        case .carePlan:
            let carePlan = OCKCarePlan(id: "", title: "",
                                       patientUUID: nil)
            return try PCKCarePlan.copyCareKit(carePlan)
        case .contact:
            let contact = OCKContact(id: "", givenName: "",
                                     familyName: "",
                                     carePlanUUID: nil)
            return try PCKContact.copyCareKit(contact)
        case .outcome:
            let outcome = OCKOutcome(taskUUID: UUID(),
                                     taskOccurrenceIndex: 0,
                                     values: [])
            return try PCKOutcome.copyCareKit(outcome)
        case .patient:
            let patient = OCKPatient(id: "",
                                     givenName: "",
                                     familyName: "")
            return try PCKPatient.copyCareKit(patient)
        case .task:
            let task = OCKTask(id: "",
                               title: "",
                               carePlanUUID: nil,
                               schedule: .init(composing: [.init(start: Date(), end: nil, interval: .init(day: 1))]))
            return try PCKTask.copyCareKit(task)
        case .healthKitTask:
            let healthKitTask = OCKHealthKitTask(id: "",
                                                 title: "",
                                                 carePlanUUID: nil,
                                                 schedule: .init(composing: [.init(start: Date(),
                                                                                   end: nil,
                                                                                   interval: .init(day: 1))]),
                                                 healthKitLinkage: .init(quantityIdentifier: .bodyTemperature,
                                                                         quantityType: .discrete,
                                                                         unit: .degreeCelsius()))
            return try PCKHealthKitTask.copyCareKit(healthKitTask)
        }
    }

    func orderedArray() -> [PCKStoreClass] {
        return [.patient, .carePlan, .contact, .task, .healthKitTask, .outcome]
    }

    func replaceRemoteConcreteClasses(_ newClasses: [PCKStoreClass: PCKSynchronizable]) throws -> [PCKStoreClass: PCKSynchronizable] {
        var updatedClasses = try getConcrete()

        for (key, value) in newClasses {
            if isCorrectType(key, check: value) {
                updatedClasses[key] = value
            } else {
                Logger.pullRevisions.debug("PCKStoreClass.replaceRemoteConcreteClasses(). Discarding class for `\(key.rawValue, privacy: .private)` because it's of the wrong type. All classes need to subclass a PCK concrete type. If you are trying to map a class to a OCKStore concreate type, pass it to `customClasses` instead. This class isn't compatibile")
            }
        }
        return updatedClasses
    }

    func getConcrete() throws -> [PCKStoreClass: PCKSynchronizable] {

        var concreteClasses: [PCKStoreClass: PCKSynchronizable] = [
            .carePlan: try PCKStoreClass.carePlan.getDefault(),
            .contact: try PCKStoreClass.contact.getDefault(),
            .outcome: try PCKStoreClass.outcome.getDefault(),
            .patient: try PCKStoreClass.patient.getDefault(),
            .task: try PCKStoreClass.task.getDefault(),
            .healthKitTask: try PCKStoreClass.healthKitTask.getDefault()
        ]

        for (key, value) in concreteClasses {
            // swiftlint:disable for_where
            if !isCorrectType(key, check: value) {
                concreteClasses.removeValue(forKey: key)
            }
        }

        // Ensure all default classes are created
        guard concreteClasses.count == orderedArray().count else {
            throw ParseCareKitError.couldntCreateConcreteClasses
        }

        return concreteClasses
    }

    func replaceConcreteClasses(_ newClasses: [PCKStoreClass: PCKSynchronizable]) throws -> [PCKStoreClass: PCKSynchronizable] {
        var updatedClasses = try getConcrete()

        for (key, value) in newClasses {
            if isCorrectType(key, check: value) {
                updatedClasses[key] = value
            } else {
                Logger.pullRevisions.debug("PCKStoreClass.replaceConcreteClasses(). Discarding class for `\(key.rawValue, privacy: .private)` because it's of the wrong type. All classes need to subclass a PCK concrete type. If you are trying to map a class to a OCKStore concreate type, pass it to `customClasses` instead. This class isn't compatibile")
            }
        }
        return updatedClasses
    }

    func isCorrectType(_ type: PCKStoreClass, check: PCKSynchronizable) -> Bool {
        switch type {
        case .carePlan:
            guard (check as? PCKCarePlan) != nil else {
                return false
            }
            return true
        case .contact:
            guard (check as? PCKContact) != nil else {
                return false
            }
            return true
        case .outcome:
            guard (check as? PCKOutcome) != nil else {
                return false
            }
            return true
        case .patient:
            guard (check as? PCKPatient) != nil else {
                return false
            }
            return true
        case .task:
            guard (check as? PCKTask) != nil else {
                return false
            }
            return true
        case .healthKitTask:
            guard (check as? PCKHealthKitTask) != nil else {
                return false
            }
            return true
        }
    }
}
