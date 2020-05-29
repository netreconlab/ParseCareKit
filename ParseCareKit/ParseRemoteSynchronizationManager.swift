//
//  ParseRemoteSynchronizationManager.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/6/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import CareKitStore
import Parse


public protocol ParseRemoteSynchronizationDelegate{
    func chooseConflictResolutionPolicy(_ conflict: OCKMergeConflictDescription, completion: @escaping (OCKMergeConflictResolutionPolicy) -> Void)
}

open class ParseRemoteSynchronizationManager: NSObject, OCKRemoteSynchronizable {
    public var delegate: OCKRemoteSynchronizationDelegate?
    public var parseRemoteDelegate: ParseRemoteSynchronizationDelegate?
    public var automaticallySynchronizes: Bool
    public internal(set) var userTypeUUID:UUID!
    public internal(set) weak var store:OCKStore!
    public internal(set) var customClassesToSynchronize:[String:PCKRemoteSynchronized]?
    public internal(set) var pckStoreClassesToSynchronize: [PCKStoreClass: PCKRemoteSynchronized]!
    
    override init(){
        self.automaticallySynchronizes = false //Don't start until OCKStore is available
        super.init()
    }
    
    convenience public init(uuid:UUID) {
        self.init()
        self.userTypeUUID = uuid
        self.pckStoreClassesToSynchronize = PCKStoreClass.patient.getRemoteConcrete()
        self.customClassesToSynchronize = nil
    }
    
    convenience public init(uuid:UUID, replacePCKStoreClasses: [PCKStoreClass: PCKRemoteSynchronized]) {
        self.init()
        self.userTypeUUID = uuid
        self.pckStoreClassesToSynchronize = PCKStoreClass.patient.replaceRemoteConcreteClasses(replacePCKStoreClasses)
        self.customClassesToSynchronize = nil
    }
    
    convenience public init(uuid:UUID, replacePCKStoreClasses: [PCKStoreClass: PCKRemoteSynchronized]?, customClasses: [String:PCKRemoteSynchronized]){
        self.init()
        self.userTypeUUID = uuid
        if replacePCKStoreClasses != nil{
            self.pckStoreClassesToSynchronize = PCKStoreClass.patient.replaceRemoteConcreteClasses(replacePCKStoreClasses!)
        }else{
            self.pckStoreClassesToSynchronize = nil
        }
         
        self.customClassesToSynchronize = customClasses
    }
    
    public func startSynchronizing(_ store: OCKStore, auto: Bool=true){
        self.store = store
        self.automaticallySynchronizes = auto
        
        guard self.pckStoreClassesToSynchronize != nil else {
            fatalError("ParseRemoteSynchronize.startSynchronizing() cannot start synchronzing because something is wrong with replacePCKStoreClasses.")
        }
    
        if self.automaticallySynchronizes{
            self.store.synchronize { error in
                print(error?.localizedDescription ?? "ParseCareKit auto synchronizing has started...")
            }
        }else{
            print("ParseCareKit set to manual synchronization. Trigger synchronization manually if needed")
        }
    }
    
    public func pullRevisions(since knowledgeVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord, @escaping (Error?) -> Void) -> Void, completion: @escaping (Error?) -> Void) {
        
        guard let _ = PFUser.current() else{
            completion(ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Fetch KnowledgeVector from Cloud
        KnowledgeVector.fetchFromCloud(userTypeUUID: userTypeUUID, createNewIfNeeded: false){[weak self]
            (_, potentialCKKnowledgeVector, error) in
            guard let cloudVector = potentialCKKnowledgeVector else{
                //Okay to return nil here to let pushRevisions fix KnowledgeVector
                completion(nil)
                return
            }
            let returnError:Error? = nil
            
            guard let self = self else{
                completion(ParseCareKitError.cantUnwrapSelf)
                return
            }
            
            //Currently can't seet UUIDs using structs, so this commented out. Maybe if I encode/decode?
            let localClock = knowledgeVector.clock(for: self.userTypeUUID)
            
            self.pullRevisionsForConcreteClasses(previousError: returnError, localClock: localClock, cloudVector: cloudVector, mergeRevision: mergeRevision){[weak self] previosError in
                    
                guard let self = self else{
                    completion(ParseCareKitError.cantUnwrapSelf)
                    return
                }
                
                self.pullRevisionsForCustomClasses(previousError: previosError, localClock: localClock, cloudVector: cloudVector, mergeRevision: mergeRevision, completion: completion)
            }
        }
    }
    
    func pullRevisionsForConcreteClasses(concreteClassesAlreadyPulled:Int=0, previousError: Error?, localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord, @escaping (Error?) -> Void) -> Void, completion: @escaping (Error?) -> Void){
        
        let classNames = PCKStoreClass.patient.orderedArray()
        
        guard concreteClassesAlreadyPulled < classNames.count,
            let concreteClass = self.pckStoreClassesToSynchronize[classNames[concreteClassesAlreadyPulled]],
            let newConcreteClass = concreteClass.new() as? PCKRemoteSynchronized else{
                print("Finished pulling default revision classes")
                completion(previousError)
                return
        }
        var currentError = previousError
        newConcreteClass.pullRevisions(localClock, cloudVector: cloudVector){[weak self]
            customRevision in
            mergeRevision(customRevision){
                error in
                if error != nil {
                    currentError = error!
                    print("Error in ParseCareKit.pullRevisionsForConcreteClasses(). \(currentError!)")
                }
                
                guard let self = self else{
                    completion(ParseCareKitError.cantUnwrapSelf)
                    return
                }
                
                self.pullRevisionsForConcreteClasses(concreteClassesAlreadyPulled: concreteClassesAlreadyPulled+1, previousError: currentError, localClock: localClock, cloudVector: cloudVector, mergeRevision: mergeRevision, completion: completion)
                
            }
        }
    }
    
    func pullRevisionsForCustomClasses(customClassesAlreadyPulled:Int=0, previousError: Error?, localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord, @escaping (Error?) -> Void) -> Void, completion: @escaping (Error?) -> Void){
        if let customClassesToSynchronize = self.customClassesToSynchronize{
            let classNames = customClassesToSynchronize.keys.sorted()
            
            guard customClassesAlreadyPulled < classNames.count,
                let customClass = customClassesToSynchronize[classNames[customClassesAlreadyPulled]],
                let newCustomClass = customClass.new() as? PCKRemoteSynchronized else{
                    print("Finished pulling custom revision classes")
                    completion(previousError)
                    return
            }
            var currentError = previousError
            newCustomClass.pullRevisions(localClock, cloudVector: cloudVector){[weak self]
                customRevision in
                mergeRevision(customRevision){
                    error in
                    if error != nil {
                        currentError = error!
                        print("Error in ParseCareKit.pullRevisionsForCustomClasses(). \(currentError!)")
                    }
                    
                    guard let self = self else{
                        completion(ParseCareKitError.cantUnwrapSelf)
                        return
                    }
                    
                    self.pullRevisionsForCustomClasses(customClassesAlreadyPulled: customClassesAlreadyPulled+1, previousError: currentError, localClock: localClock, cloudVector: cloudVector, mergeRevision: mergeRevision, completion: completion)
                }
            }
        }else{
            completion(previousError)
        }
    }
    
    public func pushRevisions(deviceRevision: OCKRevisionRecord, overwriteRemote: Bool, completion: @escaping (Error?) -> Void) {
        
        guard let _ = PFUser.current() else{
            completion(ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        guard deviceRevision.entities.count > 0 else{
            //No revisions need to be pushed
            completion(nil)
            return
        }
        
        //Fetch KnowledgeVector from Cloud
        KnowledgeVector.fetchFromCloud(userTypeUUID: userTypeUUID, createNewIfNeeded: true){
            (potentialPCKKnowledgeVector, potentialCKKnowledgeVector, error) in
        
            guard let cloudParseVector = potentialPCKKnowledgeVector,
                let cloudCareKitVector = potentialCKKnowledgeVector else{
                    guard let error = error as NSError?,
                        let errorDictionary = error.userInfo["error"] as? [String:Any],
                        let reason = errorDictionary["routine"] as? String else {
                            completion(ParseCareKitError.couldntUnwrapKnowledgeVector)
                            return
                    }
                    //If the query was looking in a column that wasn't a default column, it will return nil if the table doesn't contain the custom column
                    if reason == "errorMissingColumn"{
                        //Saving the new item with the custom column should resolve the issue
                        print("This table '\(KnowledgeVector.parseClassName())' either doesn't exist or is missing a column. Attempting to create the table and add new data to it...")
                        if potentialPCKKnowledgeVector != nil{
                            potentialPCKKnowledgeVector!.saveInBackground{
                                (success,error) in
                                print("Saved KnowledgeVector. Try to sync again \(potentialPCKKnowledgeVector!)")
                                completion(error)
                            }
                        }else{
                            completion(error)
                        }
                    }else{
                        //There was a different issue that we don't know how to handle
                        print("Error in ParseRemoteSynchronizationManager.pushRevisions() \(error.localizedDescription)")
                        completion(error)
                    }
                return
            }
            
            let cloudVectorClock = cloudCareKitVector.clock(for: self.userTypeUUID)
            var revisionsCompletedCount = 0
            deviceRevision.entities.forEach{
                let entity = $0
                switch entity{
                case .patient(let patient):
                    
                    if let customClassName = patient.userInfo?[kPCKCustomClassKey] {
                        self.pushRevisionForCustomClass(entity, className: customClassName, overwriteRemote: overwriteRemote, cloudClock: cloudVectorClock){[weak self]
                            _ in
                            revisionsCompletedCount += 1
                            if revisionsCompletedCount == deviceRevision.entities.count{
                                guard let self = self else{
                                    completion(ParseCareKitError.cantUnwrapSelf)
                                    return
                                }
                                self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                            }
                        }
                    }else{
                        
                        _ = self.pckStoreClassesToSynchronize[.patient]!.new(with: entity, store: self.store){[weak self]
                            parse in
                            
                            guard let parse = parse as? PCKRemoteSynchronized else{
                                completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                                return
                            }
                            parse.pushRevision(overwriteRemote, cloudClock: cloudVectorClock){
                                error in
                                revisionsCompletedCount += 1
                                if revisionsCompletedCount == deviceRevision.entities.count{
                                    guard let self = self else{
                                        completion(ParseCareKitError.cantUnwrapSelf)
                                        return
                                    }
                                    self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                                }
                            }
                        }
                    }
                
                case .carePlan(let carePlan):
                    if let customClassName = carePlan.userInfo?[kPCKCustomClassKey] {
                        self.pushRevisionForCustomClass(entity, className: customClassName, overwriteRemote: overwriteRemote, cloudClock: cloudVectorClock){[weak self]
                            _ in
                            revisionsCompletedCount += 1
                            if revisionsCompletedCount == deviceRevision.entities.count{
                                guard let self = self else{
                                    completion(ParseCareKitError.cantUnwrapSelf)
                                    return
                                }
                                self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                            }
                        }
                    }else{
                        
                        _ = self.pckStoreClassesToSynchronize[.carePlan]!.new(with: entity, store: self.store){[weak self]
                        parse in
                        
                            guard let parse = parse as? PCKRemoteSynchronized else{
                                completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                                return
                            }
                            parse.pushRevision(overwriteRemote, cloudClock: cloudVectorClock){
                                _ in
                                revisionsCompletedCount += 1
                                if revisionsCompletedCount == deviceRevision.entities.count{
                                    guard let self = self else{
                                        completion(ParseCareKitError.cantUnwrapSelf)
                                        return
                                    }
                                    self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                                }
                            }
                        }
                    }
                case .contact(let contact):
                    if let customClassName = contact.userInfo?[kPCKCustomClassKey] {
                        self.pushRevisionForCustomClass(entity, className: customClassName, overwriteRemote: overwriteRemote, cloudClock: cloudVectorClock){[weak self]
                            _ in
                            revisionsCompletedCount += 1
                            if revisionsCompletedCount == deviceRevision.entities.count{
                                guard let self = self else{
                                    completion(ParseCareKitError.cantUnwrapSelf)
                                    return
                                }
                                self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                            }
                        }
                    }else{
                        _ = self.pckStoreClassesToSynchronize[.contact]!.new(with: entity, store: self.store){
                        parse in
                        
                            guard let parse = parse as? PCKRemoteSynchronized else{
                                completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                                return
                            }
                            parse.pushRevision(overwriteRemote, cloudClock: cloudVectorClock){[weak self]
                                _ in
                                revisionsCompletedCount += 1
                                if revisionsCompletedCount == deviceRevision.entities.count{
                                    guard let self = self else{
                                        completion(ParseCareKitError.cantUnwrapSelf)
                                        return
                                    }
                                    self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                                }
                            }
                        }
                    }
                case .task(let task):
                    if let customClassName = task.userInfo?[kPCKCustomClassKey] {
                        self.pushRevisionForCustomClass(entity, className: customClassName, overwriteRemote: overwriteRemote, cloudClock: cloudVectorClock){[weak self]
                            _ in
                            revisionsCompletedCount += 1
                            if revisionsCompletedCount == deviceRevision.entities.count{
                                guard let self = self else{
                                    completion(ParseCareKitError.cantUnwrapSelf)
                                    return
                                }
                                self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                            }
                        }
                    }else{
                        _ = self.pckStoreClassesToSynchronize[.task]!.new(with: entity, store: self.store){
                        parse in
                        
                            guard let parse = parse as? PCKRemoteSynchronized else{
                                completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                                return
                            }
                            parse.pushRevision(overwriteRemote, cloudClock: cloudVectorClock){[weak self]
                                _ in
                                revisionsCompletedCount += 1
                                if revisionsCompletedCount == deviceRevision.entities.count{
                                    guard let self = self else{
                                        completion(ParseCareKitError.cantUnwrapSelf)
                                        return
                                    }
                                    self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                                }
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
                        _ = self.pckStoreClassesToSynchronize[.outcome]!.new(with: entity, store: self.store){[weak self]
                        parse in
                        
                            guard let parse = parse as? PCKRemoteSynchronized else{
                                completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                                return
                            }
                            parse.pushRevision(overwriteRemote, cloudClock: cloudVectorClock){
                                _ in
                                revisionsCompletedCount += 1
                                if revisionsCompletedCount == deviceRevision.entities.count{
                                    guard let self = self else{
                                        completion(ParseCareKitError.cantUnwrapSelf)
                                        return
                                    }
                                    self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                                }
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
        
        customClass.new(with: entity, store: self.store){
            parse in
            
            guard let parse = parse as? PCKRemoteSynchronized else{
                completion(ParseCareKitError.requiredValueCantBeUnwrapped)
                return
            }
            parse.pushRevision(overwriteRemote, cloudClock: cloudClock){
                error in
                completion(error)
            }
        }
    }
    
    func finishedRevisions(_ parseKnowledgeVector: KnowledgeVector, cloudKnowledgeVector: OCKRevisionRecord.KnowledgeVector, localKnowledgeVector: OCKRevisionRecord.KnowledgeVector, completion: @escaping (Error?)->Void){
        
        var cloudVector = cloudKnowledgeVector
        //Increment and merge Knowledge Vector
        cloudVector.increment(clockFor: userTypeUUID)
        cloudVector.merge(with: localKnowledgeVector)
        
        guard let _ = parseKnowledgeVector.encodeKnowledgeVector(cloudVector) else{
            completion(ParseCareKitError.couldntUnwrapKnowledgeVector)
            return
        }
        parseKnowledgeVector.saveInBackground{
            (success,error) in
            if !success{
                print("Error in ParseRemoteSynchronizationManager.finishedRevisions(). \(String(describing: error))")
                completion(error)
                return
            }
            completion(nil)
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
