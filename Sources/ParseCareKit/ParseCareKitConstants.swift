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

public enum ParseCareKitConstants {
    static let defaultACL = "edu.uky.cs.netreconlab.ParseCareKit_defaultACL"
    static let acl = "_acl"
    static let administratorRole = "Administrators"
}

// MARK: Coding
enum PCKCodingKeys: String, CodingKey {
    case entityId, id
    case uuid, schemaVersion, createdDate, updatedDate, deletedDate, timezone,
         userInfo, groupIdentifier, tags, source, asset, remoteID, notes,
         logicalClock, className, ACL, objectId, updatedAt, createdAt
    case effectiveDate, previousVersionUUIDs, nextVersionUUIDs
}

// MARK: Custom Enums
enum CustomKey {
    static let customClass                                  = "customClass"
}

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
            let carePlan = OCKCarePlan(id: "", title: "", patientUUID: nil)
            return try PCKCarePlan.copyCareKit(carePlan)
        case .contact:
            let contact = OCKContact(id: "", givenName: "", familyName: "", carePlanUUID: nil)
            return try PCKContact.copyCareKit(contact)
        case .outcome:
            let outcome = OCKOutcome(taskUUID: UUID(), taskOccurrenceIndex: 0, values: [])
            return try PCKOutcome.copyCareKit(outcome)
        case .patient:
            let patient = OCKPatient(id: "", givenName: "", familyName: "")
            return try PCKPatient.copyCareKit(patient)
        case .task:
            let task = OCKTask(id: "", title: "", carePlanUUID: nil,
                               schedule: .init(composing: [.init(start: Date(), end: nil, interval: .init(day: 1))]))
            return try PCKTask.copyCareKit(task)
        case .healthKitTask:
            let healthKitTask = OCKHealthKitTask(id: "", title: "", carePlanUUID: nil,
                                                 schedule: .init(composing: [.init(start: Date(), end: nil, interval: .init(day: 1))]), healthKitLinkage: .init(quantityIdentifier: .bodyTemperature, quantityType: .discrete, unit: .degreeCelsius()))
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
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.pullRevisions.debug("PCKStoreClass.replaceRemoteConcreteClasses(). Discarding class for `\(key.rawValue, privacy: .private)` because it's of the wrong type. All classes need to subclass a PCK concrete type. If you are trying to map a class to a OCKStore concreate type, pass it to `customClasses` instead. This class isn't compatibile")
                } else {
                    os_log("PCKStoreClass.replaceRemoteConcreteClasses(). Discarding class for `%{private}@` because it's of the wrong type. All classes need to subclass a PCK concrete type. If you are trying to map a class to a OCKStore concreate type, pass it to `customClasses` instead. This class isn't compatibile", log: .pullRevisions, type: .debug, key.rawValue)
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
            .task: try PCKStoreClass.task.getDefault(),
            .healthKitTask: try PCKStoreClass.healthKitTask.getDefault()
        ]

        for (key, value) in concreteClasses {
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
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.pullRevisions.debug("PCKStoreClass.replaceConcreteClasses(). Discarding class for `\(key.rawValue, privacy: .private)` because it's of the wrong type. All classes need to subclass a PCK concrete type. If you are trying to map a class to a OCKStore concreate type, pass it to `customClasses` instead. This class isn't compatibile")
                } else {
                    os_log("PCKStoreClass.replaceConcreteClasses(). Discarding class for `%{private}@` because it's of the wrong type. All classes need to subclass a PCK concrete type. If you are trying to map a class to a OCKStore concreate type, pass it to `customClasses` instead. This class isn't compatibile", log: .pullRevisions, type: .debug, key.rawValue)
                }
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

// MARK: Parse Database Keys

/// Parse business logic keys. These keys can be used for querying Parse objects.
public enum ParseKey {
    /// objectId key.
    public static let objectId = "objectId"
    /// createdAt key.
    public static let createdAt = "createdAt"
    /// updatedAt key.
    public static let updatedAt = "updatedAt"
    /// objectId key.
    public static let ACL = "ACL"
}

/// Keys for all `PCKObjectable` objects. These keys can be used for querying Parse objects.
public enum ObjectableKey {
    /// entityId key.
    public static let entityId                                   = "entityId"
    /// asset key.
    public static let asset                                      = "asset"
    /// groupIdentifier key.
    public static let groupIdentifier                            = "groupIdentifier"
    /// notes key.
    public static let notes                                      = "notes"
    /// timezone key.
    public static let timezone                                   = "timezone"
    /// logicalClock key.
    public static let logicalClock                               = "logicalClock"
    /// createdDate key.
    public static let createdDate                                = "createdDate"
    /// updatedDate key.
    public static let updatedDate                                = "updatedDate"
    /// tags key.
    public static let tags                                       = "tags"
    /// userInfo key.
    public static let userInfo                                   = "userInfo"
    /// source key.
    public static let source                                     = "source"
    /// remoteID key.
    public static let remoteID                                   = "remoteID"
}

/// Keys for all `PCKVersionable` objects. These keys can be used for querying Parse objects.
public enum VersionableKey {
    /// deletedDate key.
    public static let deletedDate                                = "deletedDate"
    /// effectiveDate key.
    public static let effectiveDate                              = "effectiveDate"
    /// nextVersionUUIDs key.
    public static let nextVersionUUIDs                            = "nextVersionUUIDs"
    /// previousVersionUUIDs key.
    public static let previousVersionUUIDs                        = "previousVersionUUIDs"
}

// MARK: Patient Class
/// Keys for `PCKPatient` objects. These keys can be used for querying Parse objects.
public enum PatientKey {
    /// className key.
    public static let className                                = "Patient"
    /// allergies key.
    public static let allergies                                = "alergies"
    /// birthday key.
    public static let birthday                                 = "birthday"
    /// sex key.
    public static let sex                                      = "sex"
    /// name key.
    public static let name                                     = "name"
}

// MARK: CarePlan Class
/// Keys for `PCKCarePlan` objects. These keys can be used for querying Parse objects.
public enum CarePlanKey {
    /// className key.
    public static let className                                = "CarePlan"
    /// patient key.
    public static let patient                                  = "patient"
    /// title key.
    public static let title                                    = "title"
}

// MARK: Contact Class
/// Keys for `PCKContact` objects. These keys can be used for querying Parse objects.
public enum ContactKey {
    /// className key.
    public static let className                                = "Contact"
    /// carePlan key.
    public static let carePlan                                 = "carePlan"
    /// title key.
    public static let title                                    = "title"
    /// role key.
    public static let role                                     = "role"
    /// organization key.
    public static let organization                             = "organization"
    /// category key.
    public static let category                                 = "category"
    /// name key.
    public static let name                                     = "name"
    /// address key.
    public static let address                                  = "address"
    /// emailAddresses key.
    public static let emailAddresses                           = "emailAddresses"
    /// phoneNumbers key.
    public static let phoneNumbers                             = "phoneNumbers"
    /// messagingNumbers key.
    public static let messagingNumbers                         = "messagingNumbers"
    /// otherContactInfo key.
    public static let otherContactInfo                         = "otherContactInfo"
}

// MARK: Task Class
/// Keys for `PCKTask` objects. These keys can be used for querying Parse objects.
public enum TaskKey {
    /// className key.
    public static let className                                = "Task"
    /// title key.
    public static let title                                    = "title"
    /// carePlan key.
    public static let carePlan                                 = "carePlan"
    /// impactsAdherence key.
    public static let impactsAdherence                         = "impactsAdherence"
    /// instructions key.
    public static let instructions                             = "instructions"
    /// elements key.
    public static let elements                                 = "elements"
}

// MARK: Outcome Class
/// Keys for `PCKOutcome` objects. These keys can be used for querying Parse objects.
public enum OutcomeKey {
    /// className key.
    public static let className                                = "Outcome"
    /// deletedDate key.
    public static let deletedDate                              = "deletedDate"
    /// task key.
    public static let task                                     = "task"
    /// taskOccurrenceIndex key.
    public static let taskOccurrenceIndex                      = "taskOccurrenceIndex"
    /// values key.
    public static let values                                   = "values"
}

// MARK: Clock Class
/// Keys for `Clock` objects. These keys can be used for querying Parse objects.
public enum ClockKey {
    /// className key.
    public static let className                                = "Clock"
    /// uuid key.
    public static let uuid                                     = "uuid"
    /// vector key.
    public static let vector                                   = "vector"
}
