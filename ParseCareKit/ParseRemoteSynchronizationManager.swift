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

/**
 Protocol that defines the properties and methods for parse carekit entities that are synchronized using a knowledge vector.
 */
public protocol PCKRemoteSynchronizedEntity: PFObject, PFSubclassing {
    static func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void)
    static func pushRevision(_ store: OCKStore, overwriteRemote: Bool, cloudClock: Int, careKitEntity:OCKEntity, completion: @escaping (Error?) -> Void)
}

public protocol ParseRemoteSynchronizationDelegate{
    func chooseConflictResolutionPolicy(_ conflict: OCKMergeConflictDescription, completion: @escaping (OCKMergeConflictResolutionPolicy) -> Void)
}

open class ParseRemoteSynchronizationManager: NSObject, OCKRemoteSynchronizable {
    public var delegate: OCKRemoteSynchronizationDelegate?
    public var parseRemoteDelegate: ParseRemoteSynchronizationDelegate?
    public var automaticallySynchronizes: Bool
    public weak var store:OCKStore!
    
    public override init(){
        self.automaticallySynchronizes = false //Don't start until OCKStore is available
        super.init()
    }
    
    public func pullRevisions(since knowledgeVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord, @escaping (Error?) -> Void) -> Void, completion: @escaping (Error?) -> Void) {
        
        guard let user = User.current() else{
            completion(nil)
            return
        }
        
        //Fetch KnowledgeVector from Cloud
        KnowledgeVector.fetchFromCloud(user: user, createNewIfNeeded: false){
            (_, potentialCKKnowledgeVector, potentialUUID) in
            guard let cloudVector = potentialCKKnowledgeVector,
                let cloudVectorUUID = potentialUUID else{
                completion(nil)
                return
            }
            
            //Currently can't seet UUIDs using structs, so this commented out. Maybe if I encode/decode?
            let localClock = knowledgeVector.clock(for: cloudVectorUUID)
            Task.pullRevisions(localClock, cloudVector: cloudVector){
                taskRevision in
                mergeRevision(taskRevision){
                    error in
                    if error != nil {
                        completion(error!)
                        return
                    }
                    Outcome.pullRevisions(localClock, cloudVector: cloudVector){
                        outcomeRevision in
                        mergeRevision(outcomeRevision){
                            error in
                            if error != nil {
                                completion(error!)
                            }
                            completion(nil)
                            return
                        }
                    }
                }
            }
        }
    }
    
    public func pushRevisions(deviceRevision: OCKRevisionRecord, overwriteRemote: Bool, completion: @escaping (Error?) -> Void) {
        
        guard let user = User.current(),
            deviceRevision.entities.count > 0 else{
            completion(nil)
            return
        }
        //Fetch KnowledgeVector from Cloud
        KnowledgeVector.fetchFromCloud(user: user, createNewIfNeeded: true){
            (potentialPCKKnowledgeVector, potentialCKKnowledgeVector, potentialUUID) in
        
            guard let cloudParseVector = potentialPCKKnowledgeVector,
                let cloudCareKitVector = potentialCKKnowledgeVector,
                let cloudVectorUUID = potentialUUID else{
                completion(nil)
                return
            }
            
            let cloudVectorClock = cloudCareKitVector.clock(for: cloudVectorUUID)
            var revisionsCompletedCount = 0
            deviceRevision.entities.forEach{
                let entity = $0
                switch entity{
                case .patient(_):
                    User.pushRevision(self.store, overwriteRemote: overwriteRemote, cloudClock: cloudVectorClock, careKitEntity: entity){
                        error in
                        revisionsCompletedCount += 1
                        if revisionsCompletedCount == deviceRevision.entities.count{
                            self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                        }
                    }
                case .carePlan(_):
                    CarePlan.pushRevision(self.store, overwriteRemote: overwriteRemote, cloudClock: cloudVectorClock, careKitEntity: entity){
                        _ in
                        revisionsCompletedCount += 1
                        if revisionsCompletedCount == deviceRevision.entities.count{
                            self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                        }
                    }
                case .contact(_):
                    Contact.pushRevision(self.store, overwriteRemote: overwriteRemote, cloudClock: cloudVectorClock, careKitEntity: entity){
                        _ in
                        revisionsCompletedCount += 1
                        if revisionsCompletedCount == deviceRevision.entities.count{
                            self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                        }
                    }
                case .task(_):
                    Task.pushRevision(self.store, overwriteRemote: overwriteRemote, cloudClock: cloudVectorClock, careKitEntity: entity){
                        _ in
                        revisionsCompletedCount += 1
                        if revisionsCompletedCount == deviceRevision.entities.count{
                            self.finishedRevisions(cloudParseVector, cloudKnowledgeVector: cloudCareKitVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                        }
                    }
                case .outcome(_):
                    Outcome.pushRevision(self.store, overwriteRemote: overwriteRemote, cloudClock: cloudVectorClock, careKitEntity: entity){
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
    
    func finishedRevisions(_ parseKnowledgeVector: KnowledgeVector, cloudKnowledgeVector: OCKRevisionRecord.KnowledgeVector, localKnowledgeVector: OCKRevisionRecord.KnowledgeVector, completion: @escaping (Error?)->Void){
        
        guard let cloudVectorUUID = UUID(uuidString: parseKnowledgeVector.uuid) else{
            completion(nil)
            return
        }
        
        var cloudVector = cloudKnowledgeVector
        //Increment and merge Knowledge Vector
        cloudVector.increment(clockFor: cloudVectorUUID)
        cloudVector.merge(with: localKnowledgeVector)
        
        guard let _ = parseKnowledgeVector.encodeKnowledgeVector(cloudVector) else{
            completion(nil)
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
