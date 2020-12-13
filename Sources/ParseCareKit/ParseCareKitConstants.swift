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
    case nextVersion, previousVersion, effectiveDate, previousVersionUUID, nextVersionUUID
}

/// Types of ParseCareKit classes.
public enum PCKStoreClass: String {
    case carePlan
    case contact
    case outcome
    case patient
    case task

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
        }
    }

    func orderedArray() -> [PCKStoreClass] {
        return [.patient, .carePlan, .contact, .task, .outcome]
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
    static let uuid                                       = "uuid"
    static let entityId                                   = "entityId"
    static let asset                                      = "asset"
    static let groupIdentifier                            = "groupIdentifier"
    static let notes                                      = "notes"
    static let timezone                                   = "timezone"
    static let logicalClock                               = "logicalClock"
    static let createdDate                                = "createdDate"
    static let updatedDate                                = "updatedDate"
    static let tags                                       = "tags"
    static let userInfo                                   = "userInfo"
    static let source                                     = "source"
    static let remoteID                                   = "remoteID"
}

public enum VersionableKey {
    static let deletedDate                                = "deletedDate"
    static let effectiveDate                              = "effectiveDate"
    static let next                                       = "next"
    static let previous                                   = "previous"
}

//#Mark - Patient Class
public enum PatientKey {
    static let className                                = "Patient"
    static let allergies                                = "alergies"
    static let birthday                                 = "birthday"
    static let sex                                      = "sex"
    static let name                                     = "name"
}

//#Mark - CarePlan Class
public enum CarePlanKey {
    static let className                                = "CarePlan"
    static let patient                                  = "patient"
    static let title                                    = "title"
}

//#Mark - Contact Class
public enum ContactKey {
    static let className                                = "Contact"
    static let carePlan                                 = "carePlan"
    static let title                                    = "title"
    static let role                                     = "role"
    static let organization                             = "organization"
    static let category                                 = "category"
    static let name                                     = "name"
    static let address                                  = "address"
    static let emailAddresses                           = "emailAddresses"
    static let phoneNumbers                             = "phoneNumbers"
    static let messagingNumbers                         = "messagingNumbers"
    static let otherContactInfo                         = "otherContactInfo"
}

//#Mark - Task Class
public enum TaskKey {
    static let className                                = "Task"
    static let title                                    = "title"
    static let carePlan                                 = "carePlan"
    static let impactsAdherence                         = "impactsAdherence"
    static let instructions                             = "instructions"
    static let elements                                 = "elements"
}

//#Mark - Outcome Class
public enum OutcomeKey {
    static let className                                = "Outcome"
    static let deletedDate                              = "deletedDate"
    static let task                                     = "task"
    static let taskOccurrenceIndex                      = "taskOccurrenceIndex"
    static let values                                   = "values"
}

//#Mark - OutcomeValue Class
public enum OutcomeValueKey {
    static let className                                = "OutcomeValue"
    static let indexKey                                 = "index"
    static let kindKey                                  = "kind"
    static let unitsKey                                 = "units"
}

//#Mark - Note Class
public enum NoteKey {
    static let className                                = "Note"
    static let contentKey                               = "content"
    static let titleKey                                 = "title"
    static let authorKey                                = "author"
}

//#Mark - Clock Class
public enum ClockKey {
    static let className                                = "Clock"
    static let uuid                                     = "uuid"
    static let vectorKey                                = "vector"
}
