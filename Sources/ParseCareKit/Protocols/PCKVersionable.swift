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
public protocol PCKVersionable: PCKObjectable, PCKSynchronizable {
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
        self.previousVersionUUIDs = other.previousVersionUUIDs
        self.nextVersionUUIDs = other.nextVersionUUIDs
        self.copyCommonValues(from: other)
    }

    /**
     Link the ParseCareKit versions of related objects. Fixes the link list between objects if they are broken.
     - Parameters:
        - versionFixed: An object that has been,
        - backwards: The direction in which the link list is being traversed. `true` is backwards, `false` is forwards.
    */
    func fixVersionLinkedList(_ versionFixed: Self, backwards: Bool) {

        guard let versionFixedUUID = versionFixed.uuid else {
            if #available(iOS 14.0, watchOS 7.0, *) {
                Logger.versionable.debug("Couldn't unwrap versionFixed.uuid")
            } else {
                os_log("Couldn't unwrap versionFixed.uuid",
                       log: .versionable, type: .debug)
            }
            return
        }

        if backwards {
            if let previousVersionUUID = versionFixed.previousVersionUUIDs?.last {
                Self.first(previousVersionUUID) { result in

                    switch result {

                    case .success(var previousFound):

                        if let previousNextVersionUUIDs = previousFound.nextVersionUUIDs,
                            !previousNextVersionUUIDs.contains(versionFixedUUID) {
                            previousFound.nextVersionUUIDs?.append(versionFixedUUID)
                            previousFound.save(callbackQueue: ParseRemote.queue) { results in
                                switch results {

                                case .success:
                                    self.fixVersionLinkedList(previousFound, backwards: backwards)
                                case .failure(let error):
                                    if #available(iOS 14.0, watchOS 7.0, *) {
                                        Logger.versionable.error("Couldn't save in fixVersionLinkedList(),  \(error.localizedDescription, privacy: .private). Object: \(versionFixed, privacy: .private)")
                                    } else {
                                        os_log("Couldn't save in fixVersionLinkedList(). Error: %{private}@. Object: %{private}@",
                                               log: .versionable, type: .error,
                                               error.localizedDescription, versionFixed.description)
                                    }
                                }
                            }
                        }

                    case .failure:
                        return
                    }
                }
            }
            // We are done fixing
        } else {
            if let nextVersionUUID = versionFixed.nextVersionUUIDs?.first {
                Self.first(nextVersionUUID) { result in

                    switch result {

                    case .success(var nextFound):
                        if let nextPreviousUUIDs = nextFound.previousVersionUUIDs, !nextPreviousUUIDs.contains(versionFixedUUID) {
                            nextFound.previousVersionUUIDs?.append(versionFixedUUID)
                            nextFound.save(callbackQueue: ParseRemote.queue) { results in

                                switch results {

                                case .success:
                                    self.fixVersionLinkedList(nextFound, backwards: backwards)
                                case .failure(let error):
                                    if #available(iOS 14.0, watchOS 7.0, *) {
                                        Logger.versionable.error("Couldn't save in fixVersionLinkedList(),  \(error.localizedDescription, privacy: .private). Object: \(versionFixed, privacy: .private)")
                                    } else {
                                        os_log("Couldn't save in fixVersionLinkedList(), %{private}@. Object: %{private}@",
                                               log: .versionable, type: .error,
                                               error.localizedDescription, versionFixed.description)
                                    }
                                }
                            }
                        }

                    case .failure:
                        return
                    }
                }
            }
            // We are done fixing
        }
    }

    /**
     Saves a `PCKVersionable` object.
     - Parameters:
        - options: A set of header options sent to the server. Defaults to an empty set.
        - completion: The block to execute.
     It should have the following argument signature: `(Result<PCKSynchronizable,Error>)`.
    */
    public func save(options: API.Options = [],
                     completion: @escaping(Result<PCKSynchronizable, Error>) -> Void) {
        self.create(options: options,
                    callbackQueue: ParseRemote.queue) { results in
            switch results {

            case .success(let savedObject):
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.versionable.debug("Successfully added to cloud: \(savedObject, privacy: .private)")
                } else {
                    os_log("Successfully added to cloud: %{private}@",
                           log: .versionable, type: .debug, savedObject.description)
                }

                guard let uuid = self.uuid else {
                    completion(.failure(ParseCareKitError.couldntUnwrapRequiredField))
                    return
                }

                // Fix versioning doubly linked list if it's broken in the cloud
                if let previousVersionUUID = savedObject.previousVersionUUIDs?.last {
                    Self.first(previousVersionUUID) { result in
                        if case var .success(previousObject) = result {
                            if let previousNextVersionUUIDs = previousObject.nextVersionUUIDs,
                                !previousNextVersionUUIDs.contains(uuid) {
                                previousObject.nextVersionUUIDs?.append(uuid)
                                previousObject.save(callbackQueue: ParseRemote.queue) { results in
                                    switch results {

                                    case .success:
                                        self.fixVersionLinkedList(previousObject, backwards: true)
                                    case .failure(let error):
                                        if #available(iOS 14.0, watchOS 7.0, *) {
                                            Logger.versionable.error("Couldn't save(), \(error.localizedDescription, privacy: .private). Object: \(self, privacy: .private)")
                                        } else {
                                            os_log("Couldn't save(), %{private}@. Object: %{private}@",
                                                   log: .versionable, type: .error,
                                                   error.localizedDescription, self.description)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if let nextVersionUUID = savedObject.nextVersionUUIDs?.first {
                    Self.first(nextVersionUUID) { result in
                        if case var .success(nextObject) = result {
                            if let nextPreviousVersionUUIDs = nextObject.previousVersionUUIDs,
                                !nextPreviousVersionUUIDs.contains(uuid) {
                                nextObject.previousVersionUUIDs?.append(uuid)
                                nextObject.save(callbackQueue: ParseRemote.queue) { results in
                                    switch results {

                                    case .success:
                                        self.fixVersionLinkedList(nextObject, backwards: false)
                                    case .failure(let error):
                                        if #available(iOS 14.0, watchOS 7.0, *) {
                                            Logger.versionable.error("Couldn't save(), \(error.localizedDescription, privacy: .private). Object: \(self, privacy: .private)")
                                        } else {
                                            os_log("Couldn't save(), %{private}@. Object: %{private}@",
                                                   log: .versionable, type: .error,
                                                   error.localizedDescription, self.description)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                completion(.success(savedObject))

            case .failure(let error):
                guard error.code == .duplicateValue else {
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.versionable.error("\(self.className, privacy: .private).save(), \(error.localizedDescription, privacy: .private). Object: \(self, privacy: .private)")
                    } else {
                        os_log("%{private}@.save(), %{private}@. Object: %{private}@",
                               log: .versionable, type: .error, self.className,
                               error.localizedDescription, self.description)
                    }
                    completion(.failure(error))
                    return
                }
                completion(.success(self))
            }
        }
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
        try container.encodeIfPresent(previousVersionUUIDs, forKey: .previousVersionUUIDs)
        try container.encodeIfPresent(nextVersionUUIDs, forKey: .nextVersionUUIDs)
        try container.encodeIfPresent(effectiveDate, forKey: .effectiveDate)
        try encodeObjectable(to: encoder)
    }
} // swiftlint:disable:this file_length
