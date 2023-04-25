//
//  ParseCareKitError.swift
//  ParseCareKit
//
//  Created by Corey Baker on 12/12/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation

enum ParseCareKitError: Error {
    case userNotLoggedIn
    case relatedEntityNotOnRemote
    case requiredValueCantBeUnwrapped
    case objectIdDoesntMatchRemoteId
    case objectNotFoundOnParseServer
    case remoteClockLargerThanLocal
    case couldntUnwrapClock
    case couldntUnwrapRequiredField
    case couldntUnwrapSelf
    case remoteVersionNewerThanLocal
    case uuidAlreadyExists
    case cantCastToNeededClassType
    case cantEncodeACL
    case classTypeNotAnEligibleType
    case couldntCreateConcreteClasses
    case syncAlreadyInProgress
    case parseHealthError
    case errorString(_ string: String)
}

extension ParseCareKitError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .userNotLoggedIn:
            return NSLocalizedString("ParseCareKit: Parse User is not logged in.", comment: "Login error")
        case .relatedEntityNotOnRemote:
            return NSLocalizedString("ParseCareKit: Related entity is not on remote.", comment: "Related entity error")
        case .requiredValueCantBeUnwrapped:
            return NSLocalizedString("ParseCareKit: Required value can't be unwrapped.", comment: "Unwrapping error")
        case .couldntUnwrapClock:
            return NSLocalizedString("ParseCareKit: Clock can't be unwrapped.", comment: "Clock Unwrapping error")
        case .couldntUnwrapRequiredField:
            return NSLocalizedString("ParseCareKit: Could not unwrap required field.",
                                     comment: "Could not unwrap required field")
        case .objectIdDoesntMatchRemoteId:
            return NSLocalizedString("ParseCareKit: remoteId and objectId don't match.",
                                     comment: "Remote/Local mismatch error")
        case .remoteClockLargerThanLocal:
            return NSLocalizedString("Remote clock larger than local during pushRevisions, not pushing",
                                     comment: "Knowledge vector larger on Remote")
        case .couldntUnwrapSelf:
            return NSLocalizedString("Cannot unwrap self. This class has already been deallocated",
                                     comment: "Cannot unwrap self, class deallocated")
        case .remoteVersionNewerThanLocal:
            return NSLocalizedString("Cannot sync, the Remote version newer than local version",
                                     comment: "Remote version newer than local version")
        case .uuidAlreadyExists:
            return NSLocalizedString("Cannot sync, the uuid already exists on the Remote",
                                     comment: "UUID is not unique")
        case .cantCastToNeededClassType:
            return NSLocalizedString("Cannot cast to needed class type",
                                     comment: "Cannot cast to needed class type")
        case .cantEncodeACL:
            return NSLocalizedString("Cannot encode ACL",
                                     comment: "Cannot encode ACL")
        case .classTypeNotAnEligibleType:
            return NSLocalizedString("PCKClass type is not an eligible type",
                                     comment: "PCKClass type is not an eligible type")
        case .couldntCreateConcreteClasses:
            return NSLocalizedString("Could not create concrete classes",
                                     comment: "Could not create concrete classes")
        case .objectNotFoundOnParseServer:
            return NSLocalizedString("Object couldn't be found on the Parse Server",
                                     comment: "Object couldn't be found on the Parse Server")
        case .syncAlreadyInProgress:
            return NSLocalizedString("Sync already in progress!", comment: "Sync already in progress!")
        case .parseHealthError:
            return NSLocalizedString("There was a problem with the health of the remote!",
                                     comment: "There was a problem with the health of the remote!")
        case .errorString(let string): return string
        }
    }
}
