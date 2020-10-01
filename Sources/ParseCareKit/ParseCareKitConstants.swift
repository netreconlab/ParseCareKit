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

public enum PCKCodingKeys: String, CodingKey { // swiftlint:disable:this nesting
    case entityId, id
    case uuid, schemaVersion, createdDate, updatedDate, deletedDate, timezone, userInfo, groupIdentifier, tags, source, asset, remoteID, notes, logicalClock, className, ACL
    case nextVersion, previousVersion, effectiveDate, previousVersionUUID, nextVersionUUID
}


enum ParseCareKitError: Error {
    case userNotLoggedIn
    case relatedEntityNotInCloud
    case requiredValueCantBeUnwrapped
    case objectIdDoesntMatchRemoteId
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
        }
    }
}

public enum PCKStoreClass {
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
    /*
    func getRemoteConcrete() -> [PCKStoreClass: PCKSynchronizable]? {
        var remoteClasses = [PCKStoreClass: PCKSynchronizable]()
        
        guard let regularClasses = getConcrete() else{return nil}
        
        for (key,value) in regularClasses{
            guard let remoteClass = value as? PCKSynchronizable else{
                continue
            }
            remoteClasses[key] = remoteClass
        }
        
        //Ensure all default classes are created
        guard remoteClasses.count == orderedArray().count else{
            return nil
        }
        
        return remoteClasses
    }*/
    
    func replaceRemoteConcreteClasses(_ newClasses: [PCKStoreClass: PCKSynchronizable])throws -> [PCKStoreClass: PCKSynchronizable] {
        var updatedClasses = try getConcrete()

        for (key,value) in newClasses{
            if isCorrectType(key, check: value){
                updatedClasses[key] = value
            }else{
                print("**** Warning in PCKStoreClass.replaceRemoteConcreteClasses(). Discarding class for `\(key)` because it's of the wrong type. All classes need to subclass a PCK concrete type. If you are trying to map a class to a OCKStore concreate type, pass it to `customClasses` instead. This class isn't compatibile -> \(value)")
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
                print("**** Warning in PCKStoreClass.replaceConcreteClasses(). Discarding class for `\(key)` because it's of the wrong type. All classes need to subclass a PCK concrete type. If you are trying to map a class to a OCKStore concreate type, pass it to `customClasses` instead. This class isn't compatibile -> \(value)")
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

//#Mark - Custom Enums
public enum CareKitPersonNameComponents:String{
 
    case familyName = "familyName"
    case givenName = "givenName"
    case middleName = "middleName"
    case namePrefix = "namePrefix"
    case nameSuffix = "nameSuffix"
    case nickname = "nickname"
    
    public func convertToDictionary(_ components: PersonNameComponents) -> [String:String]{
        
        var returnDictionary = [String:String]()
        
        if let name = components.familyName{
            returnDictionary[CareKitPersonNameComponents.familyName.rawValue] = name
        }
        
        if let name = components.givenName{
            returnDictionary[CareKitPersonNameComponents.givenName.rawValue] = name
        }
        
        if let name = components.middleName{
            returnDictionary[CareKitPersonNameComponents.middleName.rawValue] = name
        }
        
        if let name = components.namePrefix{
            returnDictionary[CareKitPersonNameComponents.namePrefix.rawValue] = name
        }
        
        if let name = components.nameSuffix{
            returnDictionary[CareKitPersonNameComponents.nameSuffix.rawValue] = name
        }
        
        if let name = components.nickname{
            returnDictionary[CareKitPersonNameComponents.nickname.rawValue] = name
        }
        
        return returnDictionary
    }
    
    public func convertToPersonNameComponents(_ dictionary: [String:String])->PersonNameComponents{
     
        var components = PersonNameComponents()
        
        for (key,value) in dictionary{
            
            guard let componentType = CareKitPersonNameComponents(rawValue: key) else{
                continue
            }
            
            switch componentType {
            case .familyName:
                components.familyName = value
            case .givenName:
                components.givenName = value
            case .middleName:
                components.middleName = value
            case .namePrefix:
                components.namePrefix = value
            case .nameSuffix:
                components.nameSuffix = value
            case .nickname:
                components.nickname = value
            //@unknown default:
            //    continue
            }
            
        }
        return components
    }
    
}

public enum CareKitPostalAddress:String{
    /** multi-street address is delimited with carriage returns “\n” */
    case street = "street"
    case subLocality = "subLocality"
    case city = "city"
    case subAdministrativeArea = "subAdministrativeArea"
    case state = "state"
    case postalCode = "postalCode"
    case country = "country"
    case isoCountryCode = "isoCountryCode"
    
    public func convertToDictionary(_ address: OCKPostalAddress?) -> [String:String]?{
        
        guard let address = address else{
            return nil
        }
        
        return [
            CareKitPostalAddress.street.rawValue: address.street,
            CareKitPostalAddress.subLocality.rawValue: address.subLocality,
            CareKitPostalAddress.city.rawValue: address.city,
            CareKitPostalAddress.subAdministrativeArea.rawValue: address.subAdministrativeArea,
            CareKitPostalAddress.state.rawValue: address.state,
            CareKitPostalAddress.postalCode.rawValue: address.postalCode,
            CareKitPostalAddress.country.rawValue: address.country,
            CareKitPostalAddress.isoCountryCode.rawValue: address.isoCountryCode
        ]
    }
    
    public func convertToPostalAddress(_ dictionary:[String:String]?)->OCKPostalAddress?{
        
        guard let dictionary = dictionary else{
            return nil
        }
        
        let address = OCKPostalAddress()
        
        for (key,value) in dictionary{
            
            guard let componentType = CareKitPostalAddress(rawValue: key) else{
                continue
            }
            
            switch componentType {
            case .street:
                address.street = value
            case .subLocality:
                address.subLocality = value
            case .city:
                address.city = value
            case .subAdministrativeArea:
                address.subAdministrativeArea = value
            case .state:
                address.state = value
            case .postalCode:
                address.postalCode = value
            case .country:
                address.country = value
            case .isoCountryCode:
                address.isoCountryCode = value
            }
            
        }
        
        return address
    }
}

public enum CareKitInterval:String{
    case calendar = "calendar"
    case timeZone = "timeZone"
    case era = "era"
    case year = "year"
    case month = "month"
    case day = "day"
    case hour = "hour"
    case minute = "minute"
    case second = "second"
    case nanosecond = "nanosecond"
    case weekday = "weekday"
    case weekdayOrdinal = "weekdayOrdinal"
    case quarter = "quarter"
    case weekOfMonth = "weekOfMonth"
    case weekOfYear = "weekOfYear"
    case yearForWeekOfYear = "yearForWeekOfYear"
    
    public func convertToDictionary(_ components:DateComponents)->[String:Any]{
        
        return [
        
            CareKitInterval.calendar.rawValue: components.calendar?.identifier.hashValue as Any,
            CareKitInterval.timeZone.rawValue: components.timeZone?.abbreviation() as Any,
            CareKitInterval.era.rawValue: components.era as Any,
            CareKitInterval.year.rawValue: components.year as Any,
            CareKitInterval.month.rawValue: components.month as Any,
            CareKitInterval.day.rawValue: components.day as Any,
            CareKitInterval.hour.rawValue: components.hour as Any,
            CareKitInterval.minute.rawValue: components.minute as Any,
            CareKitInterval.second.rawValue: components.second as Any,
            CareKitInterval.nanosecond.rawValue: components.nanosecond as Any,
            CareKitInterval.weekday.rawValue: components.weekday as Any,
            CareKitInterval.weekdayOrdinal.rawValue: components.weekdayOrdinal as Any,
            CareKitInterval.quarter.rawValue: components.quarter as Any,
            CareKitInterval.weekOfMonth.rawValue: components.weekOfMonth as Any,
            CareKitInterval.weekOfYear.rawValue: components.weekOfYear as Any,
            CareKitInterval.yearForWeekOfYear.rawValue: components.yearForWeekOfYear as Any
        ]
    }
    
    public func convertToDateComponents(_ dictionary:[String:Any])->DateComponents{
        
        var calendar:Calendar? = nil
        var timeZone:TimeZone? = nil
        var era:Int? = nil
        var year:Int? = nil
        var month:Int? = nil
        var day:Int? = nil
        var hour:Int? = nil
        var minute:Int? = nil
        var second:Int? = nil
        var nanosecond:Int? = nil
        var weekday:Int? = nil
        var weekdayOrdinal:Int? = nil
        var quarter:Int? = nil
        var weekOfMonth:Int? = nil
        var weekOfYear:Int? = nil
        var yearForWeekOfYear:Int? = nil
        
        for (key,value) in dictionary{
            guard let componentsVariable = CareKitInterval(rawValue: key) else{
                continue
            }
            
            switch componentsVariable{
                
            case .calendar:
                calendar = .init(identifier: .gregorian)
            case .timeZone:
                
                guard let abbreviation = value as? String else{
                    continue
                }
                
                timeZone = TimeZone(abbreviation: abbreviation)
            case .era:
                
                guard let convertedValue = value as? Int else{
                    continue
                }
                
                era = Int(convertedValue)
            case .year:
                
                guard let convertedValue = value as? Int else{
                    continue
                }
                year = Int(convertedValue)
            case .month:
                guard let convertedValue = value as? Int else{
                    continue
                }
                month = Int(convertedValue)
            case .day:
                guard let convertedValue = value as? Int else{
                    continue
                }
                day = Int(convertedValue)
            case .hour:
                guard let convertedValue = value as? Int else{
                    continue
                }
                hour = Int(convertedValue)
            case .minute:
                guard let convertedValue = value as? Int else{
                    continue
                }
                minute = Int(convertedValue)
            case .second:
                guard let convertedValue = value as? Int else{
                    continue
                }
                second = Int(convertedValue)
            case .nanosecond:
                guard let convertedValue = value as? Int else{
                    continue
                }
                nanosecond = Int(convertedValue)
            case .weekday:
                guard let convertedValue = value as? Int else{
                    continue
                }
                weekday = Int(convertedValue)
            case .weekdayOrdinal:
                guard let convertedValue = value as? Int else{
                    continue
                }
                weekdayOrdinal = Int(convertedValue)
            case .quarter:
                guard let convertedValue = value as? Int else{
                    continue
                }
                quarter = Int(convertedValue)
            case .weekOfMonth:
                guard let convertedValue = value as? Int else{
                    continue
                }
                weekOfMonth = Int(convertedValue)
            case .weekOfYear:
                guard let convertedValue = value as? Int else{
                    continue
                }
                weekOfYear = Int(convertedValue)
            case .yearForWeekOfYear:
                guard let convertedValue = value as? Int else{
                    continue
                }
                yearForWeekOfYear = Int(convertedValue)
            //@unknown default:
            //    continue
            }
        }
        
        return DateComponents(calendar: calendar, timeZone: timeZone, era: era, year: year, month: month, day: day, hour: hour, minute: minute, second: second, nanosecond: nanosecond, weekday: weekday, weekdayOrdinal: weekdayOrdinal, quarter: quarter, weekOfMonth: weekOfMonth, weekOfYear: weekOfYear, yearForWeekOfYear: yearForWeekOfYear)
    }
}
