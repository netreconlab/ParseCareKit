//
//  PCKVersionable.swift
//  ParseCareKit
//
//  Created by Corey Baker on 9/28/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import os.log

// swiftlint:disable line_length
// swiftlint:disable cyclomatic_complexity
// swiftlint:disable function_body_length

/**
 Objects that conform to the `PCKVersionable` protocol are Parse interpretations of `OCKVersionedObjectCompatible` objects.
*/
public protocol PCKVersionable: PCKObjectable {
    /// The UUIDs of the previous version of this object, or nil if there is no previous version.
    /// The UUIDs are in no particular order.
    var previousVersionUUIDs: [UUID]? { get set }

    /// The UUIDs of the next version of this object, or nil if there is no next version.
    /// The UUIDs are in no particular order.
    var nextVersionUUIDs: [UUID]? { get set }

    /// The previous versions of this object, or nil if there is no previous version.
    /// The versions are in no particular order.
    var previousVersions: [Pointer<Self>]? { get set }

    /// The next versions of this object, or nil if there is no next version.
    /// The versions are in no particular order.
    var nextVersions: [Pointer<Self>]? { get set }

    /// The date that this version of the object begins to take precedence over the previous version.
    /// Often this will be the same as the `createdDate`, but is not required to be.
    var effectiveDate: Date? { get set }

    /// The date on which this object was marked deleted. Note that objects are never actually deleted,
    /// but rather they are marked deleted and will no longer be returned from queries.
    var deletedDate: Date? { get set }
}

extension PCKVersionable {

    /// Copies the common values of another PCKVersionable object.
    /// - parameter from: The PCKVersionable object to copy from.
    mutating public func copyVersionedValues(from other: Self) {
        self.effectiveDate = other.effectiveDate
        self.deletedDate = other.deletedDate
        self.copyCommonValues(from: other)
    }
}

// MARK: Fetching
extension PCKVersionable {
    private static func queryNotDeleted() -> Query<Self> {
        Self.query(doesNotExist(key: VersionableKey.deletedDate))
    }

    private static func queryNewestVersion(for date: Date) -> Query<Self> {
        let interval = createCurrentDateInterval(for: date)

        let startsBeforeEndOfQuery = Self.query(VersionableKey.effectiveDate < interval.end)
        let noNextVersion = queryNoNextVersion(for: date)
        return .init(and(queries: [startsBeforeEndOfQuery, noNextVersion]))
    }

    private static func queryNoNextVersion(for date: Date) -> Query<Self> {
        // Where empty array
        let query = Self.query(VersionableKey.nextVersionUUIDs == [String]())

        let interval = createCurrentDateInterval(for: date)
        let greaterEqualEffectiveDate = self.query(VersionableKey.effectiveDate >= interval.end)
        return Self.query(or(queries: [query, greaterEqualEffectiveDate]))
    }

    /**
     Querying versioned objects just like CareKit. Creates a query that finds
     the newest version that has not been deleted. This is the query used by `find(for date: Date)`.
     Use this query to build from if you desire a more intricate query.
     - Parameters:
        - for: The date the object is active.
        - returns: `Query<Self>`.
    */
    public static func query(for date: Date) -> Query<Self> {
        .init(and(queries: [queryNotDeleted(),
                            queryNewestVersion(for: date)]))
    }

    /**
     Find versioned objects *asynchronously* like `fetch` in CareKit. Finds the newest version
     that has not been deleted.
     - Parameters:
        - for: The date the objects are active.
        - options: A set of header options sent to the server. Defaults to an empty set.
        - callbackQueue: The queue to return to after completion. Default value of `.main`.
        - completion: The block to execute.
     It should have the following argument signature: `(Result<[Self],ParseError>)`.
    */
    public func find(for date: Date,
                     options: API.Options = [],
                     callbackQueue: DispatchQueue = .main,
                     completion: @escaping(Result<[Self], ParseError>) -> Void) {
        let query = Self.query(for: date)
            .includeAll()
        query.find(options: options,
                   callbackQueue: callbackQueue,
                   completion: completion)
    }
}

// MARK: Encodable
extension PCKVersionable {

    /**
     Encodes the PCKVersionable properties of the object
     - Parameters:
        - to: the encoder the properties should be encoded to.
    */
    public func encodeVersionable(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: PCKCodingKeys.self)
        try container.encodeIfPresent(deletedDate, forKey: .deletedDate)
        try container.encodeIfPresent(effectiveDate, forKey: .effectiveDate)
        try container.encodeIfPresent(previousVersionUUIDs, forKey: .previousVersionUUIDs)
        try container.encodeIfPresent(nextVersionUUIDs, forKey: .nextVersionUUIDs)
        try container.encodeIfPresent(previousVersions, forKey: .previousVersions)
        try container.encodeIfPresent(nextVersions, forKey: .nextVersions)
        try encodeObjectable(to: encoder)
    }
} // swiftlint:disable:this file_length
