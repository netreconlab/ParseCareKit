//
//  PCKRoleable.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/30/22.
//  Copyright © 2022 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift

/**
 Objects that conform to the `PCKRoleable` protocol are `ParseRole`'s .
*/
public protocol PCKRoleable: ParseRole {

    /// The default string to be appended to the `name`.
    /// It is expected for each `ParseRole` to implement it's own `appendString`.
    static var appendString: String { get }

    /// The owner of this `ParseRole`.
    var owner: RoleUser? { get set }
}

public extension PCKRoleable {

    static var appendString: String {
        "_user"
    }

    /**
     Creates a name for the role by using appending `appendString` to the `objectId`.
     - parameter owner: The owner of the `ParseRole`.
     - returns: The concatenated `objectId` and `appendString`.
     - throws: An `Error` if the `owner` is missing the `objectId`.
     */
    static func roleName(owner: RoleUser?) throws -> String {
        guard var ownerObjectId = owner?.objectId else {
            throw ParseCareKitError.errorString("Owner doesn't have an objectId")
        }
        ownerObjectId.append(Self.appendString)
        return ownerObjectId
    }

    /**
     Creates a new private `ParseRole` with the owner having read/write permission.
     - parameter with: The owner of the `ParseRole`.
     - returns: The new `ParseRole`.
     - throws: An `Error` if the `ParseRole` cannot be created.
     */
    static func create(with owner: RoleUser) throws -> Self {
        var ownerACL = ParseACL()
        ownerACL.publicRead = false
        ownerACL.publicWrite = false
        ownerACL.setWriteAccess(user: owner, value: true)
        ownerACL.setReadAccess(user: owner, value: true)
        let roleName = try Self.roleName(owner: owner)
        var newRole = try Self(name: roleName, acl: ownerACL)
        newRole.owner = owner
        return newRole
    }

    func merge(with object: Self) throws -> Self {
        var updated = try mergeParse(with: object)
        if updated.shouldRestoreKey(\.owner,
                                     original: object) {
            updated.owner = object.owner
        }
        return updated
    }
}
