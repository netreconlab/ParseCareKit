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
    private var isSynchronizing = false
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
        no public read/write access. This `defaultACL` is not the same as `ParseACL.defaultACL`. If you want the
        the `ParseCareKit` `defaultACL` to match the `ParseACL.defaultACL`, you need to provide
        `ParseACL.defaultACL`.
    */
    public init(uuid: UUID,
                auto: Bool,
                subscribeToServerUpdates: Bool,
                defaultACL: ParseACL? = nil) throws {
        self.pckStoreClassesToSynchronize = try PCKStoreClass.patient.getConcrete()
        self.customClassesToSynchronize = nil
        self.uuid = uuid
        self.automaticallySynchronizes = auto
        self.subscribeToServerUpdates = subscribeToServerUpdates
        if let currentUser = PCKUser.current {
            Self.setDefaultACL(defaultACL, for: currentUser)
            subscribeToClock()
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
        no public read/write access. This `defaultACL` is not the same as `ParseACL.defaultACL`. If you want the
        the `ParseCareKit` `defaultACL` to match the `ParseACL.defaultACL`, you need to provide
        `ParseACL.defaultACL`.
    */
    convenience public init(uuid: UUID,
                            auto: Bool,
                            replacePCKStoreClasses: [PCKStoreClass: PCKSynchronizable],
                            subscribeToServerUpdates: Bool,
                            defaultACL: ParseACL? = nil) throws {
        try self.init(uuid: uuid,
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
        no public read/write access. This `defaultACL` is not the same as `ParseACL.defaultACL`. If you want the
        the `ParseCareKit` `defaultACL` to match the `ParseACL.defaultACL`, you need to provide
        `ParseACL.defaultACL`.
    */
    convenience public init(uuid: UUID,
                            auto: Bool,
                            replacePCKStoreClasses: [PCKStoreClass: PCKSynchronizable]? = nil,
                            customClasses: [String: PCKSynchronizable],
                            subscribeToServerUpdates: Bool,
                            defaultACL: ParseACL? = nil) throws {
        try self.init(uuid: uuid,
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

    class func setDefaultACL(_ defaultACL: ParseACL?, for user: PCKUser) {
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
                    Logger.initializer.error("Couldn't encode defaultACL from user as string")
                } else {
                    os_log("Couldn't encode defaultACL from user as string",
                           log: .initializer,
                           type: .error)
                }
            }
        } catch {
            if #available(iOS 14.0, watchOS 7.0, *) {
                Logger.initializer.error("Couldn't encode defaultACL from user. \(error.localizedDescription)")
            } else {
                os_log("Couldn't encode defaultACL from user. %{private}@",
                       log: .initializer,
                       type: .error,
                       error.localizedDescription)
            }
        }
    }

    func subscribeToClock() {
        DispatchQueue.main.async {

            guard PCKUser.current != nil,
                  self.subscribeToServerUpdates == true,
                  self.clockSubscription == nil else {
                return
            }

            let clockQuery = PCKClock.query(ClockKey.uuid == self.uuid)
            guard let subscription = clockQuery.subscribeCallback else {
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.clock.error("Couldn't subscribe to clock query")
                } else {
                    os_log("Couldn't subscribe to clock query",
                           log: .clock,
                           type: .error)
                }
                return
            }
            self.clockSubscription = subscription
            self.clockSubscription?.handleEvent { (_, _) in
                self.parseDelegate?.didRequestSynchronization(self)
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger
                        .clock
                        .log("Parse subscription is notifying that there are updates on the server")
                } else {
                    os_log("Parse subscription is notifying that there are updates on the server",
                           log: .clock, type: .info)
                }
            }
        }
    }

    public func pullRevisions(since knowledgeVector: OCKRevisionRecord.KnowledgeVector,
                              mergeRevision: @escaping (OCKRevisionRecord) -> Void,
                              completion: @escaping (Error?) -> Void) {

        guard PCKUser.current != nil else {
            completion(ParseCareKitError.userNotLoggedIn)
            return
        }

        do {
            guard try ParseHealth.check().contains("ok") else {
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.pullRevisions.error("Server health is not \"ok\"")
                } else {
                    os_log("Server health is not \"ok\"", log: .pullRevisions, type: .error)
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

        if isSynchronizing {
            completion(ParseCareKitError.syncAlreadyInProgress)
            return
        }
        isSynchronizing = true

        // Fetch Clock from Cloud
        PCKClock.fetchFromCloud(uuid: self.uuid, createNewIfNeeded: false) { (_, potentialCKClock, _) in
            guard let cloudVector = potentialCKClock else {
                // No Clock available, need to let CareKit know this is the first sync.
                let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
                mergeRevision(revision)
                completion(nil)
                return
            }
            let returnError: Error? = nil

            let localClock = knowledgeVector.clock(for: self.uuid)
            self.subscribeToClock()
            ParseRemote.queue.sync {
                self.pullRevisionsForConcreteClasses(previousError: returnError, localClock: localClock,
                                                     cloudVector: cloudVector,
                                                     mergeRevision: mergeRevision) { previosError in

                    self.pullRevisionsForCustomClasses(previousError: previosError, localClock: localClock,
                                                       cloudVector: cloudVector, mergeRevision: mergeRevision,
                                                       completion: completion)
                }
            }
        }
    }

    func pullRevisionsForConcreteClasses(concreteClassesAlreadyPulled: Int=0, previousError: Error?,
                                         localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector,
                                         mergeRevision: @escaping (OCKRevisionRecord) -> Void,
                                         completion: @escaping (Error?) -> Void) {

        let classNames = PCKStoreClass.patient.orderedArray()
        self.notifyRevisionProgress(concreteClassesAlreadyPulled,
                                    totalEntities: classNames.count)

        guard concreteClassesAlreadyPulled < classNames.count,
            let concreteClass = self.pckStoreClassesToSynchronize[classNames[concreteClassesAlreadyPulled]] else {
            if #available(iOS 14.0, watchOS 7.0, *) {
                Logger.pullRevisions.debug("Finished pulling revisions for default classes")
            } else {
                os_log("Finished pulling revisions for default classes", log: .pullRevisions, type: .debug)
            }
            completion(previousError)
            return
        }

        concreteClass.pullRevisions(since: localClock, cloudClock: cloudVector) { result in

            var currentError = previousError

            switch result {

            case .success(let customRevision):
                mergeRevision(customRevision)

            case .failure(let error):
                currentError = error
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.pullRevisions.error("pullRevisionsForConcreteClasses: \(currentError!.localizedDescription, privacy: .private)")
                } else {
                    os_log("pullRevisionsForConcreteClasses: %{private}@",
                           log: .pullRevisions, type: .error, currentError!.localizedDescription)
                }
            }

            self.pullRevisionsForConcreteClasses(concreteClassesAlreadyPulled: concreteClassesAlreadyPulled+1,
                                                 previousError: currentError, localClock: localClock,
                                                 cloudVector: cloudVector, mergeRevision: mergeRevision,
                                                 completion: completion)
        }
    }

    func pullRevisionsForCustomClasses(customClassesAlreadyPulled: Int=0, previousError: Error?,
                                       localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector,
                                       mergeRevision: @escaping (OCKRevisionRecord) -> Void,
                                       completion: @escaping (Error?) -> Void) {

        if let customClassesToSynchronize = self.customClassesToSynchronize {
            let classNames = customClassesToSynchronize.keys.sorted()
            self.notifyRevisionProgress(customClassesAlreadyPulled,
                                        totalEntities: classNames.count)

            guard customClassesAlreadyPulled < classNames.count,
                let customClass = customClassesToSynchronize[classNames[customClassesAlreadyPulled]] else {
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.pullRevisions.debug("Finished pulling custom revision classes")
                } else {
                    // Fallback on earlier versions
                    os_log("Finished pulling custom revision classes", log: .pullRevisions, type: .debug)
                }
                completion(previousError)
                return
            }

            customClass.pullRevisions(since: localClock, cloudClock: cloudVector) { result in
                var currentError = previousError

                switch result {

                case .success(let customRevision):
                    mergeRevision(customRevision)

                case .failure(let error):
                    currentError = error
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.pullRevisions.error("pullRevisionsForConcreteClasses: \(currentError!.localizedDescription, privacy: .private)")
                    } else {
                        os_log("pullRevisionsForConcreteClasses: %{private}@",
                               log: .pullRevisions, type: .error, currentError!.localizedDescription)
                    }
                }

                self.pullRevisionsForCustomClasses(customClassesAlreadyPulled: customClassesAlreadyPulled+1,
                                                   previousError: previousError, localClock: localClock,
                                                   cloudVector: cloudVector, mergeRevision: mergeRevision,
                                                   completion: completion)
            }
        } else {
            completion(previousError)
        }
    }

    public func pushRevisions(deviceRevision: OCKRevisionRecord,
                              completion: @escaping (Error?) -> Void) {

        guard PCKUser.current != nil else {
            completion(ParseCareKitError.userNotLoggedIn)
            return
        }

        guard deviceRevision.entities.count > 0 else {
            // No revisions need to be pushed
            self.isSynchronizing = false
            self.parseRemoteDelegate?.successfullyPushedDataToCloud()
            completion(nil)
            return
        }

        do {
            guard try ParseHealth.check().contains("ok") else {
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.pushRevisions.error("Server health is not \"ok\"")
                } else {
                    os_log("Server health is not \"ok\"", log: .pushRevisions, type: .error)
                }
                completion(ParseCareKitError.parseHealthError)
                return
            }
        } catch {
            if #available(iOS 14.0, watchOS 7.0, *) {
                Logger.pushRevisions.error("Server health: \(error.localizedDescription)")
            } else {
                os_log("Server health: %{private}@", log: .pushRevisions, type: .error, error.localizedDescription)
            }
            completion(ParseCareKitError.parseHealthError)
            return
        }

        actor RevisionsComplete {
            var count: Int = 0

            func incrementCompleted() {
                count += 1
            }
        }

        ParseRemote.queue.async {
            // Fetch Clock from Cloud
            PCKClock.fetchFromCloud(uuid: self.uuid, createNewIfNeeded: true) { (potentialPCKClock, potentialCKClock, error) in

                guard let cloudParseVector = potentialPCKClock,
                    let cloudCareKitVector = potentialCKClock else {
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

                let cloudVectorClock = cloudCareKitVector.clock(for: self.uuid)

                let revisionsCompleted = RevisionsComplete()
                Task {
                    let count = await revisionsCompleted.count
                    self.notifyRevisionProgress(count,
                                                totalEntities: deviceRevision.entities.count)
                }

                deviceRevision.entities.forEach {
                    let entity = $0
                    switch entity {
                    case .patient(let patient):

                        if let customClassName = patient.userInfo?[CustomKey.customClass] {
                            self.pushRevisionForCustomClass(entity, className: customClassName,
                                                            cloudClock: cloudVectorClock) { error in

                                if error != nil {
                                    completion(error)
                                }
                                Task {
                                    await revisionsCompleted.incrementCompleted()
                                    let revisionsCompletedCount = await revisionsCompleted.count
                                    self.notifyRevisionProgress(revisionsCompletedCount,
                                                                totalEntities: deviceRevision.entities.count)
                                    if revisionsCompletedCount == deviceRevision.entities.count {
                                        self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                               localClock: deviceRevision.knowledgeVector,
                                                               completion: completion)
                                    }
                                }
                            }
                        } else {

                            guard let parse = try? self.pckStoreClassesToSynchronize[.patient]?.new(with: entity) else {
                                completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                                return
                            }

                            parse.pushRevision(cloudClock: cloudVectorClock) { error in

                                if error != nil {
                                    completion(error)
                                }
                                Task {
                                    await revisionsCompleted.incrementCompleted()
                                    let revisionsCompletedCount = await revisionsCompleted.count
                                    self.notifyRevisionProgress(revisionsCompletedCount,
                                                                totalEntities: deviceRevision.entities.count)
                                    if revisionsCompletedCount == deviceRevision.entities.count {
                                        self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                               localClock: deviceRevision.knowledgeVector,
                                                               completion: completion)
                                    }
                                }
                            }
                        }

                    case .carePlan(let carePlan):
                        if let customClassName = carePlan.userInfo?[CustomKey.customClass] {
                            self.pushRevisionForCustomClass(entity, className: customClassName,
                                                            cloudClock: cloudVectorClock) { error in

                                if error != nil {
                                    completion(error)
                                }
                                Task {
                                    await revisionsCompleted.incrementCompleted()
                                    let revisionsCompletedCount = await revisionsCompleted.count
                                    self.notifyRevisionProgress(revisionsCompletedCount,
                                                                totalEntities: deviceRevision.entities.count)
                                    if revisionsCompletedCount == deviceRevision.entities.count {
                                        self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                               localClock: deviceRevision.knowledgeVector,
                                                               completion: completion)
                                    }
                                }
                            }
                        } else {

                            guard let parse = try? self.pckStoreClassesToSynchronize[.carePlan]?.new(with: entity) else {
                                completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                                return
                            }

                            parse.pushRevision(cloudClock: cloudVectorClock) { error in

                                if error != nil {
                                    completion(error)
                                }
                                Task {
                                    await revisionsCompleted.incrementCompleted()
                                    let revisionsCompletedCount = await revisionsCompleted.count
                                    self.notifyRevisionProgress(revisionsCompletedCount,
                                                                totalEntities: deviceRevision.entities.count)
                                    if revisionsCompletedCount == deviceRevision.entities.count {
                                        self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                               localClock: deviceRevision.knowledgeVector,
                                                               completion: completion)
                                    }
                                }
                            }
                        }
                    case .contact(let contact):
                        if let customClassName = contact.userInfo?[CustomKey.customClass] {
                            self.pushRevisionForCustomClass(entity, className: customClassName,
                                                            cloudClock: cloudVectorClock) { error in

                                if error != nil {
                                    completion(error)
                                }
                                Task {
                                    await revisionsCompleted.incrementCompleted()
                                    let revisionsCompletedCount = await revisionsCompleted.count
                                    self.notifyRevisionProgress(revisionsCompletedCount,
                                                                totalEntities: deviceRevision.entities.count)
                                    if revisionsCompletedCount == deviceRevision.entities.count {
                                        self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                               localClock: deviceRevision.knowledgeVector,
                                                               completion: completion)
                                    }
                                }
                            }
                        } else {
                            guard let parse = try? self.pckStoreClassesToSynchronize[.contact]?.new(with: entity) else {
                                completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                                return
                            }
                            parse.pushRevision(cloudClock: cloudVectorClock) { error in

                                if error != nil {
                                    completion(error)
                                }
                                Task {
                                    await revisionsCompleted.incrementCompleted()
                                    let revisionsCompletedCount = await revisionsCompleted.count
                                    self.notifyRevisionProgress(revisionsCompletedCount,
                                                                totalEntities: deviceRevision.entities.count)
                                    if revisionsCompletedCount == deviceRevision.entities.count {
                                        self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                               localClock: deviceRevision.knowledgeVector,
                                                               completion: completion)
                                    }
                                }
                            }
                        }
                    case .task(let task):
                        if let customClassName = task.userInfo?[CustomKey.customClass] {
                            self.pushRevisionForCustomClass(entity, className: customClassName,
                                                            cloudClock: cloudVectorClock) { error in

                                if error != nil {
                                    completion(error)
                                }
                                Task {
                                    await revisionsCompleted.incrementCompleted()
                                    let revisionsCompletedCount = await revisionsCompleted.count
                                    self.notifyRevisionProgress(revisionsCompletedCount,
                                                                totalEntities: deviceRevision.entities.count)
                                    if revisionsCompletedCount == deviceRevision.entities.count {
                                        self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                               localClock: deviceRevision.knowledgeVector,
                                                               completion: completion)
                                    }
                                }
                            }
                        } else {
                            guard let parse = try? self.pckStoreClassesToSynchronize[.task]?.new(with: entity) else {
                                completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                                return
                            }

                            parse.pushRevision(cloudClock: cloudVectorClock) { error in

                                if error != nil {
                                    completion(error)
                                }
                                Task {
                                    await revisionsCompleted.incrementCompleted()
                                    let revisionsCompletedCount = await revisionsCompleted.count
                                    self.notifyRevisionProgress(revisionsCompletedCount,
                                                                totalEntities: deviceRevision.entities.count)
                                    if revisionsCompletedCount == deviceRevision.entities.count {
                                        self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                               localClock: deviceRevision.knowledgeVector,
                                                               completion: completion)
                                    }
                                }
                            }
                        }
                    case .outcome(let outcome):

                        if let customClassName = outcome.userInfo?[CustomKey.customClass] {
                            self.pushRevisionForCustomClass(entity, className: customClassName,
                                                            cloudClock: cloudVectorClock) { error in
                                if error != nil {
                                    completion(error)
                                }
                                Task {
                                    await revisionsCompleted.incrementCompleted()
                                    let revisionsCompletedCount = await revisionsCompleted.count
                                    self.notifyRevisionProgress(revisionsCompletedCount,
                                                                totalEntities: deviceRevision.entities.count)
                                    if revisionsCompletedCount == deviceRevision.entities.count {
                                        self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                               localClock: deviceRevision.knowledgeVector,
                                                               completion: completion)
                                    }
                                }
                            }
                        } else {
                            guard let parse = try? self.pckStoreClassesToSynchronize[.outcome]?.new(with: entity) else {
                                completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                                return
                            }
                            parse.pushRevision(cloudClock: cloudVectorClock) { error in
                                if error != nil {
                                    completion(error)
                                }
                                Task {
                                    await revisionsCompleted.incrementCompleted()
                                    let revisionsCompletedCount = await revisionsCompleted.count
                                    self.notifyRevisionProgress(revisionsCompletedCount,
                                                                totalEntities: deviceRevision.entities.count)
                                    if revisionsCompletedCount == deviceRevision.entities.count {
                                        self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                               localClock: deviceRevision.knowledgeVector,
                                                               completion: completion)
                                    }
                                }
                            }
                        }
                    case .healthKitTask(let healthKit):
                        if let customClassName = healthKit.userInfo?[CustomKey.customClass] {
                            self.pushRevisionForCustomClass(entity, className: customClassName,
                                                            cloudClock: cloudVectorClock) { error in

                                if error != nil {
                                    completion(error)
                                }
                                Task {
                                    await revisionsCompleted.incrementCompleted()
                                    let revisionsCompletedCount = await revisionsCompleted.count
                                    self.notifyRevisionProgress(revisionsCompletedCount,
                                                                totalEntities: deviceRevision.entities.count)
                                    if revisionsCompletedCount == deviceRevision.entities.count {
                                        self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                               localClock: deviceRevision.knowledgeVector,
                                                               completion: completion)
                                    }
                                }
                            }
                        } else {
                            guard let parse = try? self.pckStoreClassesToSynchronize[.healthKitTask]?.new(with: entity) else {
                                completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                                return
                            }

                            parse.pushRevision(cloudClock: cloudVectorClock) { error in

                                if error != nil {
                                    completion(error)
                                }
                                Task {
                                    await revisionsCompleted.incrementCompleted()
                                    let revisionsCompletedCount = await revisionsCompleted.count
                                    self.notifyRevisionProgress(revisionsCompletedCount,
                                                                totalEntities: deviceRevision.entities.count)
                                    if revisionsCompletedCount == deviceRevision.entities.count {
                                        self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                               localClock: deviceRevision.knowledgeVector,
                                                               completion: completion)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func pushRevisionForCustomClass(_ entity: OCKEntity, className: String, cloudClock: Int, completion: @escaping (Error?) -> Void) {
        guard let customClass = self.customClassesToSynchronize?[className] else {
            completion(ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }

        guard let parse = try? customClass.new(with: entity) else {
            completion(ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        parse.pushRevision(cloudClock: cloudClock) { error in
            completion(error)
        }
    }

    func finishedRevisions(_ parseClock: PCKClock, cloudClock: OCKRevisionRecord.KnowledgeVector,
                           localClock: OCKRevisionRecord.KnowledgeVector,
                           completion: @escaping (Error?) -> Void) {
        var cloudVector = cloudClock
        // Increment and merge Knowledge Vector
        cloudVector.increment(clockFor: uuid)
        cloudVector.merge(with: localClock)

        guard let updatedClock = parseClock.encodeClock(cloudVector) else {
            completion(ParseCareKitError.couldntUnwrapClock)
            return
        }
        updatedClock.save(callbackQueue: ParseRemote.queue) { result in
            self.isSynchronizing = false
            switch result {

            case .success:
                self.parseRemoteDelegate?.successfullyPushedDataToCloud()
                completion(nil)
            case .failure(let error):
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.pushRevisions.error("finishedRevisions: \(error.localizedDescription, privacy: .private)")
                } else {
                    os_log("finishedRevisions: %{private}@",
                           log: .pushRevisions, type: .error, error.localizedDescription)
                }
                completion(error)
            }
        }
    }

    func notifyRevisionProgress(_ numberCompleted: Int, totalEntities: Int) {
        if totalEntities > 0 {
            let ratioComplete = Double(numberCompleted)/Double(totalEntities)
            self.parseDelegate?.remote(self, didUpdateProgress: ratioComplete)
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
        parseDelegate
            .chooseConflictResolution(conflicts: conflicts,
                                      completion: completion)
    }
}
