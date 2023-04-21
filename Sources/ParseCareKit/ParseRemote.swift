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

/// Allows the CareKitStore to synchronize against a Parse Server.
public class ParseRemote: OCKRemoteSynchronizable {

    public weak var delegate: OCKRemoteSynchronizationDelegate?

    /// If set, the delegate will be alerted to important events delivered by the remote
    /// store (set this, don't set `delegate`).
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

    /// A dictionary of any custom classes to synchronize between the CareKitStore and the Parse Server.
    public var customClassesToSynchronize: [String: PCKSynchronizable]?

    /// A dictionary of any default classes to synchronize between the CareKitStore and the Parse Server. These
    /// are `PCKPatient`, `PCKTask`, `PCKCarePlan`, `PCKContact`, and `PCKOutcome`.
    public var pckStoreClassesToSynchronize: [PCKStoreClass: PCKSynchronizable]!

    private weak var parseDelegate: ParseRemoteDelegate?
    private var clockSubscription: SubscriptionCallback<PCKClock>?
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
        self.pckStoreClassesToSynchronize = try PCKStoreClass.patient.getConcrete()
        self.customClassesToSynchronize = nil
        self.uuid = uuid
        self.clockQuery = PCKClock.query(ClockKey.uuid == uuid)
        self.automaticallySynchronizes = auto
        self.subscribeToServerUpdates = subscribeToServerUpdates
        if let currentUser = try? await PCKUser.current() {
            try Self.setDefaultACL(defaultACL, for: currentUser)
            await subscribeToClock()
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
                            replacePCKStoreClasses: [PCKStoreClass: PCKSynchronizable],
                            subscribeToServerUpdates: Bool,
                            defaultACL: ParseACL? = nil) async throws {
        try await self.init(uuid: uuid,
                            auto: auto,
                            subscribeToServerUpdates: subscribeToServerUpdates,
                            defaultACL: defaultACL)
        try self.pckStoreClassesToSynchronize = PCKStoreClass
            .patient.replaceRemoteConcreteClasses(replacePCKStoreClasses)
        self.customClassesToSynchronize = nil
    }

    /**
     Creates an instance of ParseRemote.
     - Parameters:
        - uuid: The unique identifier of the remote clock.
        - auto: If set to `true`, then the store will attempt to synchronize every time it is modified locally.
        - replacePCKStoreClasses: Replace some or all of the default classes that are synchronized
            by passing in the respective Key/Value pairs. Defaults to nil, which uses the standard default entities.
        - customClasses: Add custom classes to synchroniz by passing in the respective Key/Value pair.
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
                            replacePCKStoreClasses: [PCKStoreClass: PCKSynchronizable]? = nil,
                            customClasses: [String: PCKSynchronizable],
                            subscribeToServerUpdates: Bool,
                            defaultACL: ParseACL? = nil) async throws {
        try await self.init(uuid: uuid,
                            auto: auto,
                            subscribeToServerUpdates: subscribeToServerUpdates,
                            defaultACL: defaultACL)
        if replacePCKStoreClasses != nil {
            self.pckStoreClassesToSynchronize = try PCKStoreClass
                .patient.replaceRemoteConcreteClasses(replacePCKStoreClasses!)
        } else {
            self.pckStoreClassesToSynchronize = nil
        }
        self.customClassesToSynchronize = customClasses
    }

    deinit {
        Task {
            do {
                try await clockQuery.unsubscribe()
                Logger.deinitializer.error("Unsubscribed from clock query")
            } catch {
                Logger.deinitializer.error("Couldn't unsubscribe from clock query")
            }
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
                Logger.defaultACL.error("Couldn't encode defaultACL from user as string")
            }
        } catch {
            Logger.defaultACL.error("Couldn't encode defaultACL from user. \(error)")
            throw error
        }
    }

    @MainActor
    func subscribeToClock() async {
        do {
            _ = try await PCKUser.current()
            guard self.subscribeToServerUpdates,
                self.clockSubscription == nil else {
                return
            }

            do {
                self.clockSubscription = try await self.clockQuery.subscribeCallback()
                self.clockSubscription?.handleEvent { (_, event) in
                    switch event {
                    case .created(let updatedClock), .entered(let updatedClock), .updated(let updatedClock):
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
                Logger.clockSubscription.error("Couldn't subscribe to clock query")
                return
            }
        } catch {
            return
        }
    }

    public func pullRevisions(since knowledgeVector: OCKRevisionRecord.KnowledgeVector,
                              mergeRevision: @escaping (OCKRevisionRecord) -> Void,
                              completion: @escaping (Error?) -> Void) {

        Task {
            // 1. Make sure a remote is setup
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
                Logger.pullRevisions.error("Server health: \(error.localizedDescription)")
                completion(ParseCareKitError.parseHealthError)
                return
            }

            if await remoteStatus.isSynchronizing {
                completion(ParseCareKitError.syncAlreadyInProgress)
                return
            }
            await remoteStatus.synchronizing()

            do {
                let parseClock = try await PCKClock.fetchFromCloud(self.uuid, createNewIfNeeded: false)

                guard let parseVector = parseClock.knowledgeVector else {
                    // No Clock available, need to let CareKit know this is the first sync.
                    let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
                    mergeRevision(revision)
                    completion(nil)
                    return
                }
                let localClock = knowledgeVector.clock(for: self.uuid)

                // 2. Pull revisions
                let query = PCKRevisionRecord.query(ObjectableKey.logicalClock >= localClock,
                                                    ObjectableKey.clockUUID == self.uuid)
                    .order([.ascending(ObjectableKey.logicalClock)])
                do {
                    let revisions = try await query.find()
                    self.notifyRevisionProgress(0,
                                                total: revisions.count)
                    // 2.1 Merge revisions
                    for (index, revision) in revisions.enumerated() {
                        let record = try await revision.fetchEntities().convertToCareKit()
                        mergeRevision(record)
                        self.notifyRevisionProgress(index + 1,
                                                    total: revisions.count)
                    }
                    self.notifyRevisionProgress(revisions.count,
                                                total: revisions.count)

                    var updatedParseClock = parseClock
                    var updatedParseVector = parseVector
                    if revisions.count > 0 {
                        // 3. Increment the knowledge vector so that all conflict
                        //    revisions applied in the next step count as new for
                        //    the peer.
                        updatedParseVector = incrementVectorClock(updatedParseVector)
                        updatedParseClock.knowledgeVector = updatedParseVector
                        guard updatedParseClock.knowledgeVector != nil else {
                            await self.remoteStatus.notSynchronzing()
                            completion(ParseCareKitError.couldntUnwrapClock)
                            return
                        }
                        do {
                            await self.remoteStatus.updateKnowledgeVector(updatedParseClock.knowledgeVector)
                            updatedParseClock = try await updatedParseClock.save()
                        } catch {
                            await self.remoteStatus.notSynchronzing()
                            completion(ParseCareKitError.couldntUnwrapClock)
                            return
                        }
                    } else {
                        await self.remoteStatus.updateKnowledgeVector(updatedParseClock.knowledgeVector)
                    }

                    // 4. Lock in the changes and catch up local device.
                    let revision = OCKRevisionRecord(entities: [],
                                                     knowledgeVector: updatedParseVector)
                    mergeRevision(revision)
                    Logger.pullRevisions.debug("Finished pulling revisions for default classes")
                    completion(nil)
                } catch {
                    await self.remoteStatus.notSynchronzing()
                    completion(error)
                }
            } catch {
                // No Clock available, need to let CareKit know this is the first sync.
                let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
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
                // Fetch Clock from Cloud
                let parseClock = try await PCKClock.fetchFromCloud(self.uuid,
                                                                   createNewIfNeeded: true)
                guard let parseVector = parseClock.knowledgeVector else {
                    await self.remoteStatus.notSynchronzing()
                    // There was a different issue that we don't know how to handle
                    Logger.pushRevisions.error("Error in pushRevisions. Couldn't unwrap clock")
                    completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                    return
                }

                guard await !self.remoteStatus.hasNewerRevision(parseVector, for: self.uuid) else {
                    let errorString = "New knowledge on server. Pull first then try again"
                    Logger.pushRevisions.error("\(errorString)")
                    await self.remoteStatus.notSynchronzing()
                    completion(ParseCareKitError.errorString(errorString))
                    return
                }

                guard deviceRevisions.count > 0 else {
                    self.completePushRevisions(shouldIncrementClock: false,
                                               parseClock: parseClock,
                                               parseVector: parseVector,
                                               localClock: deviceKnowledge,
                                               completion: completion)
                    return
                }

                // 8. Push conflict resolutions + local changes to remote
                let logicalClock = deviceKnowledge.clock(for: self.uuid)
                self.notifyRevisionProgress(0,
                                            total: deviceRevisions.count)

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
                Logger.pushRevisions.error("Error in pushRevisions. Couldn't unwrap clock: \(error)")
                completion(error)
                return
            }
        }
    }

    func completePushRevisions(shouldIncrementClock: Bool = true,
                               parseClock: PCKClock,
                               parseVector: OCKRevisionRecord.KnowledgeVector,
                               localClock: OCKRevisionRecord.KnowledgeVector,
                               completion: @escaping (Error?) -> Void) {
        Task {
            var updatedParseVector = parseVector
            if shouldIncrementClock {
                // Increment and merge Knowledge Vector
                updatedParseVector = incrementVectorClock(updatedParseVector)
            }
            updatedParseVector.merge(with: localClock)
            guard let updatedClock = PCKClock.encodeVector(updatedParseVector, for: parseClock) else {
                await self.remoteStatus.updateKnowledgeVector(parseVector) // revert
                await self.remoteStatus.notSynchronzing()
                completion(ParseCareKitError.couldntUnwrapClock)
                return
            }
            do {
                await self.remoteStatus.updateKnowledgeVector(updatedParseVector)
                _ = try await updatedClock.save()
                Logger.pushRevisions.debug("Finished pushing revisions")
                DispatchQueue.main.async {
                    self.parseRemoteDelegate?.successfullyPushedDataToCloud()
                }
                completion(nil)
            } catch {
                await self.remoteStatus.updateKnowledgeVector(parseVector) // revert
                Logger.pushRevisions.error("finishedRevisions: \(error, privacy: .private)")
                completion(error)
            }
            await self.remoteStatus.notSynchronzing()
            await self.subscribeToClock()
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

    public func chooseConflictResolution(conflicts: [OCKEntity], completion: @escaping OCKResultClosure<OCKEntity>) {

        guard let parseDelegate = self.parseDelegate else {
            guard let first = conflicts.first else {
                completion(.failure(.remoteSynchronizationFailed(reason: "Error: no conflict available")))
                return
            }
            completion(.success(first))
            return
        }
        DispatchQueue.main.async {
            parseDelegate
                .chooseConflictResolution(conflicts: conflicts,
                                          completion: completion)
        }
    }
}
