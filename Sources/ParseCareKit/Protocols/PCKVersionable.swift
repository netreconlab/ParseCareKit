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
    /// The UUID of the previous version of this object, or nil if there is no previous version.
    var previousVersionUUID: UUID? { get set }

    /// The UUID of the next version of this object, or nil if there is no next version.
    var nextVersionUUID: UUID? { get set }

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
        self.previousVersionUUID = other.previousVersionUUID
        self.nextVersionUUID = other.nextVersionUUID
        self.copyCommonValues(from: other)
    }

    /**
     Link the ParseCareKit versions of related objects. Fixex the link list between objects if they are broken.
     - Parameters:
        - versionFixed: An object that has been,
        - backwards: The direction in which the link list is being traversed. `true` is backwards, `false` is forwards.
    */
    func fixVersionLinkedList(_ versionFixed: Self, backwards: Bool) {

        if backwards {
            if versionFixed.previousVersionUUID != nil {
                Self.first(versionFixed.previousVersionUUID) { result in

                    switch result {

                    case .success(var previousFound):

                        if previousFound.nextVersionUUID == nil {
                            previousFound.nextVersionUUID = versionFixed.uuid
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
            if versionFixed.nextVersionUUID != nil {
                Self.first(versionFixed.nextVersionUUID) { result in

                    switch result {

                    case .success(var nextFound):
                        if nextFound.previousVersionUUID == nil {
                            nextFound.previousVersionUUID = versionFixed.uuid
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
        var versionedObject = self
        _ = try? versionedObject.stampRelationalEntities()
        versionedObject.save(callbackQueue: ParseRemoteSynchronizationManager.queue) { results in
            switch results {

            case .success(let savedObject):
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.versionable.debug("Successfully added to cloud: \(savedObject, privacy: .private)")
                } else {
                    os_log("Successfully added to cloud: %{private}@",
                           log: .versionable, type: .debug, savedObject.description)
                }

                //Fix versioning doubly linked list if it's broken in the cloud
                if savedObject.previousVersionUUID != nil {
                    Self.first(savedObject.previousVersionUUID!) { result in
                        if case var .success(previousObject) = result {
                            if previousObject.nextVersionUUID == nil {
                                previousObject.nextVersionUUID = versionedObject.uuid
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

                if savedObject.nextVersionUUID != nil {
                    Self.first(savedObject.nextVersionUUID!) { result in
                        if case var .success(nextObject) = result {
                            if nextObject.previousVersionUUID == nil {
                                nextObject.previousVersionUUID = savedObject.uuid
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
                    Logger.versionable.error("\(versionedObject.className, privacy: .private).save(), \(error.localizedDescription, privacy: .private). Object: \(self, privacy: .private)")
                } else {
                    os_log("%{private}@.save(), %{private}@. Object: %{private}@",
                           log: .versionable, type: .error, versionedObject.className,
                           error.localizedDescription, versionedObject.description)
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

        let query = Self.query(doesNotExist(key: VersionableKey.nextVersionUUID))

        let interval = createCurrentDateInterval(for: date)
        let greaterEqualEffectiveDate = self.query(VersionableKey.effectiveDate >= interval.end)
        return Self.query(or(queries: [query, greaterEqualEffectiveDate]))
    }
    
    func find(for date: Date) throws -> [Self] {
        try Self.query(for: date).find()
    }

    /**
     Querying versioned objects the same way queries are as CareKit. Creates a query that finds
     the newest version that hasn't been deleted.
     - Parameters:
        - for: The date the object is active.
        - returns: `Query<Self>`.
    */
    public static func query(for date: Date) -> Query<Self> {
        let query = Self.query(and(queries: [queryNotDeleted(), queryNewestVersion(for: date)]))
            .includeAll()
        return query
    }

    /**
     Fetch Versioned objects the same way as CareKit.
     - Parameters:
        - for: The date the objects are active.
        - completion: The block to execute.
     It should have the following argument signature: `(Result<[Self],ParseError>)`.
    */
    public func find(for date: Date, completion: @escaping(Result<[Self], ParseError>) -> Void) {
        let query = Self.query(for: date)
            .includeAll()
        query.find(callbackQueue: ParseRemoteSynchronizationManager.queue) { results in
            switch results {

            case .success(let entities):
                completion(.success(entities))
            case .failure(let error):
                completion(.failure(error))
            }
        }
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
        try container.encodeIfPresent(previousVersionUUID, forKey: .previousVersionUUID)
        try container.encodeIfPresent(nextVersionUUID, forKey: .nextVersionUUID)
        try container.encodeIfPresent(effectiveDate, forKey: .effectiveDate)
        try encodeObjectable(to: encoder)
    }
} // swiftlint:disable:this file_length
