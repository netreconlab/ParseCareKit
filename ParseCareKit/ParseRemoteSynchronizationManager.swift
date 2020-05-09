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
            let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
            mergeRevision(revision, completion)
            return
        }
        
        //Fetch KnowledgeVector from Cloud
        let query = KnowledgeVector.query()!
        query.whereKey(kPCKKnowledgeVectorUserKey, equalTo: user)
        query.getFirstObjectInBackground{ (object,error) in
            
            guard let foundVector = object as? KnowledgeVector,
                let cloudVectorUUID = UUID(uuidString: foundVector.uuid),
                let data = foundVector.vector.data(using: .utf8) else{
                let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
                mergeRevision(revision, completion)
                return
            }
            let cloudVector:OCKRevisionRecord.KnowledgeVector!
            do {
                cloudVector = try JSONDecoder().decode(OCKRevisionRecord.KnowledgeVector.self, from: data)
            }catch{
                let error = error
                print("Error in ParseRemoteSynchronizationManager.pullRevisions(). Couldn't decode vector \(data). Error: \(error)")
                cloudVector = nil
                let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
                mergeRevision(revision){
                    _ in
                    completion(error)
                }
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
                        }
                    }
                }
                
            }
        }
    }
    
    public func pushRevisions(deviceRevision: OCKRevisionRecord, overwriteRemote: Bool, completion: @escaping (Error?) -> Void) {
        
        guard let user = User.current() else{
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
                    
                case .patient(let patient):
                    
                    let _ = User(careKitEntity: patient, store: self.store){
                        copiedPatient in
                        guard let parsePatient = copiedPatient as? User else{return}
                        if patient.deletedDate == nil{
                            parsePatient.addToCloudInBackground(self.store, usingKnowledgeVector: true)
                        }else{
                            parsePatient.deleteFromCloudEventually(self.store, usingKnowledgeVector: true)
                        }
                    }
                case .carePlan(let carePlan):
                    let _ = CarePlan(careKitEntity: carePlan, store: self.store){
                        copiedCarePlan in
                        guard let parseCarePlan = copiedCarePlan as? CarePlan else{return}
                        if carePlan.deletedDate == nil{
                            parseCarePlan.addToCloudInBackground(self.store, usingKnowledgeVector: true)
                        }else{
                            parseCarePlan.deleteFromCloudEventually(self.store, usingKnowledgeVector: true)
                        }
                    }
                case .contact(let contact):
                    let _ = Contact(careKitEntity: contact, store: self.store){
                        copiedContact in
                        guard let parseContact = copiedContact as? Contact else{return}
                        if contact.deletedDate == nil{
                            parseContact.addToCloudInBackground(self.store, usingKnowledgeVector: true)
                        }else{
                            parseContact.deleteFromCloudEventually(self.store, usingKnowledgeVector: true)
                        }
                        
                    }
                case .task(let task):
                    
                    let _ = Task(careKitEntity: task, store: self.store){
                        copiedTask in
                        guard let parseTask = copiedTask as? Task else{return}
                        if task.deletedDate == nil{
                            parseTask.addToCloudInBackground(self.store, usingKnowledgeVector: true)
                        }else{
                            parseTask.deleteFromCloudEventually(self.store, usingKnowledgeVector: true)
                        }
                        
                    }
                case .outcome(let outcome):
                    Outcome.pushRevision(self.store, cloudClock: cloudVectorClock, outcome: outcome)
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
    
    func pullOutcomeRevisions(_ localVector: OCKRevisionRecord.KnowledgeVector, cloudVector: KnowledgeVector, cloudUUID:String, mergeRevision: @escaping (OCKRevisionRecord, @escaping (Error?) -> Void) -> Void, completion: @escaping (Error?) -> Void){
        
        guard let cloudKnowledgeVectorUUID = UUID(uuidString: cloudVector.uuid) else{
            let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
            mergeRevision(revision, completion)
            return
        }
        let localClock = localVector.clock(for: cloudKnowledgeVectorUUID)
        
        let query = Outcome.query()!
        query.whereKey(kPCKOutcomeClockKey, greaterThanOrEqualTo: localClock)
        query.includeKeys([kPCKOutcomeTaskKey,kPCKOutcomeValuesKey,kPCKOutcomeNotesKey])
        query.findObjectsInBackground{ (objects,error) in
            guard let outcomes = objects as? [Outcome] else{
                let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
                mergeRevision(revision, completion)
                return
            }
            let pulledOutcomes = outcomes.compactMap{$0.convertToCareKit()}
            let outcomeEntities = pulledOutcomes.compactMap{OCKEntity.outcome($0)}
            let data = cloudVector.vector.data(using: .utf8)!
            let revision:OCKRevisionRecord!
            do {
                let vector = try JSONDecoder().decode(OCKRevisionRecord.KnowledgeVector.self, from: data)
                revision = OCKRevisionRecord(entities: outcomeEntities, knowledgeVector: vector)
            }catch{
                print("Error in ParseRemoteSynchronizationManager.pullRevisions(). Couldn't decode vector \(data)")
                revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
            }
            mergeRevision(revision, completion)
        }
    }
    
}
