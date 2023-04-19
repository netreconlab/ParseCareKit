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

// swiftlint:disable line_length

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
    static let queue = DispatchQueue(label: "edu.netreconlab.parsecarekit",
                                     qos: .default,
                                     attributes: .concurrent,
                                     autoreleaseFrequency: .inherit,
                                     target: nil)
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
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.deinitializer.error("Unsubscribed from clock query")
                } else {
                    os_log("Unsubscribed from clock query",
                           log: .deinitializer,
                           type: .error)
                }
            } catch {
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.deinitializer.error("Couldn't unsubscribe from clock query")
                } else {
                    os_log("Couldn't unsubscribe from clock query",
                           log: .deinitializer,
                           type: .error)
                }
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
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.defaultACL.error("Couldn't encode defaultACL from user as string")
                } else {
                    os_log("Couldn't encode defaultACL from user as string",
                           log: .defaultACL,
                           type: .error)
                }
            }
        } catch {
            if #available(iOS 14.0, watchOS 7.0, *) {
                Logger.defaultACL.error("Couldn't encode defaultACL from user. \(error.localizedDescription)")
            } else {
                os_log("Couldn't encode defaultACL from user. %{private}@",
                       log: .defaultACL,
                       type: .error,
                       error.localizedDescription)
            }
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
                                guard await self.remoteStatus.hasNewerRevision(updatedVector,
                                                                               for: self.uuid) else {
                                    return
                                }
                                self.parseDelegate?.didRequestSynchronization(self)
                                if #available(iOS 14.0, watchOS 7.0, *) {
                                    Logger
                                        .clockSubscription
                                        .log("Parse subscription is notifying that there are updates on the server")
                                } else {
                                    os_log("Parse subscription is notifying that there are updates on the server",
                                           log: .clockSubscription,
                                           type: .info)
                                }
                            }
                        } catch {
                            if #available(iOS 14.0, watchOS 7.0, *) {
                                Logger
                                    .clockSubscription
                                    .error("Could not decode server clock: \(error)")
                            } else {
                                os_log("Could not decode server clock: %{private}@",
                                       log: .clockSubscription,
                                       type: .error,
                                       error.localizedDescription)
                            }
                        }
                    default:
                        return
                    }
                }
            } catch {
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.clockSubscription.error("Couldn't subscribe to clock query")
                } else {
                    os_log("Couldn't subscribe to clock query",
                           log: .clockSubscription,
                           type: .error)
                }
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
            do {
                _ = try await PCKUser.current()
            } catch {
                completion(ParseCareKitError.userNotLoggedIn)
                return
            }

            do {
                let status = try await ParseHealth.check()
                guard status == .ok else {
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.pullRevisions.error("Server health is: \(status.rawValue)")
                    } else {
                        os_log("Server health is not ok", log: .pullRevisions, type: .error)
                    }
                    completion(ParseCareKitError.parseHealthError)
                    return
                }
            } catch {
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.pullRevisions.error("Server health: \(error.localizedDescription)")
                } else {
                    os_log("Server health: %{private}@", log: .pullRevisions, type: .error, error.localizedDescription)
                }
                completion(ParseCareKitError.parseHealthError)
                return
            }

            if await remoteStatus.isSynchronizing {
                completion(ParseCareKitError.syncAlreadyInProgress)
                return
            }
            await remoteStatus.synchronizing()

            // Fetch Clock from Cloud
            PCKClock.fetchFromCloud(uuid: self.uuid, createNewIfNeeded: false) { (_, potentialCKClock, _) in
                guard let cloudVector = potentialCKClock else {
                    // No Clock available, need to let CareKit know this is the first sync.
                    let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
                    mergeRevision(revision)
                    completion(nil)
                    return
                }
                let localClock = knowledgeVector.clock(for: self.uuid)
                ParseRemote.queue.async {
                    Task {
                        let query = PCKRevisionRecord.query(ObjectableKey.logicalClock > localClock,
                                                            ObjectableKey.clockUUID == self.uuid)
                            .order([.ascending(ObjectableKey.logicalClock)])
                        do {
                            let revisions = try await query.find()
                            self.notifyRevisionProgress(0,
                                                        totalRecords: revisions.count)
                            for (index, revision) in revisions.enumerated() {
                                let record = try await revision.fetchEntities().convertToCareKit()
                                mergeRevision(record)
                                self.notifyRevisionProgress(index + 1,
                                                            totalRecords: revisions.count)
                            }

                            // Catch up
                            let revision = OCKRevisionRecord(entities: [],
                                                             knowledgeVector: cloudVector)
                            mergeRevision(revision)
                            if #available(iOS 14.0, watchOS 7.0, *) {
                                Logger.pullRevisions.debug("Finished pulling revisions for default classes")
                            } else {
                                os_log("Finished pulling revisions for default classes", log: .pullRevisions, type: .debug)
                            }
                            completion(nil)
                        } catch {
                            await self.remoteStatus.notSynchronzing()
                            completion(error)
                        }
                    }
                }
            }
        }
    }

    public func pushRevisions(deviceRevisions: [CareKitStore.OCKRevisionRecord],
                              deviceKnowledge: CareKitStore.OCKRevisionRecord.KnowledgeVector,
                              completion: @escaping (Error?) -> Void) {

        // Fetch Clock from Cloud
        PCKClock.fetchFromCloud(uuid: self.uuid,
                                createNewIfNeeded: true) { (potentialPCKClock, potentialPCKVector, error) in
            ParseRemote.queue.async {
                Task {
                    guard let parseClock = potentialPCKClock,
                        let cloudVector = potentialPCKVector else {
                        await self.remoteStatus.notSynchronzing()
                        guard let parseError = error else {
                            // There was a different issue that we don't know how to handle
                            if #available(iOS 14.0, watchOS 7.0, *) {
                                Logger.pushRevisions.error("Error in pushRevisions. Couldn't unwrap clock")
                            } else {
                                os_log("Error in pushRevisions. Couldn't unwrap clock",
                                       log: .pushRevisions, type: .error)
                            }
                            completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                            return
                        }
                        if #available(iOS 14.0, watchOS 7.0, *) {
                            Logger.pushRevisions.error("Error in pushRevisions. Couldn't unwrap clock: \(parseError)")
                        } else {
                            os_log("Error in pushRevisions. Couldn't unwrap clock: %{private}@",
                                   log: .pushRevisions, type: .error, parseError.localizedDescription)
                        }
                        completion(parseError)
                        return
                    }

                    guard deviceRevisions.count > 0 else {
                        completion(nil)
                        return
                    }

                    // Push all revision records
                    var updatedDeviceKnowledge = deviceKnowledge
                    // Increment and merge Knowledge Vector
                    updatedDeviceKnowledge.increment(clockFor: self.uuid)
                    let logicalClock = updatedDeviceKnowledge.clock(for: self.uuid)
                    self.notifyRevisionProgress(0,
                                                totalRecords: deviceRevisions.count)

                    for (index, deviceRevision) in deviceRevisions.enumerated() {
                        do {
                            let revision = try PCKRevisionRecord(record: deviceRevision,
                                                                 remoteClockUUID: self.uuid,
                                                                 remoteClock: parseClock,
                                                                 remoteClockValue: logicalClock)
                            _ = try await revision.save()
                            self.notifyRevisionProgress(index + 1,
                                                        totalRecords: deviceRevisions.count)
                            if index == (deviceRevisions.count - 1) {
                                self.completePushRevisions(parseClock: parseClock,
                                                           cloudVector: cloudVector,
                                                           localClock: updatedDeviceKnowledge,
                                                           completion: completion)
                            }
                        } catch {
                            await self.remoteStatus.notSynchronzing()
                            completion(error)
                            break
                        }
                    }
                }
            }
        }
    }

    func completePushRevisions(parseClock: PCKClock,
                               cloudVector: OCKRevisionRecord.KnowledgeVector,
                               localClock: OCKRevisionRecord.KnowledgeVector,
                               completion: @escaping (Error?) -> Void) {
        Task {
            var updatedCloudVector = cloudVector
            updatedCloudVector.merge(with: localClock)

            guard let updatedClock = PCKClock.encodeVector(updatedCloudVector, for: parseClock) else {
                await self.remoteStatus.notSynchronzing()
                completion(ParseCareKitError.couldntUnwrapClock)
                return
            }
            await self.remoteStatus.updateKnowledgeVector(updatedCloudVector)
            do {
                _ = try await updatedClock.save()
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.pushRevisions.debug("Finished pushing revisions")
                } else {
                    os_log("Finished pushing revisions", log: .pushRevisions, type: .debug)
                }
                DispatchQueue.main.async {
                    self.parseRemoteDelegate?.successfullyPushedDataToCloud()
                }
                completion(nil)
            } catch {
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.pushRevisions.error("finishedRevisions: \(error.localizedDescription, privacy: .private)")
                } else {
                    os_log("finishedRevisions: %{private}@",
                           log: .pushRevisions, type: .error, error.localizedDescription)
                }
                completion(error)
            }
            await self.remoteStatus.notSynchronzing()
            await self.subscribeToClock()
        }
    }

    func notifyRevisionProgress(_ numberCompleted: Int, totalRecords: Int) {
        if totalRecords > 0 {
            let ratioComplete = Double(numberCompleted)/Double(totalRecords)
            DispatchQueue.main.async {
                self.parseDelegate?.remote(self, didUpdateProgress: ratioComplete)
            }
            if #available(iOS 14.0, watchOS 7.0, *) {
                Logger.syncProgress.info("\(ratioComplete, privacy: .private)")
            } else {
                os_log("%{private}@",
                       log: .syncProgress, type: .default, ratioComplete)
            }
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
