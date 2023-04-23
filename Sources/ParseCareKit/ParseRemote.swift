//
//  ParseRemote.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/6/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import CareKitStore
import ParseSwift
import os.log

/// Allows the `CareKitStore` to synchronize with a Parse Server.
public class ParseRemote: OCKRemoteSynchronizable {

    /// - warning: Should set `parseRemoteDelegate` instead.
    public weak var delegate: OCKRemoteSynchronizationDelegate?

    /// If set, the delegate will be alerted to important events delivered by the remote
    /// store.
    /// - note: Setting `parseRemoteDelegate` automatically sets `delegate`.
    public weak var parseRemoteDelegate: ParseRemoteDelegate? {
        get {
            return parseDelegate
        }
        set {
            parseDelegate = newValue
            delegate = newValue
        }
    }

    public var automaticallySynchronizes: Bool

    /// The unique identifier of the remote clock.
    public var uuid: UUID!

    /// A dictionary of any custom classes to synchronize between the `CareKitStore` and the Parse Server.
    public var customClassesToSynchronize: [String: any PCKVersionable]?

    /// A dictionary of any default classes to synchronize between the `CareKitStore` and the Parse Server. These
    /// are `PCKPatient`, `PCKCarePlan`, `PCKContact`, `PCKTask`,  `PCKHealthKitTask`,
    /// and `PCKOutcome`.
    public var pckStoreClassesToSynchronize: [PCKStoreClass: any PCKVersionable.Type]!

    private weak var parseDelegate: ParseRemoteDelegate?
    private var clockRecordSubscription: SubscriptionCallback<PCKClock>?
    private var subscribeToServerUpdates: Bool
    private let remoteStatus = RemoteSynchronizing()
    private let clockQuery: Query<PCKClock>

    /**
     Creates an instance of ParseRemote.
     - Parameters:
        - uuid: The unique identifier of the remote clock.
        - auto: If set to `true`, then the store will attempt to synchronize every time it is modified locally.
        - subscribeToServerUpdates: Automatically receive updates from other devices linked to this Clock.
        Requires `ParseLiveQuery` server to be setup.
        - defaultACL: The default access control list for which users can access or modify `ParseCareKit`
        objects. If no `defaultACL` is provided, the default is set to read/write for the user who created the data with
        no public read/write access.
        - important: This `defaultACL` is not the same as `ParseACL.defaultACL`.
        - note: If you want the the `ParseCareKit` `defaultACL` to match the `ParseACL.defaultACL`,
        you need to provide `ParseACL.defaultACL`.
    */
    public init(uuid: UUID,
                auto: Bool,
                subscribeToServerUpdates: Bool,
                defaultACL: ParseACL? = nil) async throws {
        self.pckStoreClassesToSynchronize = try PCKStoreClass.getConcrete()
        self.customClassesToSynchronize = nil
        self.uuid = uuid
        self.clockQuery = PCKClock.query(ClockKey.uuid == uuid)
        self.automaticallySynchronizes = auto
        self.subscribeToServerUpdates = subscribeToServerUpdates
        if let currentUser = try? await PCKUser.current() {
            try Self.setDefaultACL(defaultACL, for: currentUser)
            await subscribeToRevisionRecord()
        }
    }

    /**
     Creates an instance of ParseRemote.
     - Parameters:
        - uuid: The unique identifier of the remote clock.
        - auto: If set to `true`, then the store will attempt to synchronize every time it is modified locally.
        - replacePCKStoreClasses: Replace some or all of the default classes that are synchronized
        - subscribeToServerUpdates: Automatically receive updates from other devices linked to this Clock.
        Requires `ParseLiveQuery` server to be setup.
        - defaultACL: The default access control list for which users can access or modify `ParseCareKit`
        objects. If no `defaultACL` is provided, the default is set to read/write for the user who created the data with
        no public read/write access.
     - important: This `defaultACL` is not the same as `ParseACL.defaultACL`.
     - note: If you want the the `ParseCareKit` `defaultACL` to match the `ParseACL.defaultACL`,
     you need to provide `ParseACL.defaultACL`.
    */
    convenience public init(uuid: UUID,
                            auto: Bool,
                            replacePCKStoreClasses: [PCKStoreClass: any PCKVersionable.Type],
                            subscribeToServerUpdates: Bool,
                            defaultACL: ParseACL? = nil) async throws {
        try await self.init(uuid: uuid,
                            auto: auto,
                            subscribeToServerUpdates: subscribeToServerUpdates,
                            defaultACL: defaultACL)
        try self.pckStoreClassesToSynchronize = PCKStoreClass
            .replaceRemoteConcreteClasses(replacePCKStoreClasses)
        self.customClassesToSynchronize = nil
    }

    /**
     Creates an instance of ParseRemote.
     - Parameters:
        - uuid: The unique identifier of the remote clock.
        - auto: If set to `true`, then the store will attempt to synchronize every time it is modified locally.
        - replacePCKStoreClasses: Replace some or all of the default classes that are synchronized
            by passing in the respective Key/Value pairs. Defaults to nil, which uses the standard default entities.
        - customClasses: Add custom classes to synchronize by passing in the respective key/value pair.
        - subscribeToServerUpdates: Automatically receive updates from other devices linked to this Clock.
        Requires `ParseLiveQuery` server to be setup.
        - defaultACL: The default access control list for which users can access or modify `ParseCareKit`
        objects. If no `defaultACL` is provided, the default is set to read/write for the user who created the data with
        no public read/write access along with respective read/write roles.
     - important: This `defaultACL` is not the same as `ParseACL.defaultACL`.
     - note: If you want the `ParseCareKit` `defaultACL` to match the `ParseACL.defaultACL`,
     you need to provide `ParseACL.defaultACL`.
    */
    convenience public init(uuid: UUID,
                            auto: Bool,
                            replacePCKStoreClasses: [PCKStoreClass: any PCKVersionable.Type]? = nil,
                            customClasses: [String: any PCKVersionable],
                            subscribeToServerUpdates: Bool,
                            defaultACL: ParseACL? = nil) async throws {
        try await self.init(uuid: uuid,
                            auto: auto,
                            subscribeToServerUpdates: subscribeToServerUpdates,
                            defaultACL: defaultACL)
        if let replacePCKStoreClasses = replacePCKStoreClasses {
            self.pckStoreClassesToSynchronize = try PCKStoreClass
                .replaceRemoteConcreteClasses(replacePCKStoreClasses)
        } else {
            self.pckStoreClassesToSynchronize = nil
        }
        self.customClassesToSynchronize = customClasses
    }

    deinit {
        Task {
            do {
                try await clockQuery.unsubscribe()
                Logger.deinitializer.error("Unsubscribed from Parse remote")
            } catch {
                Logger.deinitializer.error("Could not unsubscribe from Parse remote: \(error)")
            }
        }
    }

    // MARK: Conformance to OCKRemoteSynchronizable

    public func pullRevisions(since knowledgeVector: OCKRevisionRecord.KnowledgeVector,
                              mergeRevision: @escaping (OCKRevisionRecord) -> Void,
                              completion: @escaping (Error?) -> Void) {

        Task {
            // 1. Make sure a remote is setup and available.
            do {
                _ = try await PCKUser.current()
            } catch {
                completion(ParseCareKitError.userNotLoggedIn)
                return
            }

            do {
                let status = try await ParseHealth.check()
                guard status == .ok else {
                    Logger.pullRevisions.error("Server health is: \(status.rawValue)")
                    completion(ParseCareKitError.parseHealthError)
                    return
                }
            } catch {
                Logger.pullRevisions.error("Server health is: \(error.localizedDescription)")
                completion(ParseCareKitError.parseHealthError)
                return
            }

            // 2. Only continue if a sync is not in progress.
            guard await !remoteStatus.isSynchronizing else {
                completion(ParseCareKitError.syncAlreadyInProgress)
                return
            }
            await remoteStatus.synchronizing()

            do {
                let parseClock = try await PCKClock.fetchFromRemote(self.uuid, createNewIfNeeded: false)

                guard let parseVector = parseClock.knowledgeVector else {
                    // No KnowledgeVector available, act as if this is the first sync.
                    let revision = OCKRevisionRecord(entities: [],
                                                     knowledgeVector: .init())
                    mergeRevision(revision)
                    completion(nil)
                    return
                }

                // 3. Pull the latest revisions from the remote.
                let localClock = knowledgeVector.clock(for: self.uuid)
                let query = PCKRevisionRecord.query(ObjectableKey.logicalClock >= localClock,
                                                    ObjectableKey.clockUUID == self.uuid)
                    .order([.ascending(ObjectableKey.logicalClock)])
                do {
                    let revisions = try await query.find()
                    self.notifyRevisionProgress(0,
                                                total: revisions.count)

                    // 4 Merge all new revisions locally from remote.
                    for (index, revision) in revisions.enumerated() {
                        let record = try await revision.fetchEntities().convertToCareKit()
                        mergeRevision(record)
                        self.notifyRevisionProgress(index + 1,
                                                    total: revisions.count)
                    }
                    self.notifyRevisionProgress(revisions.count,
                                                total: revisions.count)

                    await self.remoteStatus.updateClock(parseClock)

                    // 5. Lock in the changes and catch up local device.
                    let revision = OCKRevisionRecord(entities: [],
                                                     knowledgeVector: parseVector)
                    mergeRevision(revision)
                    Logger.pullRevisions.debug("Finished pulling revisions")
                    completion(nil)
                } catch {
                    await self.remoteStatus.notSynchronzing()
                    completion(error)
                }
            } catch {
                // No Clock available, let CareKit know to push all local revisions.
                let revision = OCKRevisionRecord(entities: [],
                                                 knowledgeVector: .init())
                mergeRevision(revision)
                completion(nil)
                return
            }
        }
    }

    public func pushRevisions(deviceRevisions: [CareKitStore.OCKRevisionRecord],
                              deviceKnowledge: CareKitStore.OCKRevisionRecord.KnowledgeVector,
                              completion: @escaping (Error?) -> Void) {

        Task {
            do {
                let parseClock = try await PCKClock.fetchFromRemote(self.uuid, createNewIfNeeded: true)

                guard let parseVector = parseClock.knowledgeVector else {
                    await self.remoteStatus.notSynchronzing()
                    // There was a different issue that we don't know how to handle
                    Logger.pushRevisions.error("Could not get KnowledgeVector from Clock")
                    completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                    return
                }

                // 6. Ensure there has not been any updates to remote clock before proceeding.
                let hasNewerRevision = await self.remoteStatus.hasNewerRevision(parseVector, for: self.uuid)
                let currentClock = await self.remoteStatus.clock
                guard !hasNewerRevision || currentClock == nil else {
                    let errorString = "New knowledge on server. Pull first then try again"
                    Logger.pushRevisions.error("\(errorString)")
                    await self.remoteStatus.notSynchronzing()
                    completion(ParseCareKitError.errorString(errorString))
                    return
                }

                // 7. Only proceed if there are new local revisions.
                guard deviceRevisions.count > 0 else {
                    self.completePushRevisions(shouldIncrementClock: false,
                                               parseClock: parseClock,
                                               parseVector: parseVector,
                                               localClock: deviceKnowledge,
                                               completion: completion)
                    return
                }

                // 8. Push new local revisions to remote.
                self.notifyRevisionProgress(0,
                                            total: deviceRevisions.count)
                let logicalClock = parseVector.clock(for: self.uuid)
                for (index, deviceRevision) in deviceRevisions.enumerated() {
                    do {
                        let remoteRevision = try PCKRevisionRecord(record: deviceRevision,
                                                                   remoteClockUUID: self.uuid,
                                                                   remoteClock: parseClock,
                                                                   remoteClockValue: logicalClock)
                        try await remoteRevision.save()
                        self.notifyRevisionProgress(index + 1,
                                                    total: deviceRevisions.count)
                        if index == (deviceRevisions.count - 1) {
                            self.completePushRevisions(parseClock: parseClock,
                                                       parseVector: parseVector,
                                                       localClock: deviceKnowledge,
                                                       completion: completion)
                        }
                    } catch {
                        await self.remoteStatus.notSynchronzing()
                        completion(error)
                        break
                    }
                }
                self.notifyRevisionProgress(deviceRevisions.count,
                                            total: deviceRevisions.count)
            } catch {
                Logger.pushRevisions.error("Could not create clock: \(error)")
                completion(error)
                return
            }
        }
    }

    public func chooseConflictResolution(conflicts: [OCKEntity],
                                         completion: @escaping OCKResultClosure<OCKEntity>) {

        guard let parseDelegate = self.parseDelegate else {
            // Last write wins
            do {
                let lastWrite = try conflicts
                    .max(by: { try $0.parseEntity().value.createdDate! > $1.parseEntity().value.createdDate! })!

                completion(.success(lastWrite))
            } catch {
                completion(.failure(.invalidValue(reason: error.localizedDescription)))
            }
            return
        }
        DispatchQueue.main.async {
            parseDelegate
                .chooseConflictResolution(conflicts: conflicts,
                                          completion: completion)
        }
    }

    // MARK: Helper methods

    func completePushRevisions(shouldIncrementClock: Bool = true,
                               parseClock: PCKClock,
                               parseVector: OCKRevisionRecord.KnowledgeVector,
                               localClock: OCKRevisionRecord.KnowledgeVector,
                               completion: @escaping (Error?) -> Void) {
        Task {
            var updatedParseVector = parseVector
            // 9. Increment and merge clocks if new local revisions were pushed,
            //    or else check if the local device is new with a new clock that
            //    is now in sync with the remote.
            if shouldIncrementClock {
                updatedParseVector = incrementVectorClock(updatedParseVector)
                updatedParseVector.merge(with: localClock)
            } else {
                updatedParseVector.merge(with: localClock)
                guard updatedParseVector.uuids.count > parseVector.uuids.count else {
                    Logger.pushRevisions.debug("Finished pushing revisions")
                    await self.remoteStatus.notSynchronzing()
                    await self.subscribeToRevisionRecord()
                    DispatchQueue.main.async {
                        self.parseRemoteDelegate?.successfullyPushedToRemote()
                    }
                    completion(nil)
                    return
                }
            }

            // 10. Save updated clock to the remote and notify peer that sync is complete.
            guard let updatedClock = PCKClock.encodeVector(updatedParseVector, for: parseClock) else {
                await self.remoteStatus.notSynchronzing()
                Logger.pushRevisions.error("Could not encode clock")
                completion(ParseCareKitError.couldntUnwrapClock)
                return
            }
            do {
                await self.remoteStatus.updateClock(updatedClock)
                _ = try await updatedClock.save()
                Logger.pushRevisions.debug("Finished pushing revisions")
                DispatchQueue.main.async {
                    self.parseRemoteDelegate?.successfullyPushedToRemote()
                }
                completion(nil)
            } catch {
                await self.remoteStatus.updateClock(parseClock) // revert
                Logger.pushRevisions.error("finishedRevisions: \(error, privacy: .private)")
                completion(error)
            }
            await self.remoteStatus.notSynchronzing()
            await self.subscribeToRevisionRecord()
        }
    }

    class func setDefaultACL(_ defaultACL: ParseACL?, for user: PCKUser) throws {
        let acl: ParseACL!
        if let defaultACL = defaultACL {
            acl = defaultACL
        } else {
            var defaultACL = ParseACL()
            defaultACL.publicRead = false
            defaultACL.publicWrite = false
            defaultACL.setReadAccess(user: user, value: true)
            defaultACL.setWriteAccess(user: user, value: true)
            defaultACL.setReadAccess(roleName: try PCKReadRole.roleName(owner: user),
                                     value: true)
            defaultACL.setWriteAccess(roleName: try PCKWriteRole.roleName(owner: user),
                                      value: true)
            acl = defaultACL
        }
        if let currentDefaultACL = PCKUtility.getDefaultACL() {
            if acl == currentDefaultACL {
                return
            }
        }
        do {
            let encodedACL = try PCKUtility.jsonEncoder().encode(acl)
            if let aclString = String(data: encodedACL, encoding: .utf8) {
                UserDefaults.standard.setValue(aclString,
                                               forKey: ParseCareKitConstants.defaultACL)
                UserDefaults.standard.synchronize()
            } else {
                Logger.defaultACL.error("Could not encode defaultACL from user as string")
            }
        } catch {
            Logger.defaultACL.error("Could not encode defaultACL from user. \(error)")
            throw error
        }
    }

    @MainActor
    func subscribeToRevisionRecord() async {
        do {
            _ = try await PCKUser.current()
            guard self.subscribeToServerUpdates,
                self.clockRecordSubscription == nil else {
                return
            }

            do {
                self.clockRecordSubscription = try await self.clockQuery.subscribeCallback()
                self.clockRecordSubscription?.handleEvent { (_, event) in
                    switch event {
                    case .created(let updatedClock), .updated(let updatedClock), .entered(let updatedClock):
                        do {
                            let updatedVector = try PCKClock.decodeVector(updatedClock)
                            Task {
                                guard await self.remoteStatus.hasNewerRevision(updatedVector, for: self.uuid) else {
                                    return
                                }
                                self.parseDelegate?.didRequestSynchronization(self)
                                Logger
                                    .clockSubscription
                                    .log("Parse subscription is notifying that there are updates on the server")
                            }
                        } catch {
                            Logger
                                .clockSubscription
                                .error("Could not decode server clock: \(error)")
                        }
                    default:
                        return
                    }
                }
            } catch {
                Logger.clockSubscription.error("Could not subscribe to RevisionRecord query")
                return
            }
        } catch {
            return
        }
    }

    func incrementVectorClock(_ vector: OCKRevisionRecord.KnowledgeVector) -> OCKRevisionRecord.KnowledgeVector {
        var mutableVector = vector
        mutableVector.increment(clockFor: self.uuid)
        return mutableVector
    }

    func notifyRevisionProgress(_ numberCompleted: Int, total: Int) {
        if total > 0 {
            let ratioComplete = Double(numberCompleted)/Double(total)
            DispatchQueue.main.async {
                self.parseDelegate?.remote(self, didUpdateProgress: ratioComplete)
            }
            Logger.syncProgress.info("\(ratioComplete, privacy: .private)")
        }
    }
}
