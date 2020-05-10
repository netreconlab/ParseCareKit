//
//  ParseRemoteSynchronizationManager.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/6/20.
//  Copyright © 2020 University of Kentucky. All rights reserved.
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

open class ParseRemoteSynchronizationManager: NSObject, OCKRemoteSynchronizable {
    public var delegate: OCKRemoteSynchronizationDelegate?
    
    public var automaticallySynchronizes: Bool
    public weak var store:OCKStore!
    var currentlyPulling = false
    var currentlyPushing = false
    
    public override init(){
        self.automaticallySynchronizes = false //Don't start until OCKStore is available
        super.init()
    }
    
    public func pullRevisions(since knowledgeVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord, @escaping (Error?) -> Void) -> Void, completion: @escaping (Error?) -> Void) {
        
        guard let user = User.current(),
            currentlyPulling == false,
            currentlyPushing == false else{
            //let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
            //mergeRevision(revision, completion)
            completion(nil)
            return
        }
        
        currentlyPulling = true
        //Fetch KnowledgeVector from Cloud
        let query = KnowledgeVector.query()!
        query.whereKey(kPCKKnowledgeVectorUserKey, equalTo: user)
        query.getFirstObjectInBackground{ (object,error) in
            
            guard let foundVector = object as? KnowledgeVector,
                let cloudVectorUUID = UUID(uuidString: foundVector.uuid),
                let data = foundVector.vector.data(using: .utf8) else{
                //let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
                //mergeRevision(revision, completion)
                self.currentlyPulling = false
                completion(nil)
                return
            }
            let cloudVector:OCKRevisionRecord.KnowledgeVector!
            do {
                cloudVector = try JSONDecoder().decode(OCKRevisionRecord.KnowledgeVector.self, from: data)
            }catch{
                let error = error
                print("Error in ParseRemoteSynchronizationManager.pullRevisions(). Couldn't decode vector \(data). Error: \(error)")
                cloudVector = nil
                self.currentlyPulling = false
                completion(nil)
                /*let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
                mergeRevision(revision){
                    _ in
                    completion(error)
                }*/
                return
            }
            let localClock = knowledgeVector.clock(for: cloudVectorUUID)
            
            Task.pullRevisions(localClock, cloudVector: cloudVector){
                taskRevision in
                mergeRevision(taskRevision){
                    error in
                    if error != nil {
                        self.currentlyPulling = false
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
                            self.currentlyPulling = false
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
            deviceRevision.entities.count > 0,
            currentlyPushing == false else{
            completion(nil)
            return
        }
        currentlyPushing = true
        //Fetch KnowledgeVector from Cloud
        let query = KnowledgeVector.query()!
        query.whereKey(kPCKKnowledgeVectorUserKey, equalTo: user)
        query.getFirstObjectInBackground{ (object,error) in
            
            let foundVector:KnowledgeVector!
            if object == nil{
                //This is the first time the KnowledgeVector is being setup for this user
                let uuid = UUID()
                foundVector = KnowledgeVector(uuid: uuid.uuidString)
            }else{
                if let found = object as? KnowledgeVector{
                    foundVector = found
                }else{
                    print("Error in ParseRemoteSynchronizationManager.pushRevisions(). Couldn't get KnowledgeVector correctly from Cloud")
                    foundVector=nil
                    self.currentlyPushing = false
                    completion(nil)
                    return
                }
            }
            
            guard let cloudVectorUUID = UUID(uuidString: foundVector.uuid),
                let data = foundVector.vector.data(using: .utf8) else{
                self.currentlyPushing = false
                completion(nil)
                return
            }
            var cloudVector:OCKRevisionRecord.KnowledgeVector!
            do {
                cloudVector = try JSONDecoder().decode(OCKRevisionRecord.KnowledgeVector.self, from: data)
            }catch{
                print("Error in ParseRemoteSynchronizationManager.pushRevisions(). Couldn't decode vector \(data)")
                cloudVector = nil
                self.currentlyPushing = false
                completion(nil)
                return
            }
            
            let cloudVectorClock = cloudVector.clock(for: cloudVectorUUID)
            var revisionsCompletedCount = 0
            deviceRevision.entities.forEach{
                let entity = $0
                switch entity{
                case .patient(_):
                    User.pushRevision(self.store, overwriteRemote: overwriteRemote, cloudClock: cloudVectorClock, careKitEntity: entity){
                        error in
                        revisionsCompletedCount += 1
                        if revisionsCompletedCount == deviceRevision.entities.count{
                            self.completedRevisions(foundVector, cloudKnowledgeVector: cloudVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                        }
                    }
                case .carePlan(_):
                    CarePlan.pushRevision(self.store, overwriteRemote: overwriteRemote, cloudClock: cloudVectorClock, careKitEntity: entity){
                        _ in
                        revisionsCompletedCount += 1
                        if revisionsCompletedCount == deviceRevision.entities.count{
                            self.completedRevisions(foundVector, cloudKnowledgeVector: cloudVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                        }
                    }
                case .contact(_):
                    Contact.pushRevision(self.store, overwriteRemote: overwriteRemote, cloudClock: cloudVectorClock, careKitEntity: entity){
                        _ in
                        revisionsCompletedCount += 1
                        if revisionsCompletedCount == deviceRevision.entities.count{
                            self.completedRevisions(foundVector, cloudKnowledgeVector: cloudVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                        }
                    }
                case .task(_):
                    Task.pushRevision(self.store, overwriteRemote: overwriteRemote, cloudClock: cloudVectorClock, careKitEntity: entity){
                        _ in
                        revisionsCompletedCount += 1
                        if revisionsCompletedCount == deviceRevision.entities.count{
                            self.completedRevisions(foundVector, cloudKnowledgeVector: cloudVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                        }
                    }
                case .outcome(_):
                    Outcome.pushRevision(self.store, overwriteRemote: overwriteRemote, cloudClock: cloudVectorClock, careKitEntity: entity){
                        _ in
                        revisionsCompletedCount += 1
                        if revisionsCompletedCount == deviceRevision.entities.count{
                            self.completedRevisions(foundVector, cloudKnowledgeVector: cloudVector, localKnowledgeVector: deviceRevision.knowledgeVector, completion: completion)
                        }
                    }
                }
            }
        }
    }
    
    func completedRevisions(_ parseKnowledgeVector: KnowledgeVector, cloudKnowledgeVector: OCKRevisionRecord.KnowledgeVector, localKnowledgeVector: OCKRevisionRecord.KnowledgeVector, completion: @escaping (Error?)->Void){
        
        guard let cloudVectorUUID = UUID(uuidString: parseKnowledgeVector.uuid) else{
            self.currentlyPushing = false
            completion(nil)
            return
        }
        
        var cloudVector = cloudKnowledgeVector
        
        //Increment and merge Knowledge Vector
        cloudVector.increment(clockFor: cloudVectorUUID)
        cloudVector.merge(with: localKnowledgeVector)
        do{
            let json = try JSONEncoder().encode(cloudVector)
            let cloudVectorString = String(data: json, encoding: .utf8)!
            parseKnowledgeVector.vector = cloudVectorString
            parseKnowledgeVector.saveInBackground{
                (success,error) in
                self.currentlyPushing = false
                if !success{
                    print("Error in ParseRemoteSynchronizationManager.completedRevisions(). \(String(describing: error))")
                    completion(error)
                    return
                }
                completion(nil)
            }
        }catch{
            self.currentlyPushing = false
            completion(error)
        }
    }
    
    public func chooseConflictResolutionPolicy(_ conflict: OCKMergeConflictDescription, completion: @escaping (OCKMergeConflictResolutionPolicy) -> Void) {
        let conflictPolicy = OCKMergeConflictResolutionPolicy.keepRemote
        completion(conflictPolicy)
    }
}
