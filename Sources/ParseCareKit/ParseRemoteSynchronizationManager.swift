//
//  ParseRemoteSynchronizationManager.swift
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
public class ParseRemoteSynchronizationManager: OCKRemoteSynchronizable {

    public weak var delegate: OCKRemoteSynchronizationDelegate?

    /// If set, the delegate will be alerted to important events delivered by the remote
    /// store (set this, don't set `delegate`).
    public weak var parseRemoteDelegate: ParseRemoteSynchronizationDelegate? {
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
    /// are `Patient`, `Task`, `CarePlan`, `Contact`, and `Outcome`.
    public var pckStoreClassesToSynchronize: [PCKStoreClass: PCKSynchronizable]!

    private weak var parseDelegate: ParseRemoteSynchronizationDelegate?
    private var clockSubscription: Subscription<Query<Clock>, Clock>?
    private var subscribeToServerUpdates: Bool
    static let queue = DispatchQueue(label: "edu.netreconlab.parsecarekit",
                                                     qos: .default,
                                                     attributes: .concurrent,
                                                     autoreleaseFrequency: .inherit,
                                                     target: nil)
    /**
     Creates an instance of ParseRemoteSynchronizationManager.
     - Parameters:
        - uuid: The unique identifier of the remote clock.
        - auto: If set to `true`, then the store will attempt to synchronize every time it is modified locally.
        - subscribeToServerUpdates: Automatically receive updates from other devices linked to this Clock.
     Requires `ParseLiveQuery` server to be setup.
    */
    public init(uuid: UUID, auto: Bool, subscribeToServerUpdates: Bool) throws {
        self.pckStoreClassesToSynchronize = try PCKStoreClass.patient.getConcrete()
        self.customClassesToSynchronize = nil
        self.uuid = uuid
        self.automaticallySynchronizes = auto
        self.subscribeToServerUpdates = subscribeToServerUpdates
        if PCKUser.current != nil {
            subscribeToClock()
        }
    }

    /**
     Creates an instance of ParseRemoteSynchronizationManager.
     - Parameters:
        - uuid: The unique identifier of the remote clock.
        - auto: If set to `true`, then the store will attempt to synchronize every time it is modified locally.
        - replacePCKStoreClasses: Replace some or all of the default classes that are synchronized
        - subscribeToServerUpdates: Automatically receive updates from other devices linked to this Clock.
     Requires `ParseLiveQuery` server to be setup.
    */
    convenience public init(uuid: UUID, auto: Bool, replacePCKStoreClasses: [PCKStoreClass: PCKSynchronizable], subscribeToServerUpdates: Bool) throws {
        try self.init(uuid: uuid, auto: auto, subscribeToServerUpdates: subscribeToServerUpdates)
        try self.pckStoreClassesToSynchronize = PCKStoreClass
            .patient.replaceRemoteConcreteClasses(replacePCKStoreClasses)
        self.customClassesToSynchronize = nil
    }

    /**
     Creates an instance of ParseRemoteSynchronizationManager.
     - Parameters:
        - uuid: The unique identifier of the remote clock.
        - auto: If set to `true`, then the store will attempt to synchronize every time it is modified locally.
        - replacePCKStoreClasses: Replace some or all of the default classes that are synchronized
            by passing in the respective Key/Value pairs. Defaults to nil, which uses the standard default entities.
        - customClasses: Add custom classes to synchroniz by passing in the respective Key/Value pair.
        - subscribeToServerUpdates: Automatically receive updates from other devices linked to this Clock.
     Requires `ParseLiveQuery` server to be setup.
    */
    convenience public init(uuid: UUID, auto: Bool,
                            replacePCKStoreClasses: [PCKStoreClass: PCKSynchronizable]? = nil,
                            customClasses: [String: PCKSynchronizable], subscribeToServerUpdates: Bool) throws {
        try self.init(uuid: uuid, auto: auto, subscribeToServerUpdates: subscribeToServerUpdates)
        if replacePCKStoreClasses != nil {
            self.pckStoreClassesToSynchronize = try PCKStoreClass
                .patient.replaceRemoteConcreteClasses(replacePCKStoreClasses!)
        } else {
            self.pckStoreClassesToSynchronize = nil
        }
        self.customClassesToSynchronize = customClasses
    }

    func subscribeToClock() {
        if self.subscribeToServerUpdates && self.clockSubscription == nil {
            let clockQuery = Clock.query(ClockKey.uuid == self.uuid)
            guard let subscription = clockQuery.subscribe else {
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.clock.error("Couldn't subscribe to clock query.")
                } else {
                    os_log("Couldn't subscribe to clock query",
                           log: .clock,
                           type: .error)
                }
                return
            }
            self.clockSubscription = subscription
            self.clockSubscription!.handleEvent { (_, _) in
                self.parseDelegate?.didRequestSynchronization(self)
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger
                        .clock
                        .log("Parse subscription is notifying that there are updates on the server.")
                } else {
                    os_log("Parse subscription is notifying that there are updates on the server.",
                           log: .clock, type: .info)
                }
            }
        }
    }

    public func pullRevisions(since clock: OCKRevisionRecord.KnowledgeVector,
                              mergeRevision: @escaping (OCKRevisionRecord, @escaping (Error?) -> Void) -> Void,
                              completion: @escaping (Error?) -> Void) {

        guard PCKUser.current != nil else {
            completion(ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }

        ParseRemoteSynchronizationManager.queue.async {
            //Fetch Clock from Cloud
            Clock.fetchFromCloud(uuid: self.uuid, createNewIfNeeded: false) { (_, potentialCKClock, _) in
                guard let cloudVector = potentialCKClock else {
                    //No Clock available, need to let CareKit know this is the first sync.
                    let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
                    mergeRevision(revision, completion)
                    return
                }
                let returnError: Error? = nil

                let localClock = clock.clock(for: self.uuid)
                self.subscribeToClock()
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
                                         mergeRevision: @escaping (OCKRevisionRecord,
                                                                   @escaping (Error?) -> Void) -> Void,
                                         completion: @escaping (Error?) -> Void) {

        let classNames = PCKStoreClass.patient.orderedArray()
        if classNames.count > 0 {
            let ratioComplete = Double(concreteClassesAlreadyPulled)/Double(classNames.count)
            self.parseDelegate?.remote(self, didUpdateProgress: ratioComplete)
            if #available(iOS 14.0, watchOS 7.0, *) {
                Logger.pullRevisions.info("pullRevisionsForConcreteClasses progress: \(ratioComplete, privacy: .private)")
            } else {
                os_log("pullRevisionsForConcreteClasses progress: %{private}@.",
                       log: .pullRevisions, type: .default, ratioComplete)
            }
        }

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
        var currentError = previousError
        concreteClass.pullRevisions(since: localClock, cloudClock: cloudVector) { customRevision in
            mergeRevision(customRevision) { error in
                if error != nil {
                    currentError = error!
                    if #available(iOS 14.0, watchOS 7.0, *) {
                        Logger.pullRevisions.error("pullRevisionsForConcreteClasses: \(currentError!.localizedDescription, privacy: .private)")
                    } else {
                        os_log("pullRevisionsForConcreteClasses: %{private}@.",
                               log: .pullRevisions, type: .error, currentError!.localizedDescription)
                    }
                }

                self.pullRevisionsForConcreteClasses(concreteClassesAlreadyPulled: concreteClassesAlreadyPulled+1,
                                                     previousError: currentError, localClock: localClock,
                                                     cloudVector: cloudVector, mergeRevision: mergeRevision,
                                                     completion: completion)

            }
        }
    }

    func pullRevisionsForCustomClasses(customClassesAlreadyPulled: Int=0, previousError: Error?,
                                       localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector,
                                       mergeRevision: @escaping (OCKRevisionRecord,
                                                                 @escaping (Error?) -> Void) -> Void,
                                       completion: @escaping (Error?) -> Void) {

        if let customClassesToSynchronize = self.customClassesToSynchronize {
            let classNames = customClassesToSynchronize.keys.sorted()

            if classNames.count > 0 {
                let ratioComplete = Double(customClassesAlreadyPulled)/Double(classNames.count)
                self.parseDelegate?.remote(self, didUpdateProgress: ratioComplete)
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.pullRevisions.info("pullRevisionsForCustomClasses progress: \(ratioComplete, privacy: .private)")
                } else {
                    os_log("pullRevisionsForCustomClasses progress: %{private}@.",
                           log: .pullRevisions, type: .default, ratioComplete)
                }
            }

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
            var currentError = previousError
            customClass.pullRevisions(since: localClock, cloudClock: cloudVector) { customRevision in
                mergeRevision(customRevision) { error in
                    if error != nil {
                        currentError = error!
                        if #available(iOS 14.0, watchOS 7.0, *) {
                            Logger.pullRevisions.error("pullRevisionsForCustomClasses: \(currentError!.localizedDescription, privacy: .private)")
                        } else {
                            // Fallback on earlier versions
                            os_log("pullRevisionsForCustomClasses: %{private}@.",
                                   log: .pullRevisions, type: .error, currentError!.localizedDescription)
                        }
                    }

                    self.pullRevisionsForCustomClasses(customClassesAlreadyPulled: customClassesAlreadyPulled+1,
                                                       previousError: currentError, localClock: localClock,
                                                       cloudVector: cloudVector, mergeRevision: mergeRevision,
                                                       completion: completion)
                }
            }
        } else {
            completion(previousError)
        }
    }

    public func pushRevisions(deviceRevision: OCKRevisionRecord,
                              overwriteRemote: Bool, completion: @escaping (Error?) -> Void) {

        guard PCKUser.current != nil else {
            completion(ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }

        guard deviceRevision.entities.count > 0 else {
            //No revisions need to be pushed
            completion(nil)
            return
        }

        ParseRemoteSynchronizationManager.queue.async {
            //Fetch Clock from Cloud
            Clock.fetchFromCloud(uuid: self.uuid, createNewIfNeeded: true) { (potentialPCKClock, potentialCKClock, error) in

                guard let cloudParseVector = potentialPCKClock,
                    let cloudCareKitVector = potentialCKClock else {

                        guard let parseError = error else {
                            //There was a different issue that we don't know how to handle
                            if let error = error {
                                if #available(iOS 14.0, watchOS 7.0, *) {
                                    Logger.pushRevisions.error("\(error.localizedDescription, privacy: .private)")
                                } else {
                                    os_log("%{private}@.", log: .pushRevisions, type: .error, error.localizedDescription)
                                }
                            } else {
                                if #available(iOS 14.0, watchOS 7.0, *) {
                                    Logger.pushRevisions.error("Error in pushRevisions.")
                                } else {
                                    os_log("Error in pushRevisions.", log: .pushRevisions, type: .error)
                                }
                            }
                            return
                        }

                        switch parseError.code {
                        case .internalServer, .objectNotFound:
                            //1 - this column hasn't been added. 101 - Query returned no results
                            if potentialPCKClock != nil {
                                potentialPCKClock!.save(callbackQueue: ParseRemoteSynchronizationManager.queue) { _ in
                                    if #available(iOS 14.0, watchOS 7.0, *) {
                                        Logger.pushRevisions.error("Saved Clock. Try to sync again \(potentialPCKClock!.debugDescription, privacy: .private).")
                                    } else {
                                        os_log("Saved Clock. Try to sync again. %{private}@.",
                                               log: .pushRevisions, type: .debug, potentialPCKClock!.debugDescription)
                                    }
                                    completion(error)
                                }
                            } else {
                                completion(error)
                            }
                        default:
                            //There was a different issue that we don't know how to handle
                            if #available(iOS 14.0, watchOS 7.0, *) {
                                Logger.pushRevisions.error("\(parseError.localizedDescription, privacy: .private)")
                            } else {
                                os_log("%{private}@.", log: .pushRevisions, type: .error, parseError.localizedDescription)
                            }
                            completion(error)
                        }
                    return
                }

                let cloudVectorClock = cloudCareKitVector.clock(for: self.uuid)
                var revisionsCompletedCount = 0
                deviceRevision.entities.forEach {
                    if deviceRevision.entities.count > 0 {
                        let ratioComplete = Double(revisionsCompletedCount)/Double(deviceRevision.entities.count)
                        self.parseDelegate?.remote(self, didUpdateProgress: ratioComplete)
                        if #available(iOS 14.0, watchOS 7.0, *) {
                            Logger.pullRevisions.info("pushRevisions progress: \(ratioComplete, privacy: .private)")
                        } else {
                            os_log("pushRevisions progress: %{private}@.",
                                   log: .pullRevisions, type: .default, ratioComplete)
                        }
                    }
                    let entity = $0
                    switch entity {
                    case .patient(let patient):

                        if let customClassName = patient.userInfo?[CustomKey.customClass] {
                            self.pushRevisionForCustomClass(entity, className: customClassName,
                                                            cloudClock: cloudVectorClock,
                                                            overwriteRemote: overwriteRemote) { error in

                                if error != nil {
                                    completion(error)
                                }
                                revisionsCompletedCount += 1
                                if revisionsCompletedCount == deviceRevision.entities.count {
                                    self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                           localClock: deviceRevision.knowledgeVector,
                                                           completion: completion)
                                }
                            }
                        } else {

                            guard let parse = try? self.pckStoreClassesToSynchronize[.patient]?.new(with: entity) else {
                                completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                                return
                            }

                            parse.pushRevision(cloudClock: cloudVectorClock,
                                               overwriteRemote: overwriteRemote) { error in

                                if error != nil {
                                    completion(error)
                                }
                                revisionsCompletedCount += 1
                                if revisionsCompletedCount == deviceRevision.entities.count {
                                    self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                           localClock: deviceRevision.knowledgeVector,
                                                           completion: completion)
                                }
                            }
                        }

                    case .carePlan(let carePlan):
                        if let customClassName = carePlan.userInfo?[CustomKey.customClass] {
                            self.pushRevisionForCustomClass(entity, className: customClassName,
                                                            cloudClock: cloudVectorClock,
                                                            overwriteRemote: overwriteRemote) { error in

                                if error != nil {
                                    completion(error)
                                }
                                revisionsCompletedCount += 1
                                if revisionsCompletedCount == deviceRevision.entities.count {
                                    self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                           localClock: deviceRevision.knowledgeVector,
                                                           completion: completion)
                                }
                            }
                        } else {

                            guard let parse = try?  self.pckStoreClassesToSynchronize[.carePlan]?.new(with: entity) else {
                                completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                                return
                            }

                            parse.pushRevision(cloudClock: cloudVectorClock, overwriteRemote: overwriteRemote) { error in

                                if error != nil {
                                    completion(error)
                                }
                                revisionsCompletedCount += 1
                                if revisionsCompletedCount == deviceRevision.entities.count {
                                    self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                           localClock: deviceRevision.knowledgeVector,
                                                           completion: completion)
                                }
                            }
                        }
                    case .contact(let contact):
                        if let customClassName = contact.userInfo?[CustomKey.customClass] {
                            self.pushRevisionForCustomClass(entity, className: customClassName,
                                                            cloudClock: cloudVectorClock,
                                                            overwriteRemote: overwriteRemote) { error in

                                if error != nil {
                                    completion(error)
                                }
                                revisionsCompletedCount += 1
                                if revisionsCompletedCount == deviceRevision.entities.count {
                                    self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                           localClock: deviceRevision.knowledgeVector,
                                                           completion: completion)
                                }
                            }
                        } else {
                            guard let parse = try?  self.pckStoreClassesToSynchronize[.contact]?.new(with: entity) else {
                                completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                                return
                            }
                            parse.pushRevision(cloudClock: cloudVectorClock, overwriteRemote: overwriteRemote) { error in

                                if error != nil {
                                    completion(error)
                                }
                                revisionsCompletedCount += 1
                                if revisionsCompletedCount == deviceRevision.entities.count {

                                    self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                           localClock: deviceRevision.knowledgeVector,
                                                           completion: completion)
                                }
                            }
                        }
                    case .task(let task):
                        if let customClassName = task.userInfo?[CustomKey.customClass] {
                            self.pushRevisionForCustomClass(entity, className: customClassName,
                                                            cloudClock: cloudVectorClock,
                                                            overwriteRemote: overwriteRemote) { error in

                                if error != nil {
                                    completion(error)
                                }
                                revisionsCompletedCount += 1
                                if revisionsCompletedCount == deviceRevision.entities.count {
                                    self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                           localClock: deviceRevision.knowledgeVector,
                                                           completion: completion)
                                }
                            }
                        } else {
                            guard let parse = try?  self.pckStoreClassesToSynchronize[.task]?.new(with: entity) else {
                                completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                                return
                            }

                            parse.pushRevision(cloudClock: cloudVectorClock,
                                               overwriteRemote: overwriteRemote) { error in

                                if error != nil {
                                    completion(error)
                                }
                                revisionsCompletedCount += 1
                                if revisionsCompletedCount == deviceRevision.entities.count {
                                    self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                           localClock: deviceRevision.knowledgeVector,
                                                           completion: completion)
                                }
                            }

                        }
                    case .outcome(let outcome):

                        if let customClassName = outcome.userInfo?[CustomKey.customClass] {
                            self.pushRevisionForCustomClass(entity, className: customClassName,
                                                            cloudClock: cloudVectorClock,
                                                            overwriteRemote: overwriteRemote) { error in
                                if error != nil {
                                    completion(error)
                                }
                                revisionsCompletedCount += 1
                                if revisionsCompletedCount == deviceRevision.entities.count {
                                    self.finishedRevisions(cloudParseVector, cloudClock: cloudCareKitVector,
                                                           localClock: deviceRevision.knowledgeVector,
                                                           completion: completion)
                                }
                            }
                        } else {
                            guard let parse = try?  self.pckStoreClassesToSynchronize[.outcome]?.new(with: entity) else {
                                completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                                return
                            }
                            parse.pushRevision(cloudClock: cloudVectorClock, overwriteRemote: overwriteRemote) { error in
                                if error != nil {
                                    completion(error)
                                }
                                revisionsCompletedCount += 1
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

    func pushRevisionForCustomClass(_ entity: OCKEntity, className: String, cloudClock: Int,
                                    overwriteRemote: Bool, completion: @escaping (Error?) -> Void) {
        guard let customClass = self.customClassesToSynchronize?[className] else {
            completion(ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }

        guard let parse = try? customClass.new(with: entity) else {
            completion(ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        parse.pushRevision(cloudClock: cloudClock, overwriteRemote: overwriteRemote) { error in
            completion(error)
        }
    }

    func finishedRevisions(_ parseClock: Clock, cloudClock: OCKRevisionRecord.KnowledgeVector,
                           localClock: OCKRevisionRecord.KnowledgeVector,
                           completion: @escaping (Error?) -> Void) {
        var parseClock = parseClock
        var cloudVector = cloudClock
        //Increment and merge Knowledge Vector
        cloudVector.increment(clockFor: uuid)
        cloudVector.merge(with: localClock)

        guard parseClock.encodeClock(cloudVector) != nil else {
            completion(ParseCareKitError.couldntUnwrapClock)
            return
        }
        parseClock.save(callbackQueue: ParseRemoteSynchronizationManager.queue) { result in
            switch result {

            case .success:
                completion(nil)
            case .failure(let error):
                if #available(iOS 14.0, watchOS 7.0, *) {
                    Logger.pushRevisions.error("finishedRevisions: \(error.localizedDescription, privacy: .private)")
                } else {
                    os_log("finishedRevisions: %{private}@.",
                           log: .pushRevisions, type: .error, error.localizedDescription)
                }
                completion(error)
            }
        }
    }

    public func chooseConflictResolutionPolicy(_ conflict: OCKMergeConflictDescription,
                                               completion: @escaping (OCKMergeConflictResolutionPolicy) -> Void) {
        if let parseDelegate = parseDelegate {
            parseDelegate.chooseConflictResolutionPolicy(conflict, completion: completion)
        } else {
            let conflictPolicy = OCKMergeConflictResolutionPolicy.keepRemote
            completion(conflictPolicy)
        }
    }
}
