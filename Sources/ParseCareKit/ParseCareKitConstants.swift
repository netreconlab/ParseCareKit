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

// #Mark - Custom Enums
public enum PCKCodingKeys: String, CodingKey { // swiftlint:disable:this nesting
    case entityId, id
    case uuid, schemaVersion, createdDate, updatedDate, deletedDate, timezone, userInfo, groupIdentifier, tags, source, asset, remoteID, notes, logicalClock, className, ACL, objectId, updatedAt, createdAt
    case nextVersion, previousVersion, effectiveDate, previousVersionUUID, nextVersionUUID
}


enum ParseCareKitError: Error {
    case userNotLoggedIn
    case relatedEntityNotInCloud
    case requiredValueCantBeUnwrapped
    case objectIdDoesntMatchRemoteId
    case objectNotFoundOnParseServer
    case cloudClockLargerThanLocalWhilePushRevisions
    case couldntUnwrapClock
    case cantUnwrapSelf
    case cloudVersionNewerThanLocal
    case uuidAlreadyExists
    case cantCastToNeededClassType
    case classTypeNotAnEligibleType
    case couldntCreateConcreteClasses
}

extension ParseCareKitError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .userNotLoggedIn:
            return NSLocalizedString("ParseCareKit: Parse User isn't logged in.", comment: "Login error")
        case .relatedEntityNotInCloud:
            return NSLocalizedString("ParseCareKit: Related entity isn't in cloud.", comment: "Related entity error")
        case .requiredValueCantBeUnwrapped:
            return NSLocalizedString("ParseCareKit: Required value can't be unwrapped.", comment: "Unwrapping error")
        case .couldntUnwrapClock:
            return NSLocalizedString("ParseCareKit: Clock can't be unwrapped.", comment: "Clock Unwrapping error")
        case .objectIdDoesntMatchRemoteId:
            return NSLocalizedString("ParseCareKit: remoteId and objectId don't match.", comment: "Remote/Local mismatch error")
        case .cloudClockLargerThanLocalWhilePushRevisions:
            return NSLocalizedString("Cloud clock larger than local during pushRevisions, not pushing", comment: "Knowledge vector larger in Cloud")
        case .cantUnwrapSelf:
            return NSLocalizedString("Can't unwrap self. This class has already been deallocated", comment: "Can't unwrap self, class deallocated")
        case .cloudVersionNewerThanLocal:
            return NSLocalizedString("Can't sync, the Cloud version newere than local version", comment: "Cloud version newer than local version")
        case .uuidAlreadyExists:
            return NSLocalizedString("Can't sync, the uuid already exists in the Cloud", comment: "UUID isn't unique")
        case .cantCastToNeededClassType:
            return NSLocalizedString("Can't cast to needed class type", comment: "Can't cast to needed class type")
        case .classTypeNotAnEligibleType:
            return NSLocalizedString("PCKClass type isn't an eligible type", comment: "PCKClass type isn't an eligible type")
        case .couldntCreateConcreteClasses:
            return NSLocalizedString("Couldn't create concrete classes", comment: "Couldn't create concrete classes")
        case .objectNotFoundOnParseServer:
            return NSLocalizedString("Object couldn't be found on the Parse Server", comment: "Object couldn't be found on the Parse Server")
        }
    }
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
            let task = OCKTask(id: "", title: "", carePlanUUID: nil, schedule: .init(composing: [.init(start: Date(), end: nil, interval: .init(day: 1))]))
            return try Task.copyCareKit(task)
        }
    }
    
    func orderedArray() -> [PCKStoreClass]{
        return [.patient, .carePlan, .contact, .task, .outcome]
    }
    
    func replaceRemoteConcreteClasses(_ newClasses: [PCKStoreClass: PCKSynchronizable])throws -> [PCKStoreClass: PCKSynchronizable] {
        var updatedClasses = try getConcrete()

        for (key,value) in newClasses{
            if isCorrectType(key, check: value){
                updatedClasses[key] = value
            }else{
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.pullRevisions.debug("PCKStoreClass.replaceRemoteConcreteClasses(). Discarding class for `\(key.rawValue)` because it's of the wrong type. All classes need to subclass a PCK concrete type. If you are trying to map a class to a OCKStore concreate type, pass it to `customClasses` instead. This class isn't compatibile.")
                } else {
                    os_log("PCKStoreClass.replaceRemoteConcreteClasses(). Discarding class for `%{public}@` because it's of the wrong type. All classes need to subclass a PCK concrete type. If you are trying to map a class to a OCKStore concreate type, pass it to `customClasses` instead. This class isn't compatibile.", log: .pullRevisions, type: .debug, key.rawValue)
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
        
        for (key,value) in concreteClasses{
            if !isCorrectType(key, check: value){
                concreteClasses.removeValue(forKey: key)
            }
        }
        
        //Ensure all default classes are created
        guard concreteClasses.count == orderedArray().count else{
            throw ParseCareKitError.couldntCreateConcreteClasses
        }
        
        return concreteClasses
    }
    
    func replaceConcreteClasses(_ newClasses: [PCKStoreClass: PCKSynchronizable]) throws -> [PCKStoreClass: PCKSynchronizable] {
        var updatedClasses = try getConcrete()

        for (key,value) in newClasses{
            if isCorrectType(key, check: value){
                updatedClasses[key] = value
            }else{
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.pullRevisions.debug("PCKStoreClass.replaceConcreteClasses(). Discarding class for `\(key.rawValue)` because it's of the wrong type. All classes need to subclass a PCK concrete type. If you are trying to map a class to a OCKStore concreate type, pass it to `customClasses` instead. This class isn't compatibile.")
                } else {
                    os_log("PCKStoreClass.replaceConcreteClasses(). Discarding class for `%{public}@` because it's of the wrong type. All classes need to subclass a PCK concrete type. If you are trying to map a class to a OCKStore concreate type, pass it to `customClasses` instead. This class isn't compatibile -> %{public}@.", log: .pullRevisions, type: .debug, key.rawValue)
                }
            }
        }
        return updatedClasses
    }
    
    func isCorrectType(_ type: PCKStoreClass, check: PCKSynchronizable) -> Bool{
        switch type {
        case .carePlan:
            guard let _ = check as? CarePlan else{
                return false
            }
            return true
        case .contact:
            guard let _ = check as? Contact else{
                return false
            }
            return true
        case .outcome:
            guard let _ = check as? Outcome else{
                return false
            }
            return true
        case .patient:
            guard let _ = check as? Patient else{
                return false
            }
            return true
        case .task:
            guard let _ = check as? Task else{
                return false
            }
            return true
        }
    }
}

public let kPCKCustomClassKey                                       = "customClass"

//#Mark - Parse Database Keys

public let kPCKParseObjectIdKey                                     = "objectId"
public let kPCKParseCreatedAtKey                                    = "createdAt"
public let kPCKParseUpdatedAtKey                                    = "updatedAt"

public let kPCKObjectableUUIDKey                                        = "uuid"
public let kPCKObjectableEntityIdKey                                    = "entityId"
public let kPCKObjectableAssetKey                                       = "asset"
public let kPCKObjectableGroupIdentifierKey                             = "groupIdentifier"
public let kPCKObjectableNotesKey                                       = "notes"
public let kPCKObjectableTimezoneKey                                    = "timezone"
public let kPCKObjectableClockKey                                       = "logicalClock"
public let kPCKObjectableCreatedDateKey                                 = "createdDate"
public let kPCKObjectableUpdatedDateKey                                 = "updatedDate"
public let kPCKObjectableTagsKey                                        = "tags"
public let kPCKObjectableUserInfoKey                                    = "userInfo"
public let kPCKObjectableSourceKey                                      = "source"
public let kPCKObjectableDeletedDateKey                                 = "deletedDate"
public let kPCKObjectableRemoteIDKey                                    = "remoteID"

public let kPCKVersionedObjectEffectiveDateKey                      = "effectiveDate"

public let kPCKVersionedObjectNextKey                               = "next"
public let kPCKVersionedObjectPreviousKey                           = "previous"

//#Mark - Patient Class
public let kPCKPatientClassKey                                 = "Patient"

// Field keys
public let kPCKPatientAllergiesKey                                  = "alergies"
public let kPCKPatientBirthdayKey                                   = "birthday"
public let kPCKPatientSexKey                                        = "sex"
public let kPCKPatientNameKey                                       = "name"

//#Mark - CarePlan Class
public let kPCKCarePlanClassKey                                = "CarePlan"

// Field keys
public let kPCKCarePlanPatientKey                                 = "patient"
public let kPCKCarePlanTitleKey                                   = "title"

//#Mark - Contact Class
public let kPCKContactClassKey                                 = "Contact"

// Field keys
public let kPCKContactCarePlanKey                                 = "carePlan"
public let kPCKContactTitleKey                                    = "title"
public let kPCKContactRoleKey                                     = "role"
public let kPCKContactOrganizationKey                             = "organization"
public let kPCKContactCategoryKey                                 = "category"
public let kPCKContactNameKey                                     = "name"
public let kPCKContactAddressKey                                  = "address"
public let kPCKContactEmailAddressesKey                           = "emailAddressesDictionary"
public let kPCKContactPhoneNumbersKey                             = "phoneNumbersDictionary"
public let kPCKContactMessagingNumbersKey                         = "messagingNumbersDictionary"
public let kPCKContactOtherContactInfoKey                         = "otherContactInfoDictionary"


//#Mark - Task Class
public let kPCKTaskClassKey                                    = "Task"

// Field keys
public let kPCKTaskTitleKey                                       = "title"
public let kPCKTaskCarePlanKey                                    = "carePlan"
public let kPCKTaskImpactsAdherenceKey                         = "impactsAdherence"
public let kPCKTaskInstructionsKey                             = "instructions"
public let kPCKTaskElementsKey                                 = "elements"

//#Mark - Schedule Element Class
public let kAScheduleElementClassKey                           = "ScheduleElement"
// Field keys
public let kPCKScheduleElementTextKey                             = "text"
public let kPCKScheduleElementStartKey                            = "start"
public let kPCKScheduleElementEndKey                              = "end"
public let kPCKScheduleElementIntervalKey                         = "interval"
public let kPCKScheduleElementTargetValuesKey                     = "targetValues"
public let kPCKScheduleElementElementsKey                         = "elements"

//#Mark - Outcome Class
public let kPCKOutcomeClassKey                                    = "Outcome"

// Field keys
public let kPCKOutcomeTaskKey                                     = "task"
public let kPCKOutcomeTaskOccurrenceIndexKey                   = "taskOccurrenceIndex"
public let kPCKOutcomeValuesKey                                = "values"


//#Mark - OutcomeValue Class
public let kPCKOutcomeValueClassKey                            = "OutcomeValue"

// Field keys
public let kPCKOutcomeValueIndexKey                               = "index"
public let kPCKOutcomeValueKindKey                             = "kind"
public let kPCKOutcomeValueUnitsKey                            = "units"
public let kPCKOutcomeValueValueKey                            = "textValue"
public let kPCKOutcomeValueBinaryValueKey                            = "binaryValue"
public let kPCKOutcomeValueBooleanValueKey                            = "booleanValue"
public let kPCKOutcomeValueIntegerValueKey                            = "integerValue"
public let kPCKOutcomeValueDoubleValueKey                            = "doubleValue"
public let kPCKOutcomeValueDateValueKey                            = "dateValue"


//#Mark - Note Class
public let kPCKNoteClassKey                                    = "Note"
// Field keys
public let kPCKNoteContentKey                                  = "content"
public let kPCKNoteTitleKey                                    = "title"
public let kPCKNoteAuthorKey                                   = "author"

//#Mark - Clock Class
public let kPCKClockClassKey                         = "Clock"
// Field keys
public let kPCKClockPatientTypeUUIDKey               = "uuid"
public let kPCKClockVectorKey                        = "vector"


//#Mark - CareKit UserInfo Database Keys

//Outcome Class (keep this as Outcome has had issues querying multiple times)
public let kPCKOutcomUserInfoIDKey              = "entityId"

//OutcomeValue Class
public let kPCKOutcomeValueUserInfoUUIDKey              = "uuid"
public let kPCKOutcomeValueUserInfoRelatedOutcomeIDKey = "relatedOutcomeID"

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier!
    
    static let carePlan = OSLog(subsystem: subsystem, category: "carePlan")
    static let contact = OSLog(subsystem: subsystem, category: "carePlan")
    static let patient = OSLog(subsystem: subsystem, category: "patient")
    static let task = OSLog(subsystem: subsystem, category: "task")
    static let outcome = OSLog(subsystem: subsystem, category: "outcome")
    static let versionable = OSLog(subsystem: subsystem, category: "versionable")
    static let objectable = OSLog(subsystem: subsystem, category: "objectable")
    static let pullRevisions = OSLog(subsystem: subsystem, category: "pullRevisions")
    static let pushRevisions = OSLog(subsystem: subsystem, category: "pushRevisions")
    static let clock = OSLog(subsystem: subsystem, category: "clock")
}

@available(iOS 14.0, watchOS 7.0, *)
extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!
    
    static let carePlan = Logger(subsystem: subsystem, category: "carePlan")
    static let contact = Logger(subsystem: subsystem, category: "carePlan")
    static let patient = Logger(subsystem: subsystem, category: "patient")
    static let task = Logger(subsystem: subsystem, category: "task")
    static let outcome = Logger(subsystem: subsystem, category: "outcome")
    static let versionable = Logger(subsystem: subsystem, category: "versionable")
    static let objectable = Logger(subsystem: subsystem, category: "objectable")
    static let pullRevisions = Logger(subsystem: subsystem, category: "pullRevisions")
    static let pushRevisions = Logger(subsystem: subsystem, category: "pushRevisions")
    static let clock = Logger(subsystem: subsystem, category: "clock")
}
