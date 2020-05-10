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
    static func pushRevision(_ store: OCKStore, cloudClock: Int, careKitEntity:OCKEntity)
}

open class ParseRemoteSynchronizationManager: NSObject, OCKRemoteSynchronizable {
    public var delegate: OCKRemoteSynchronizationDelegate?
    
    public var automaticallySynchronizes: Bool
    public weak var store:OCKStore!
    
    public override init(){
        self.automaticallySynchronizes = false //Don't start until OCKStore is available
        super.init()
    }
    
    public func pullRevisions(since knowledgeVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord, @escaping (Error?) -> Void) -> Void, completion: @escaping (Error?) -> Void) {
        
        guard let user = User.current() else{
            //let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
            //mergeRevision(revision, completion)
            completion(nil)
            return
        }
        
        //Fetch KnowledgeVector from Cloud
        let query = KnowledgeVector.query()!
        query.whereKey(kPCKKnowledgeVectorUserKey, equalTo: user)
        query.getFirstObjectInBackground{ (object,error) in
            
            guard let foundVector = object as? KnowledgeVector,
                let cloudVectorUUID = UUID(uuidString: foundVector.uuid),
                let data = foundVector.vector.data(using: .utf8) else{
                //let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
                //mergeRevision(revision, completion)
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
                        completion(error!)
                        return
                    }
                    Outcome.pullRevisions(localClock, cloudVector: cloudVector){
                        outcomeRevision in
                        mergeRevision(outcomeRevision){
                            error in
                            if error != nil {
                                completion(error!)
                                return
                            }
                            completion(nil)
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
                    completion(nil)
                    return
                }
            }
            
            guard let cloudVectorUUID = UUID(uuidString: foundVector.uuid),
                let data = foundVector.vector.data(using: .utf8) else{
                completion(nil)
                return
            }
            var cloudVector:OCKRevisionRecord.KnowledgeVector!
            do {
                cloudVector = try JSONDecoder().decode(OCKRevisionRecord.KnowledgeVector.self, from: data)
            }catch{
                print("Error in ParseRemoteSynchronizationManager.pushRevisions(). Couldn't decode vector \(data)")
                cloudVector = nil
                completion(nil)
                return
            }
            
            let cloudVectorClock = cloudVector.clock(for: cloudVectorUUID)
            deviceRevision.entities.forEach{
                let entity = $0
                switch entity{
                case .patient(_):
                    User.pushRevision(self.store, cloudClock: cloudVectorClock, careKitEntity: entity)
                case .carePlan(_):
                    CarePlan.pushRevision(self.store, cloudClock: cloudVectorClock, careKitEntity: entity)
                case .contact(_):
                    Contact.pushRevision(self.store, cloudClock: cloudVectorClock, careKitEntity: entity)
                case .task(_):
                    Task.pushRevision(self.store, cloudClock: cloudVectorClock, careKitEntity: entity)
                case .outcome(_):
                    Outcome.pushRevision(self.store, cloudClock: cloudVectorClock, careKitEntity: entity)
                }
            }
            
            //Increment and merge Knowledge Vector
            cloudVector.increment(clockFor: cloudVectorUUID)
            cloudVector.merge(with: deviceRevision.knowledgeVector)
            do{
                let json = try JSONEncoder().encode(cloudVector)
                let cloudVectorString = String(data: json, encoding: .utf8)!
                foundVector.vector = cloudVectorString
                foundVector.saveInBackground{
                    (success,error) in
                    if !success{
                        guard let error = error else{
                            print("Error in ParseRemoteSynchronizationManager.pushRevisions(). Unknown error")
                            completion(nil)
                            return
                        }
                        print("Error in ParseRemoteSynchronizationManager.pushRevisions(). \(error)")
                    }
                    completion(error)
                }
            }catch{
                let error = error
                completion(error)
            }
        }
        completion(nil)
    }
    
    public func chooseConflictResolutionPolicy(_ conflict: OCKMergeConflictDescription, completion: @escaping (OCKMergeConflictResolutionPolicy) -> Void) {
        let conflictPolicy = OCKMergeConflictResolutionPolicy.keepRemote
        completion(conflictPolicy)
    }
}
