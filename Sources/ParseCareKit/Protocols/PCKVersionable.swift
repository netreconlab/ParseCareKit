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

public protocol PCKVersionable: PCKObjectable, PCKSynchronizable {
    /// The UUID of the previous version of this object, or nil if there is no previous version.
    var previousVersionUUID: UUID? { get set }

    /// The previous version of this object, or nil if there is no previous version.
    var previousVersion: Self? { get set }

    /// The UUID of the next version of this object, or nil if there is no next version.
    var nextVersionUUID: UUID? { get set }

    /// The next version of this object, or nil if there is no next version.
    var nextVersion: Self? { get set }

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
        self.previousVersion = other.previousVersion
        self.nextVersion = other.nextVersion
        //Copy UUID's after
        self.previousVersionUUID = other.previousVersionUUID
        self.nextVersionUUID = other.nextVersionUUID
        self.copyCommonValues(from: other)
    }

    /**
     Link the versions of related objects.
     - Parameters:
        - completion: The block to execute.
     It should have the following argument signature: `(Result<Self,Error>)`.
    */
    func linkVersions(completion: @escaping (Result<Self, Error>) -> Void) {
        var versionedObject = self
        Self.first(versionedObject.previousVersionUUID, relatedObject: versionedObject.previousVersion) { result in

            switch result {

            case .success(let previousObject):

                versionedObject.previousVersion = previousObject

                Self.first(versionedObject.nextVersionUUID, relatedObject: versionedObject.nextVersion) { result in

                    switch result {

                    case .success(let nextObject):

                        versionedObject.nextVersion = nextObject
                        completion(.success(versionedObject))

                    case .failure:
                        completion(.success(versionedObject))
                    }
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /**
     Link the ParseCareKit versions of related objects. Fixex the link list between objects if they are broken.
     - Parameters:
        - versionFixed: An object that has been,
        - backwards: The direction in which the link list is being traversed. `true` is backwards, `false` is forwards.
    */
    func fixVersionLinkedList(_ versionFixed: Self, backwards: Bool) {
        var versionFixed = versionFixed

        if backwards {
            if versionFixed.previousVersionUUID != nil && versionFixed.previousVersion == nil {
                Self.first(versionFixed.previousVersionUUID, relatedObject: versionFixed.previousVersion) { result in

                    switch result {

                    case .success(var previousFound):

                        versionFixed.previousVersion = previousFound
                        versionFixed.save(callbackQueue: .main) { results in
                            switch results {

                            case .success:
                                if previousFound.nextVersion == nil {
                                    previousFound.nextVersion = versionFixed
                                    previousFound.save(callbackQueue: .main) { results in
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
                                } else {
                                    self.fixVersionLinkedList(previousFound, backwards: backwards)
                                }
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

                    case .failure:
                        return
                    }
                }
            }
            //We are done fixing
        } else {
            if versionFixed.nextVersionUUID != nil && versionFixed.nextVersion == nil {
                Self.first(versionFixed.nextVersionUUID, relatedObject: versionFixed.nextVersion) { result in

                    switch result {

                    case .success(var nextFound):

                        versionFixed.nextVersion = nextFound
                        versionFixed.save(callbackQueue: .main) { results in
                            switch results {

                            case .success:
                                if nextFound.previousVersion == nil {
                                    nextFound.previousVersion = versionFixed
                                    nextFound.save(callbackQueue: .main) { results in

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
                                } else {
                                    self.fixVersionLinkedList(nextFound, backwards: backwards)
                                }
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
        versionedObject.save(callbackQueue: .main) { results in
            switch results {

            case .success(let savedObject):
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.versionable.debug("Successfully added to cloud: \(savedObject, privacy: .private)")
                } else {
                    os_log("Successfully added to cloud: %{private}@",
                           log: .versionable, type: .debug, savedObject.description)
                }

                self.linkVersions { result in

                    if case let .success(modifiedObject) = result {

                        modifiedObject.save(callbackQueue: .main) { _ in }

                        //Fix versioning doubly linked list if it's broken in the cloud
                        if modifiedObject.previousVersion != nil {
                            if modifiedObject.previousVersion!.nextVersion == nil {
                                modifiedObject.previousVersion!.find(modifiedObject.previousVersion!.uuid) { results in

                                    switch results {

                                    case .success(let versionedObjectsFound):
                                        guard var previousObjectFound = versionedObjectsFound.first else {
                                            return
                                        }
                                        previousObjectFound.nextVersion = modifiedObject
                                        previousObjectFound.save(callbackQueue: .main) { results in
                                            switch results {

                                            case .success:
                                                self.fixVersionLinkedList(previousObjectFound, backwards: true)
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
                                    case .failure(let error):
                                        if #available(iOS 14.0, watchOS 7.0, *) {
                                            Logger.versionable.error("Couldn't find object in save(), \(error.localizedDescription, privacy: .private). Object: \(self, privacy: .private)")
                                        } else {
                                            os_log("Couldn't find object in save(), %{private}@. Object: %{private}@",
                                                   log: .versionable, type: .error,
                                                   error.localizedDescription, self.description)
                                        }
                                    }
                                }
                            }
                        }

                        if modifiedObject.nextVersion != nil {
                            if modifiedObject.nextVersion!.previousVersion == nil {
                                modifiedObject.nextVersion!.find(modifiedObject.nextVersion!.uuid) { results in

                                    switch results {

                                    case .success(let versionedObjectsFound):
                                        guard var nextObjectFound = versionedObjectsFound.first else {
                                            return
                                        }
                                        nextObjectFound.previousVersion = modifiedObject
                                        nextObjectFound.save(callbackQueue: .main) { results in
                                            switch results {

                                            case .success:
                                                self.fixVersionLinkedList(nextObjectFound, backwards: true)
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
                                    case .failure(let error):
                                        if #available(iOS 14.0, watchOS 7.0, *) {
                                            Logger.versionable.error("Couldn't find object in save(), \(error.localizedDescription, privacy: .private). Object: \(self, privacy: .private)")
                                        } else {
                                            os_log("Couldn't find object in save(), %{private}@. Object: %{private}@",
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
    private static func queryVersion(for date: Date, queryToAndWith: Query<Self>)-> Query<Self> {
        let interval = createCurrentDateInterval(for: date)

        let query = queryToAndWith
            .where(doesNotExist(key: VersionableKey.deletedDate)) //Only consider non deleted keys
            .where(VersionableKey.effectiveDate < interval.end)
            .include([VersionableKey.next, VersionableKey.previous, ObjectableKey.notes])
        return query
    }

    private static func queryWhereNoNextVersionOrNextVersionGreaterThanEqualToDate(for date: Date)-> Query<Self> {

        let query = Self.query(doesNotExist(key: VersionableKey.next))
            .include([VersionableKey.next, VersionableKey.previous, ObjectableKey.notes])
        let interval = createCurrentDateInterval(for: date)
        let greaterEqualEffectiveDate = self.query(VersionableKey.effectiveDate >= interval.end)
        return Self.query(or(queries: [query, greaterEqualEffectiveDate]))
    }

    func find(for date: Date) throws -> [Self] {
        try Self.query(for: date).find()
    }

    /**
     Querying Versioned objects the same way queries are done in CareKit.
     - Parameters:
        - for: The date the object is active.
        - completion: The block to execute.
     It should have the following argument signature: `(Query<Self>)`.
    */
    //This query doesn't filter nextVersion effectiveDate >= interval.end
    public static func query(for date: Date) -> Query<Self> {
        let query = queryVersion(for: date,
                                 queryToAndWith: queryWhereNoNextVersionOrNextVersionGreaterThanEqualToDate(for: date))
            .include([VersionableKey.next, VersionableKey.previous, ObjectableKey.notes])
        return query
    }

    /**
     Fetch Versioned objects the same way queries are done in CareKit.
     - Parameters:
        - for: The date the objects are active.
        - completion: The block to execute.
     It should have the following argument signature: `(Result<[Self],ParseError>)`.
    */
    public func find(for date: Date, completion: @escaping(Result<[Self], ParseError>) -> Void) {
        let query = Self.query(for: date)
            .include([VersionableKey.next, VersionableKey.previous, ObjectableKey.notes])
        query.find(callbackQueue: .main) { results in
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

        if encodingForParse {
            try container.encodeIfPresent(nextVersion, forKey: .nextVersion)
            try container.encodeIfPresent(previousVersion, forKey: .previousVersion)

        }
        try container.encodeIfPresent(deletedDate, forKey: .deletedDate)
        try container.encodeIfPresent(previousVersionUUID, forKey: .previousVersionUUID)
        try container.encodeIfPresent(nextVersionUUID, forKey: .nextVersionUUID)
        try container.encodeIfPresent(effectiveDate, forKey: .effectiveDate)
        try encodeObjectable(to: encoder)
    }
}

//CustomStringConvertible
extension PCKVersionable {
    public var description: String {
        "className=\(className) uuid=\(String(describing: uuid)) id=\(id) createdDate=\(String(describing: createdDate)) updatedDate=\(String(describing: updatedDate)) schemaVersion=\(String(describing: schemaVersion))  timezone=\(String(describing: timezone)) userInfo=\(String(describing: userInfo)) groupIdentifier=\(String(describing: groupIdentifier)) tags=\(String(describing: tags)) source=\(String(describing: source)) asset=\(String(describing: asset)) remoteID=\(String(describing: remoteID)) notes=\(String(describing: notes)) previousVersionUUID=\(String(describing: previousVersionUUID)) previousVersion=\(String(describing: previousVersion)) nextVersionUUID=\(String(describing: nextVersionUUID)) nextVersion=\(String(describing: nextVersion)) effectiveDate=\(String(describing: effectiveDate)) deletedDate=\(String(describing: deletedDate)) objectId=\(String(describing: objectId)) createdAt=\(String(describing: createdAt)) updatedAt=\(String(describing: updatedAt)) logicalClock=\(String(describing: logicalClock)) encodingForParse=\(encodingForParse) ACL=\(String(describing: ACL))"
    }
} // swiftlint:disable:this file_length
