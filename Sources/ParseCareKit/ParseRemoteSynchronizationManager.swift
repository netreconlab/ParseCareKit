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

typealias SynchronizedType = PCKSynchronizable

/**
Protocol that defines the properties to conform to when updates a needed and conflict resolution.
*/
public protocol ParseRemoteSynchronizationDelegate: OCKRemoteSynchronizationDelegate {
    func chooseConflictResolutionPolicy(_ conflict: OCKMergeConflictDescription, completion: @escaping (OCKMergeConflictResolutionPolicy) -> Void)
    func storeUpdatedOutcome(_ outcome: OCKOutcome)
    func storeUpdatedCarePlan(_ carePlan: OCKCarePlan)
    func storeUpdatedContact(_ contact: OCKContact)
    func storeUpdatedPatient(_ patient: OCKPatient)
    func storeUpdatedTask(_ task: OCKTask)
    func successfullyPushedDataToCloud()
}

public class ParseRemoteSynchronizationManager: OCKRemoteSynchronizable {
    public var delegate: OCKRemoteSynchronizationDelegate?
    public var parseRemoteDelegate: ParseRemoteSynchronizationDelegate? {
        set{
            parseDelegate = newValue
            delegate = newValue
        }get{
            return parseDelegate
        }
    }
    public var automaticallySynchronizes: Bool
    public internal(set) var uuid:UUID!
    public internal(set) var customClassesToSynchronize:[String: PCKSynchronizable]?
    public internal(set) var pckStoreClassesToSynchronize: [PCKStoreClass: PCKSynchronizable]!
    private var parseDelegate: ParseRemoteSynchronizationDelegate?
    
    public init(uuid:UUID, auto: Bool) {
        self.uuid = uuid
        self.automaticallySynchronizes = auto
        self.pckStoreClassesToSynchronize = PCKStoreClass.patient.getConcrete()
        self.customClassesToSynchronize = nil
    }
    
    convenience public init(uuid:UUID, auto: Bool, replacePCKStoreClasses: [PCKStoreClass: PCKSynchronizable]) {
        self.init(uuid: uuid, auto: auto)
        self.pckStoreClassesToSynchronize = PCKStoreClass.patient.replaceRemoteConcreteClasses(replacePCKStoreClasses)
        self.customClassesToSynchronize = nil
    }
    
    convenience public init(uuid:UUID, auto: Bool, replacePCKStoreClasses: [PCKStoreClass: PCKSynchronizable]?, customClasses: [String:PCKSynchronizable]){
        self.init(uuid: uuid, auto: auto)
        if replacePCKStoreClasses != nil{
            self.pckStoreClassesToSynchronize = PCKStoreClass.patient.replaceRemoteConcreteClasses(replacePCKStoreClasses!)
        }else{
            self.pckStoreClassesToSynchronize = nil
        }
        self.customClassesToSynchronize = customClasses
    }
    
    public func pullRevisions(since knowledgeVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord, @escaping (Error?) -> Void) -> Void, completion: @escaping (Error?) -> Void) {
        
        guard let _ = PCKUser.current else{
            let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
            mergeRevision(revision){
                error in
                completion(error)
            }
            return
        }
        
        //Fetch KnowledgeVector from Cloud
        KnowledgeVector.fetchFromCloud(uuid: uuid, createNewIfNeeded: false){
            (_, potentialCKKnowledgeVector, error) in
            guard let cloudVector = potentialCKKnowledgeVector else{
                //No KnowledgeVector available, need to let CareKit know this is the first sync.
                let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
                mergeRevision(revision,completion)
                return
            }
            let returnError:Error? = nil
            
            let localClock = knowledgeVector.clock(for: self.uuid)
            
            self.pullRevisionsForConcreteClasses(previousError: returnError, localClock: localClock, cloudVector: cloudVector, mergeRevision: mergeRevision){previosError in
                    
                self.pullRevisionsForCustomClasses(previousError: previosError, localClock: localClock, cloudVector: cloudVector, mergeRevision: mergeRevision, completion: completion)
            }
        }
    }
    
    func pullRevisionsForConcreteClasses(concreteClassesAlreadyPulled:Int=0, previousError: Error?, localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord, @escaping (Error?) -> Void) -> Void, completion: @escaping (Error?) -> Void){
        
        let classNames = PCKStoreClass.patient.orderedArray()
        
        guard concreteClassesAlreadyPulled < classNames.count,
            let concreteClass = self.pckStoreClassesToSynchronize[classNames[concreteClassesAlreadyPulled]] else{
                print("Finished pulling default revision classes")
                completion(previousError)
                return
        }
        let newConcreteClass = concreteClass.new()
        var currentError = previousError
        newConcreteClass.pullRevisions(localClock, cloudVector: cloudVector){
            customRevision in
            mergeRevision(customRevision){
                error in
                if error != nil {
                    currentError = error!
                    print("Error in ParseCareKit.pullRevisionsForConcreteClasses(). \(currentError!)")
                }
                
                self.pullRevisionsForConcreteClasses(concreteClassesAlreadyPulled: concreteClassesAlreadyPulled+1, previousError: currentError, localClock: localClock, cloudVector: cloudVector, mergeRevision: mergeRevision, completion: completion)
                
            }
        }
    }
    
    func pullRevisionsForCustomClasses(customClassesAlreadyPulled:Int=0, previousError: Error?, localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord, @escaping (Error?) -> Void) -> Void, completion: @escaping (Error?) -> Void){
        if let customClassesToSynchronize = self.customClassesToSynchronize{
            let classNames = customClassesToSynchronize.keys.sorted()
            
            guard customClassesAlreadyPulled < classNames.count,
                let customClass = customClassesToSynchronize[classNames[customClassesAlreadyPulled]] else{
                    print("Finished pulling custom revision classes")
                    completion(previousError)
                    return
            }
            let newCustomClass = customClass.new()
            var currentError = previousError
            newCustomClass.pullRevisions(localClock, cloudVector: cloudVector){
                customRevision in
                mergeRevision(customRevision){
                    error in
                    if error != nil {
                        currentError = error!
                        print("Error in ParseCareKit.pullRevisionsForCustomClasses(). \(currentError!)")
                    }
                    
                    self.pullRevisionsForCustomClasses(customClassesAlreadyPulled: customClassesAlreadyPulled+1, previousError: currentError, localClock: localClock, cloudVector: cloudVector, mergeRevision: mergeRevision, completion: completion)
                }
            }
        }else{
            completion(previousError)
        }
    }
    
    public func pushRevisions(deviceRevision: OCKRevisionRecord, overwriteRemote: Bool, completion: @escaping (Error?) -> Void) {
        
        guard let _ = PCKUser.current else{
            completion(ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        guard deviceRevision.entities.count > 0 else{
            //No revisions need to be pushed
            completion(nil)
            return
        }
        
        //Fetch KnowledgeVector from Cloud
        KnowledgeVector.fetchFromCloud(uuid: uuid, createNewIfNeeded: true){
            (potentialPCKKnowledgeVector, potentialCKKnowledgeVector, error) in
        
            guard let cloudParseVector = potentialPCKKnowledgeVector,
                let cloudCareKitVector = potentialCKKnowledgeVector else{
                    
                    guard let parseError = error else{
                        //There was a different issue that we don't know how to handle
                        print("Error in ParseRemoteSynchronizationManager.pushRevisions() \(String(describing: error?.localizedDescription))")
                        return
                    }
                    
                    switch parseError.code{
                    case .internalServer, .objectNotFound: //1 - this column hasn't been added. 101 - Query returned no results
                        if potentialPCKKnowledgeVector != nil{
                            potentialPCKKnowledgeVector!.save(callbackQueue: .global(qos: .background)) {
                                _ in
                                print("Saved KnowledgeVector. Try to sync again \(potentialPCKKnowledgeVector!)")
                                completion(error)
                            }
                        }else{
                            completion(error)
                        }
                    default:
                        //There was a different issue that we don't know how to handle
                        print("Error in ParseRemoteSynchronizationManager.pushRevisions() \(parseError.localizedDescription)")
                        completion(error)
                    }
                return
            }
            
            let cloudVectorClock = cloudCareKitVector.clock(for: self.uuid)
            var revisionsCompletedCount = 0
            deviceRevision.entities.forEach{
                let entity = $0
                switch entity{
                case .patient(let patient):
                    
                    if let customClassName = patient.userInfo?[kPCKCustomClassKey] {
                        self.pushRevisionForCustomClass(entity, className: customClassName, overwriteRemote: overwriteRemote, cloudClock: cloudVectorClock){
                            _ in
                            revisionsCompletedCount += 1
                            if revisionsCompletedCount == deviceRevision.entities.count{
                                self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                            }
                        }
                    }else{
                        
                        guard let parse = self.pckStoreClassesToSynchronize[.patient]?.new(with: entity) else{
                            completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                            return
                        }
                        
                        parse.pushRevision(overwriteRemote, cloudClock: cloudVectorClock){
                            error in
                            revisionsCompletedCount += 1
                            if revisionsCompletedCount == deviceRevision.entities.count{
                                self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                            }
                        }
                    }
                    
                case .carePlan(let carePlan):
                    if let customClassName = carePlan.userInfo?[kPCKCustomClassKey] {
                        self.pushRevisionForCustomClass(entity, className: customClassName, overwriteRemote: overwriteRemote, cloudClock: cloudVectorClock){
                            _ in
                            revisionsCompletedCount += 1
                            if revisionsCompletedCount == deviceRevision.entities.count{
                                self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                            }
                        }
                    }else{
                        
                        guard let parse = self.pckStoreClassesToSynchronize[.carePlan]?.new(with: entity) else {
                            completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                            return
                        }
                        
                        parse.pushRevision(overwriteRemote, cloudClock: cloudVectorClock){
                            _ in
                            revisionsCompletedCount += 1
                            if revisionsCompletedCount == deviceRevision.entities.count{
                                self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                            }
                        }
                    }
                case .contact(let contact):
                    if let customClassName = contact.userInfo?[kPCKCustomClassKey] {
                        self.pushRevisionForCustomClass(entity, className: customClassName, overwriteRemote: overwriteRemote, cloudClock: cloudVectorClock){
                            _ in
                            revisionsCompletedCount += 1
                            if revisionsCompletedCount == deviceRevision.entities.count{
                                self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                            }
                        }
                    }else{
                        guard let parse = self.pckStoreClassesToSynchronize[.contact]?.new(with: entity) else {
                            completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                            return
                        }
                        parse.pushRevision(overwriteRemote, cloudClock: cloudVectorClock){
                            _ in
                            revisionsCompletedCount += 1
                            if revisionsCompletedCount == deviceRevision.entities.count{
    
                                self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                            }
                        }
                    }
                case .task(let task):
                    if let customClassName = task.userInfo?[kPCKCustomClassKey] {
                        self.pushRevisionForCustomClass(entity, className: customClassName, overwriteRemote: overwriteRemote, cloudClock: cloudVectorClock){
                            _ in
                            revisionsCompletedCount += 1
                            if revisionsCompletedCount == deviceRevision.entities.count{
                                self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                            }
                        }
                    }else{
                        guard let parse = self.pckStoreClassesToSynchronize[.task]?.new(with: entity) else {
                            completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                            return
                        }
                        
                        parse.pushRevision(overwriteRemote, cloudClock: cloudVectorClock){
                            _ in
                            revisionsCompletedCount += 1
                            if revisionsCompletedCount == deviceRevision.entities.count{
                                
                                self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                            }
                        }
                        
                    }
                case .outcome(let outcome):
                    
                    if let customClassName = outcome.userInfo?[kPCKCustomClassKey] {
                        self.pushRevisionForCustomClass(entity, className: customClassName, overwriteRemote: overwriteRemote, cloudClock: cloudVectorClock){
                            _ in
                            revisionsCompletedCount += 1
                            if revisionsCompletedCount == deviceRevision.entities.count{
                                self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                            }
                        }
                    }else{
                        guard let parse = self.pckStoreClassesToSynchronize[.outcome]?.new(with: entity) else{
                            completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                            return
                        }
                        parse.pushRevision(overwriteRemote, cloudClock: cloudVectorClock){
                            _ in
                            revisionsCompletedCount += 1
                            if revisionsCompletedCount == deviceRevision.entities.count{
                                
                                self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func pushRevisionForCustomClass(_ entity: OCKEntity, className: String, overwriteRemote: Bool, cloudClock: Int, completion: @escaping (Error?) -> Void){
        guard let customClass = self.customClassesToSynchronize?[className] else{
            completion(ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        guard let parse = customClass.new(with: entity) else{
            completion(ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        parse.pushRevision(overwriteRemote, cloudClock: cloudClock){
            error in
            completion(error)
        }
    }
    
    func finishedRevisions(_ parseKnowledgeVector: KnowledgeVector, cloudKnowledgeVector: OCKRevisionRecord.KnowledgeVector, localKnowledgeVector: OCKRevisionRecord.KnowledgeVector, completion: @escaping (Error?)->Void){
        var parseKnowledgeVector = parseKnowledgeVector
        var cloudVector = cloudKnowledgeVector
        //Increment and merge Knowledge Vector
        cloudVector.increment(clockFor: uuid)
        cloudVector.merge(with: localKnowledgeVector)
        
        guard let _ = parseKnowledgeVector.encodeKnowledgeVector(cloudVector) else{
            completion(ParseCareKitError.couldntUnwrapKnowledgeVector)
            return
        }
        parseKnowledgeVector.save(callbackQueue: .global(qos: .background)){
            result in
            switch result {

            case .success(_):
                self.parseRemoteDelegate?.successfullyPushedDataToCloud()
                completion(nil)
            case .failure(let error):
                print("Error in ParseRemoteSynchronizationManager.finishedRevisions(). \(error.localizedDescription)")
                completion(error)
            }
        }
    }
    
    public func chooseConflictResolutionPolicy(_ conflict: OCKMergeConflictDescription, completion: @escaping (OCKMergeConflictResolutionPolicy) -> Void) {
        if parseRemoteDelegate != nil{
            parseRemoteDelegate!.chooseConflictResolutionPolicy(conflict, completion: completion)
        }else{
            let conflictPolicy = OCKMergeConflictResolutionPolicy.keepRemote
            completion(conflictPolicy)
        }
    }
}
