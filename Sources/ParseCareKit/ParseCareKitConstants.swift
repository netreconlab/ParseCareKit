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

public enum ParseCareKitConstants {
    static let defaultACL = "edu.netreconlab.ParseCareKit_defaultACL"
    static let acl = "_acl"
    static let administratorRole = "Administrators"
}

// MARK: Custom Enums
let queryLimit = 1000
enum CustomKey {
    static let className                                  = "className"
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
    /// name key for ParseRole.
    public static let name = "name"
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
    /// clock key.
    public static let clock                                      = "clock"
    /// clockUUID key.
    public static let clockUUID                                  = "clockUUID"
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

// MARK: RevisionRecord Class
/// Keys for `RevisionRecord` objects. These keys can be used for querying Parse objects.
enum RevisionRecordKey {
    /// className key.
    static let className                                       = "RevisionRecord"
    /// clockUUID key.
    static let clockUUID                                       = "clockUUID"
    /// logicalClock key.
    static let logicalClock                                    = "logicalClock"
}
