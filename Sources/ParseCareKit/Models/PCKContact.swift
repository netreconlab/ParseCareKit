//
//  PCKContact.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore
import os.log

// swiftlint:disable cyclomatic_complexity
// swiftlint:disable line_length
// swiftlint:disable function_body_length
// swiftlint:disable type_body_length

/// An `PCKContact` is the ParseCareKit equivalent of `OCKContact`.  An `OCKContact`represents a contact that a user
/// may want to get in touch with. A contact may be a care provider, a friend, or a family member. Contacts must have at
/// least a name, and may optionally have numerous other addresses at which to be contacted.
public struct PCKContact: PCKVersionable {

    public var previousVersionUUIDs: [UUID]? {
        willSet {
            guard let newValue = newValue else {
                previousVersions = nil
                return
            }
            var newPreviousVersions = [Pointer<Self>]()
            newValue.forEach { newPreviousVersions.append(Pointer<Self>(objectId: $0.uuidString)) }
            previousVersions = newPreviousVersions
        }
    }

    public var nextVersionUUIDs: [UUID]? {
        willSet {
            guard let newValue = newValue else {
                nextVersions = nil
                return
            }
            var newNextVersions = [Pointer<Self>]()
            newValue.forEach { newNextVersions.append(Pointer<Self>(objectId: $0.uuidString)) }
            nextVersions = newNextVersions
        }
    }

    public var previousVersions: [Pointer<Self>]?

    public var nextVersions: [Pointer<Self>]?

    public var effectiveDate: Date?

    public var entityId: String?

    public var logicalClock: Int?

    public var clock: PCKClock?

    public var schemaVersion: OCKSemanticVersion?

    public var createdDate: Date?

    public var updatedDate: Date?

    public var deletedDate: Date?

    public var timezone: TimeZone?

    public var userInfo: [String: String]?

    public var groupIdentifier: String?

    public var tags: [String]?

    public var source: String?

    public var asset: String?

    public var notes: [OCKNote]?

    public var remoteID: String?

    public var encodingForParse: Bool = true {
        willSet {
            prepareEncodingRelational(newValue)
        }
    }

    public static var className: String {
        "Contact"
    }

    public var objectId: String?

    public var createdAt: Date?

    public var updatedAt: Date?

    public var ACL: ParseACL?

    public var originalData: Data?

    /// The contact's postal address.
    public var address: OCKPostalAddress?

    /// Indicates if this contact is care provider or if they are a friend or family member.
    public var category: OCKContactCategory?

    /// The contact's name.
    public var name: PersonNameComponents?

    /// The organization this contact belongs to.
    public var organization: String?

    /// A description of what this contact's role is.
    public var role: String?

    /// A title for this contact.
    public var title: String?

    /// The version in the local database for the care plan associated with this contact.
    public var carePlan: PCKCarePlan? {
        didSet {
            carePlanUUID = carePlan?.uuid
        }
    }

    /// The version id in the local database for the care plan associated with this contact.
    public var carePlanUUID: UUID? {
        didSet {
            if carePlanUUID != carePlan?.uuid {
                carePlan = nil
            }
        }
    }

    /// An array of numbers that the contact can be messaged at.
    /// The number strings may contains non-numeric characters.
    public var messagingNumbers: [OCKLabeledValue]?

    /// An array of the contact's email addresses.
    public var emailAddresses: [OCKLabeledValue]?

    /// An array of the contact's phone numbers.
    /// The number strings may contains non-numeric characters.
    public var phoneNumbers: [OCKLabeledValue]?

    /// An array of other information that could be used reach this contact.
    public var otherContactInfo: [OCKLabeledValue]?

    enum CodingKeys: String, CodingKey {
        case objectId, createdAt, updatedAt
        case entityId, schemaVersion, createdDate, updatedDate, deletedDate,
             timezone, userInfo, groupIdentifier, tags, source, asset, remoteID,
             notes, logicalClock
        case previousVersionUUIDs, nextVersionUUIDs, effectiveDate
        case carePlan, title, carePlanUUID, address, category, name, organization, role
        case emailAddresses, messagingNumbers, phoneNumbers, otherContactInfo
    }

    public init() {
        ACL = PCKUtility.getDefaultACL()
    }

    public static func new(with careKitEntity: OCKEntity) throws -> PCKContact {

        switch careKitEntity {
        case .contact(let entity):
            return try Self.copyCareKit(entity)
        default:
            Logger.contact.error("new(with:) The wrong type (\(careKitEntity.entityType, privacy: .private)) of entity was passed as an argument.")
            throw ParseCareKitError.classTypeNotAnEligibleType
        }
    }

    public static func copyValues(from other: PCKContact, to here: PCKContact) throws -> Self {
        var here = here
        here.copyVersionedValues(from: other)
        here.previousVersionUUIDs = other.previousVersionUUIDs
        here.nextVersionUUIDs = other.nextVersionUUIDs
        here.address = other.address
        here.category = other.category
        here.title = other.title
        here.name = other.name
        here.organization = other.organization
        here.role = other.role
        here.carePlan = other.carePlan
        return here
    }

    public static func copyCareKit(_ contactAny: OCKAnyContact) throws -> PCKContact {

        guard let contact = contactAny as? OCKContact else {
            throw ParseCareKitError.cantCastToNeededClassType
        }
        let encoded = try PCKUtility.jsonEncoder().encode(contact)
        var decoded = try PCKUtility.decoder().decode(Self.self, from: encoded)
        decoded.objectId = contact.uuid.uuidString
        decoded.entityId = contact.id
        decoded.carePlan = PCKCarePlan(uuid: contact.carePlanUUID)
        decoded.previousVersions = contact.previousVersionUUIDs.map { Pointer<Self>(objectId: $0.uuidString) }
        decoded.nextVersions = contact.nextVersionUUIDs.map { Pointer<Self>(objectId: $0.uuidString) }
        if let acl = contact.acl {
            decoded.ACL = acl
        } else {
            decoded.ACL = PCKUtility.getDefaultACL()
        }
        return decoded
    }

    mutating func prepareEncodingRelational(_ encodingForParse: Bool) {
        if carePlan != nil {
            carePlan?.encodingForParse = encodingForParse
        }
    }

    public func convertToCareKit() throws -> OCKContact {
        var mutableContact = self
        mutableContact.encodingForParse = false
        let encoded = try PCKUtility.jsonEncoder().encode(mutableContact)
        return try PCKUtility.decoder().decode(OCKContact.self, from: encoded)
    }
}

extension PCKContact {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if encodingForParse {
            try container.encodeIfPresent(carePlan?.toPointer(), forKey: .carePlan)
        }

        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(carePlanUUID, forKey: .carePlanUUID)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(organization, forKey: .organization)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(emailAddresses, forKey: .emailAddresses)
        try container.encodeIfPresent(messagingNumbers, forKey: .messagingNumbers)
        try container.encodeIfPresent(phoneNumbers, forKey: .phoneNumbers)
        try container.encodeIfPresent(otherContactInfo, forKey: .otherContactInfo)
        try encodeVersionable(to: encoder)
    }
} // swiftlint:disable:this file_length
