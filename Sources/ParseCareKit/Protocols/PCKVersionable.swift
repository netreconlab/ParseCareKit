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
import Combine

// swiftlint:disable line_length
// swiftlint:disable cyclomatic_complexity
// swiftlint:disable function_body_length

/**
 Objects that conform to the `PCKVersionable` protocol are Parse interpretations of `OCKVersionedObjectCompatible` objects.
*/
public protocol PCKVersionable: PCKObjectable, PCKSynchronizable {
    /// The UUID of the previous version of this object, or nil if there is no previous version.
    var previousVersionUUIDs: [UUID] { get set }

    /// The UUID of the next version of this object, or nil if there is no next version.
    var nextVersionUUIDs: [UUID] { get set }

    /// The date that this version of the object begins to take precedence over the previous version.
    /// Often this will be the same as the `createdDate`, but is not required to be.
    var effectiveDate: Date? { get set }

    /// The date on which this object was marked deleted. Note that objects are never actually deleted,
    /// but rather they are marked deleted and will no longer be returned from queries.
    var deletedDate: Date? {get set}
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

        if backwards {
            if let previousVersionUUID = versionFixed.previousVersionUUIDs.last {
                Self.first(previousVersionUUID) { result in

                    switch result {

                    case .success(var previousFound):

                        if !previousFound.nextVersionUUIDs.contains(versionFixed.uuid) {
                            previousFound.nextVersionUUIDs.append(versionFixed.uuid)
                            previousFound.save(callbackQueue: ParseRemoteSynchronizationManager.queue) { results in
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
            //We are done fixing
        } else {
            if let nextVersionUUID = versionFixed.nextVersionUUIDs.first {
                Self.first(nextVersionUUID) { result in

                    switch result {

                    case .success(var nextFound):
                        if !nextFound.previousVersionUUIDs.contains(versionFixed.uuid) {
                            nextFound.previousVersionUUIDs.insert(versionFixed.uuid, at: 0)
                            nextFound.save(callbackQueue: ParseRemoteSynchronizationManager.queue) { results in

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
            //We are done fixing
        }
    }

    /**
     Saving a `PCKVersionable` object.
     - Parameters:
        - completion: The block to execute.
     It should have the following argument signature: `(Result<PCKSynchronizable,Error>)`.
    */
    public func save(completion: @escaping(Result<PCKSynchronizable, Error>) -> Void) {
        self.save(callbackQueue: ParseRemoteSynchronizationManager.queue) { results in
            switch results {

            case .success(let savedObject):
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.versionable.debug("Successfully added to cloud: \(savedObject, privacy: .private)")
                } else {
                    os_log("Successfully added to cloud: %{private}@",
                           log: .versionable, type: .debug, savedObject.description)
                }

                //Fix versioning doubly linked list if it's broken in the cloud
                if let previousVersionUUID = savedObject.previousVersionUUIDs.last {
                    Self.first(previousVersionUUID) { result in
                        if case var .success(previousObject) = result {
                            if !previousObject.nextVersionUUIDs.contains(self.uuid) {
                                previousObject.nextVersionUUIDs.append(self.uuid)
                                previousObject.save(callbackQueue: ParseRemoteSynchronizationManager.queue) { results in
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

                if let nextVersionUUID = savedObject.nextVersionUUIDs.first {
                    Self.first(nextVersionUUID) { result in
                        if case var .success(nextObject) = result {
                            if !nextObject.previousVersionUUIDs.contains(self.uuid) {
                                nextObject.previousVersionUUIDs.insert(self.uuid, at: 0)
                                nextObject.save(callbackQueue: ParseRemoteSynchronizationManager.queue) { results in
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
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.versionable.error("\(self.className, privacy: .private).save(), \(error.localizedDescription, privacy: .private). Object: \(self, privacy: .private)")
                } else {
                    os_log("%{private}@.save(), %{private}@. Object: %{private}@",
                           log: .versionable, type: .error, self.className,
                           error.localizedDescription, self.description)
                }
                completion(.failure(error))
            }
        }
    }
}

//Fetching
extension PCKVersionable {
    private static func queryNotDeleted() -> Query<Self> {
        Self.query(doesNotExist(key: VersionableKey.deletedDate))
    }

    private static func queryNewestVersion(for date: Date)-> Query<Self> {
        let interval = createCurrentDateInterval(for: date)

        let startsBeforeEndOfQuery = Self.query(VersionableKey.effectiveDate < interval.end)
        let noNextVersion = queryNoNextVersion(for: date)
        return .init(and(queries: [startsBeforeEndOfQuery, noNextVersion]))
    }

    private static func queryNoNextVersion(for date: Date)-> Query<Self> {

        let query = Self.query(doesNotExist(key: VersionableKey.nextVersionUUIDs))

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
     Find versioned objects *synchronously* like `fetch` in CareKit. Finds the newest version
     that has not been deleted.
     - Parameters:
        - for: The date the objects are active.
        - options: A set of header options sent to the server. Defaults to an empty set.
        - throws: `ParseError`.
        - returns: An array of `PCKVersionable` objects fitting the description of the query.
    */
    func find(for date: Date, options: API.Options = []) throws -> [Self] {
        try Self.query(for: date).find(options: options)
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

    /**
     Find versioned objects *asynchronously* like `fetch` in CareKit. Finds the newest version
     that has not been deleted. Publishes when complete.
     - Parameters:
        - for: The date the objects are active.
        - options: A set of header options sent to the server. Defaults to an empty set.
        - returns: `Future<[Self],ParseError>`.
    */
    public func findPublisher(for date: Date,
                              options: API.Options = []) -> Future<[Self], ParseError> {
        let query = Self.query(for: date)
            .includeAll()
        return query.findPublisher(options: options)
    }
}

//Encodable
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
