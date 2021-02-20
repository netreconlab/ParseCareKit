//
//  ParseCareKitConstants.swift
//  ParseCareKit
//
//  Created by Corey Baker on 4/26/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore
import os.log

// swiftlint:disable line_length

// #Mark - Custom Enums
enum CustomKey {
    static let customClass                                  = "customClass"
}

public enum PCKCodingKeys: String, CodingKey {
    case entityId, id // swiftlint:disable:this identifier_name
    case uuid, schemaVersion, createdDate, updatedDate, deletedDate, timezone,
         userInfo, groupIdentifier, tags, source, asset, remoteID, notes,
         logicalClock, className, ACL, objectId, updatedAt, createdAt
    case effectiveDate, previousVersionUUIDs, nextVersionUUIDs
}

/// Types of ParseCareKit classes.
public enum PCKStoreClass: String {
    case carePlan
    case contact
    case outcome
    case patient
    case task
    case healthKitTask

    func getDefault() throws -> PCKSynchronizable {
        switch self {
        case .carePlan:
            let carePlan = OCKCarePlan(id: "", title: "", patientUUID: nil)
            return try CarePlan.copyCareKit(carePlan)
        case .contact:
            let contact = OCKContact(id: "", givenName: "", familyName: "", carePlanUUID: nil)
            return try Contact.copyCareKit(contact)
        case .outcome:
            let outcome = OCKOutcome(taskUUID: UUID(), taskOccurrenceIndex: 0, values: [])
            return try Outcome.copyCareKit(outcome)
        case .patient:
            let patient = OCKPatient(id: "", givenName: "", familyName: "")
            return try Patient.copyCareKit(patient)
        case .task:
            let task = OCKTask(id: "", title: "", carePlanUUID: nil,
                               schedule: .init(composing: [.init(start: Date(), end: nil, interval: .init(day: 1))]))
            return try Task.copyCareKit(task)
        case .healthKitTask:
            let healthKitTask = OCKHealthKitTask(id: "", title: "", carePlanUUID: nil,
                                        schedule: .init(composing: [.init(start: Date(), end: nil, interval: .init(day: 1))]), healthKitLinkage: .init(quantityIdentifier: .activeEnergyBurned, quantityType: .cumulative, unit: .count()))
            return try HealthKitTask.copyCareKit(healthKitTask)
        }
    }

    func orderedArray() -> [PCKStoreClass] {
        return [.patient, .carePlan, .contact, .task, .outcome, .healthKitTask]
    }

    func replaceRemoteConcreteClasses(_ newClasses: [PCKStoreClass: PCKSynchronizable]) throws -> [PCKStoreClass: PCKSynchronizable] {
        var updatedClasses = try getConcrete()

        for (key, value) in newClasses {
            if isCorrectType(key, check: value) {
                updatedClasses[key] = value
            } else {
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.pullRevisions.debug("PCKStoreClass.replaceRemoteConcreteClasses(). Discarding class for `\(key.rawValue, privacy: .private)` because it's of the wrong type. All classes need to subclass a PCK concrete type. If you are trying to map a class to a OCKStore concreate type, pass it to `customClasses` instead. This class isn't compatibile.")
                } else {
                    os_log("PCKStoreClass.replaceRemoteConcreteClasses(). Discarding class for `%{private}@` because it's of the wrong type. All classes need to subclass a PCK concrete type. If you are trying to map a class to a OCKStore concreate type, pass it to `customClasses` instead. This class isn't compatibile.", log: .pullRevisions, type: .debug, key.rawValue)
                }
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
            .task: try PCKStoreClass.task.getDefault()
        ]

        for (key, value) in concreteClasses {
            if !isCorrectType(key, check: value) {
                concreteClasses.removeValue(forKey: key)
            }
        }

        //Ensure all default classes are created
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
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.pullRevisions.debug("PCKStoreClass.replaceConcreteClasses(). Discarding class for `\(key.rawValue, privacy: .private)` because it's of the wrong type. All classes need to subclass a PCK concrete type. If you are trying to map a class to a OCKStore concreate type, pass it to `customClasses` instead. This class isn't compatibile.")
                } else {
                    os_log("PCKStoreClass.replaceConcreteClasses(). Discarding class for `%{private}@` because it's of the wrong type. All classes need to subclass a PCK concrete type. If you are trying to map a class to a OCKStore concreate type, pass it to `customClasses` instead. This class isn't compatibile.", log: .pullRevisions, type: .debug, key.rawValue)
                }
            }
        }
        return updatedClasses
    }

    func isCorrectType(_ type: PCKStoreClass, check: PCKSynchronizable) -> Bool {
        switch type {
        case .carePlan:
            guard (check as? CarePlan) != nil else {
                return false
            }
            return true
        case .contact:
            guard (check as? Contact) != nil else {
                return false
            }
            return true
        case .outcome:
            guard (check as? Outcome) != nil else {
                return false
            }
            return true
        case .patient:
            guard (check as? Patient) != nil else {
                return false
            }
            return true
        case .task:
            guard (check as? Task) != nil else {
                return false
            }
            return true
        case .healthKitTask:
            guard (check as? HealthKitTask) != nil else {
                return false
            }
            return true
        }
    }
}

//#Mark - Parse Database Keys
public enum ParseKey {
    static let objectId = "objectId"
    static let createdAt = "createdAt"
    static let ACL = "ACL"
}

public enum ObjectableKey {
    public static let uuid                                       = "uuid"
    public static let entityId                                   = "entityId"
    public static let asset                                      = "asset"
    public static let groupIdentifier                            = "groupIdentifier"
    public static let notes                                      = "notes"
    public static let timezone                                   = "timezone"
    public static let logicalClock                               = "logicalClock"
    public static let createdDate                                = "createdDate"
    public static let updatedDate                                = "updatedDate"
    public static let tags                                       = "tags"
    public static let userInfo                                   = "userInfo"
    public static let source                                     = "source"
    public static let remoteID                                   = "remoteID"
}

public enum VersionableKey {
    public static let deletedDate                                = "deletedDate"
    public static let effectiveDate                              = "effectiveDate"
    public static let nextVersionUUIDs                            = "nextVersionUUIDs"
    public static let previousVersionUUIDs                        = "previousVersionUUIDs"
}

//#Mark - Patient Class
public enum PatientKey {
    public static let className                                = "Patient"
    public static let allergies                                = "alergies"
    public static let birthday                                 = "birthday"
    public static let sex                                      = "sex"
    public static let name                                     = "name"
}

//#Mark - CarePlan Class
public enum CarePlanKey {
    public static let className                                = "CarePlan"
    public static let patient                                  = "patient"
    public static let title                                    = "title"
}

//#Mark - Contact Class
public enum ContactKey {
    public static let className                                = "Contact"
    public static let carePlan                                 = "carePlan"
    public static let title                                    = "title"
    public static let role                                     = "role"
    public static let organization                             = "organization"
    public static let category                                 = "category"
    public static let name                                     = "name"
    public static let address                                  = "address"
    public static let emailAddresses                           = "emailAddresses"
    public static let phoneNumbers                             = "phoneNumbers"
    public static let messagingNumbers                         = "messagingNumbers"
    public static let otherContactInfo                         = "otherContactInfo"
}

//#Mark - Task Class
public enum TaskKey {
    public static let className                                = "Task"
    public static let title                                    = "title"
    public static let carePlan                                 = "carePlan"
    public static let impactsAdherence                         = "impactsAdherence"
    public static let instructions                             = "instructions"
    public static let elements                                 = "elements"
}

//#Mark - Outcome Class
public enum OutcomeKey {
    public static let className                                = "Outcome"
    public static let deletedDate                              = "deletedDate"
    public static let task                                     = "task"
    public static let taskOccurrenceIndex                      = "taskOccurrenceIndex"
    public static let values                                   = "values"
}

//#Mark - OutcomeValue Class
public enum OutcomeValueKey {
    public static let className                                = "OutcomeValue"
    public static let indexKey                                 = "index"
    public static let kindKey                                  = "kind"
    public static let unitsKey                                 = "units"
}

//#Mark - Note Class
public enum NoteKey {
    public static let className                                = "Note"
    public static let contentKey                               = "content"
    public static let titleKey                                 = "title"
    public static let authorKey                                = "author"
}

//#Mark - Clock Class
public enum ClockKey {
    public static let className                                = "Clock"
    public static let uuid                                     = "uuid"
    public static let vectorKey                                = "vector"
}
