//
//  ParseCareKitConstants.swift
//  ParseCareKit
//
//  Created by Corey Baker on 4/26/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import Parse
import CareKitStore

enum ParseCareKitError: Error {
    case userNotLoggedIn
}

//#Mark - Parse Database Keys

//#Mark - Being Class
public let kPCKBeingClassKey                                 = Being.parseClassName()

// Field keys
public let kPCKBeingObjectIdKey                                    = "objectId"
public let kPCKBeingUUIDKey                                          = "uuid"
public let kPCKBeingPostedAtKey                                    = "postedAt"
public let kPCKBeingCreatedAtKey                                   = "createdAt"
public let kPCKBeingUpdatedAtKey                                     = "updatedAt"
public let kPCKBeingAllergiesKey                                     = "alergies"
public let kPCKBeingAssetKey                                         = "asset"
public let kPCKBeingBirthdayKey                                      = "birthday"
public let kPCKBeingGroupIdentifierKey                          = "groupIdentifier"
public let kPCKBeingNotesKey                                    = "notes"
public let kPCKBeingSexKey                                      = "sex"
public let kPCKBeingSourceKey                                   = "source"
public let kPCKBeingTagsKey                                     = "tags"
public let kPCKBeingTimezoneKey                                 = "timezone"
public let kPCKBeingClockKey                                    = "clock"
public let kPCKBeingEntityIdKey                                = "entityId"


//#Mark - CarePlan Class
public let kPCKCarePlanClassKey                                = "CarePlan"
// Field keys
public let kPCKCarePlanUUIDKey                                   = "uuid"
public let kPCKCarePlanObjectIdKey                                = "objectId"
public let kPCKCarePlanCreatedAtKey                               = "createdAt"
public let kPCKCarePlanUpdatedAtKey                               = "updatedAt"
public let kPCKCarePlanLocallyCreatedAtKey                        = "locallyCreatedAt"
public let kPCKCarePlanLocallyUpdatedAtKey                        = "locallyUpdatedAt"
public let kPCKCarePlanPatientKey                                 = "patient"
public let kPCKCarePlanAuthorKey                                  = "author"
public let kPCKCarePlanAuthorIdKey                                = "authorId"
public let kPCKCarePlanPatientUUIDKey                             = "patientUUID"
public let kPCKCarePlanTitleKey                                   = "title"
public let kPCKCarePlanGroupIdentifierKey                      = "groupIdentifier"
public let kPCKCarePlanNotesKey                                = "notes"
public let kPCKCarePlanSourceKey                               = "source"
public let kPCKCarePlanTagsKey                                 = "tags"
public let kPCKCarePlanClockKey                                    = "clock"
public let kPCKCarePlanEntityIdKey                                = "entityId"

//#Mark - Task Class
public let kPCKTaskClassKey                                    = "Task"
// Field keys
public let kPCKTaskUUIDKey                                          = "uuid"
public let kPCKTaskObjectIdKey                                    = "objectId"
public let kPCKTaskTitleKey                                       = "title"
public let kPCKTaskCarePlanKey                                    = "carePlan"
public let kPCKTaskCarePlanUUIDKey                                  = "carePlanUUID"
public let kPCKTaskGroupIdentifierKey                          = "groupIdentifier"
public let kPCKTaskImpactsAdherenceKey                         = "impactsAdherence"
public let kPCKTaskInstructionsKey                             = "instructions"
public let kPCKTaskNotesKey                                    = "notes"
public let kPCKTaskSourceKey                                   = "source"
public let kPCKTaskTagsKey                                     = "tags"
public let kPCKTaskAssetKey                                    = "asset"
public let kPCKTaskTimezoneKey                                 = "timezone"
public let kPCKTaskElementsKey                                 = "elements"
public let kPCKTaskClockKey                                    = "clock"
public let kPCKTaskEntityIdKey                                = "entityId"

//#Mark - KnowledgeVector Class
public let kPCKKnowledgeVectorClassKey                         = "KnowledgeVector"
// Field keys
public let kPCKKnowledgeVectorBeingTypeUUIDKey                          = "beingTypeUUID"
public let kPCKKnowledgeVectorVectorKey                        = "vector"

//#Mark - Contact Class
public let kPCKContactClassKey                                 = "Contact"
// Field keys
public let kPCKContactUUIDKey                                       = "uuid"
public let kPCKContactObjectIdKey                                 = "objectId"
public let kPCKContactGroupIdKey                                  = "groupIdentifier"
public let kPCKContactTagsKey                                     = "tags"
public let kPCKContactSourceKey                                   = "source"
public let kPCKContactTitleKey                                    = "title"
public let kPCKContactTimezoneKey                                 = "timezone"
public let kPCKContactRoleKey                                     = "role"
public let kPCKContactOrganizationKey                             = "organization"
public let kPCKContactCategoryKey                                 = "category"
public let kPCKContactAssetKey                                    = "asset"
public let kPCKContactNameKey                                     = "name"
public let kPCKContactAuthorKey                                   = "author"
public let kPCKContactBeingKey                                     = "being"
public let kPCKContactEmailAddressesKey                           = "emailAddresses"
public let kPCKContactAddressKey                                  = "address"
public let kPCKContactNotesKey                                    = "notes"
public let kPCKContactCarePlanKey                                 = "carePlan"
public let kPCKContactCarePlanUUIDKey                               = "carePlanUUID"
public let kPCKContactPhoneNumbersKey                             = "phoneNumbers"
public let kPCKContactMessagingNumbersKey                         = "messagingNumbers"
public let kPCKContactOtherContactInfoKey                         = "otherContactInfo"
public let kPCKContactLocallyCreatedAtKey                         = "locallyCreatedAt"
public let kPCKContactLocallyUpdatedAtKey                         = "locallyUpdatedAt"
public let kPCKContactClockKey                                    = "clock"
public let kPCKContactEntityIdKey                                = "entityId"

//#Mark -Outcome Class
public let kPCKOutcomeClassKey                                    = "Outcome"
// Field keys
public let kPCKOutcomeTaskKey                                     = "task"
public let kPCKOutcomeEntityIdKey                                = "entityId"
public let kPCKOutcomeObjectIdKey                                 = "objectId"
public let kPCKOutcomeAssetKey                                 = "asset"
public let kPCKOutcomeGroupIdentifierKey                       = "groupIdentifier"
public let kPCKOutcomeLocallyCreatedAtKey                      = "locallyCreatedAt"
public let kPCKOutcomeLocallyUpdatedAtKey                      = "locallyUpdatedAt"
public let kPCKOutcomeNotesKey                                 = "notes"
public let kPCKOutcomeTagsKey                                  = "tags"
public let kPCKOutcomeTaskOccurrenceIndexKey                   = "taskOccurrenceIndex"
public let kPCKOutcomeTimezoneKey                              = "timezone"
public let kPCKOutcomeSourceKey                                = "source"
public let kPCKOutcomeValuesKey                                = "values"
public let kPCKOutcomeUUIDKey                                       = "uuid"
public let kPCKOutcomeClockKey                                    = "clock"

//#Mark - OutcomeValue Class
public let kPCKOutcomeValueClassKey                            = "OutcomeValue"
// Field keys
public let kPCKOutcomeValueObjectIdKey                         = "objectId"
public let kPCKOutcomeValueCreatedAtKey                           = "createdAt"
public let kPCKOutcomeValueUpdatedAtKey                           = "updatedAt"
public let kPCKOutcomeValuePostedAtKey                            = "postedAt"
public let kPCKOutcomeValueEntityIdKey                                  = "entityId"
public let kPCKOutcomeValueUUIDKey                                  = "uuid"
public let kPCKOutcomeValueIndexKey                               = "index"
public let kPCKOutcomeValueGroupIdentifierKey                  = "groupIdentifier"
public let kPCKOutcomeValueKindKey                             = "kind"
public let kPCKOutcomeValueNotesKey                            = "notes"
public let kPCKOutcomeValueSourceKey                           = "source"
public let kPCKOutcomeValueTagsKey                             = "tags"
public let kPCKOutcomeValueTypeKey                             = "type"
public let kPCKOutcomeValueUnitsKey                            = "units"
public let kPCKOutcomeValueValueKey                            = "value"
public let kPCKOutcomeValueLocallyCreatedAtKey                    = "locallyCreatedAt"
public let kPCKOutcomeValueLocallyUpdatedAtKey                    = "locallyUpdatedAt"



//#Mark - Schedule Element Class
public let kAScheduleElementClassKey                           = "ScheduleElement"
// Field keys
public let kPCKScheduleElementObjectIdKey                         = "objectId"
public let kPCKScheduleElementTextKey                             = "text"
public let kPCKScheduleElementStartKey                            = "start"
public let kPCKScheduleElementEndKey                              = "end"
public let kPCKScheduleElementIntervalKey                         = "interval"
public let kPCKScheduleElementTargetValuesKey                     = "targetValues"
public let kPCKScheduleElementElementsKey                         = "elements"

//#Mark - Note Class
public let kPCKNoteClassKey                                    = "Note"
// Field keys
public let kPCKNoteContentKey                                  = "content"
public let kPCKNoteSourceKey                                   = "source"
public let kPCKNoteTagsKey                                     = "tags"
public let kPCKNoteAssetKey                                    = "asset"
public let kPCKNoteNotesKey                                    = "notes"
public let kPCKNoteCreatedAtKey                                = "createdAt"
public let kPCKNoteUpdatedAtKey                                = "updatedAt"
public let kPCKNoteLocallyCreatedAtKey                         = "locallyCreatedAt"
public let kPCKNoteLocallyUpdatedAtKey                         = "locallyUpdatedAt"
public let kPCKNoteLocallyTimezoneKey                          = "timezone"
public let kPCKNoteTitleKey                                    = "title"
public let kPCKNoteIdKey                                       = "uuid"

//#Mark - CareKit UserInfo Database Keys
//CarePlan Class
public let kPCKCarePlanUserInfoPatientObjectIdKey           = "patientObjectId"

//Contact Element Class
public let kPCKContactUserInfoAuthorEntityIdKey         = "authorId" //The id of the User if there is one.
public let kPCKContactUserInfoRelatedEntityIdKey          = "relatedId" //The id of the User if there is one.

//OutcomeValue Class
public let kPCKOutcomeValueUserInfoUUIDKey              = "uuid"
public let kPCKOutcomeValueUserInfoRelatedOutcomeEntityIdKey = "relatedOutcomeEntityId"

//Note Class
public let kPCKNoteUserInfoAuthorObjectIdKey                                 = "authorObjectId"


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
