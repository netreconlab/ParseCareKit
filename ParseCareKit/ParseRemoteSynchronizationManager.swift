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

class ParseRemoteSynchronizationManager: NSObject, OCKRemoteSynchronizable {
    var delegate: OCKRemoteSynchronizationDelegate?
    
    var automaticallySynchronizes: Bool
    let store:OCKStore!
    
    public init(_ store: OCKStore){
        self.store = store
        self.automaticallySynchronizes = true
        super.init()
    }
    
    public func pullRevisions(since knowledgeVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord, @escaping (Error?) -> Void) -> Void, completion: @escaping (Error?) -> Void) {
        
    }
    
    public func pushRevisions(deviceRevision: OCKRevisionRecord, overwriteRemote: Bool, completion: @escaping (Error?) -> Void) {
        deviceRevision.entities.forEach{
            switch $0{
                
            case .patient(let patient):
                let _ = User(careKitEntity: patient, store: self.store){
                    copiedPatient in
                    guard let patient = copiedPatient as? User else{return}
                    patient.addToCloudInBackground(self.store)
                }
            case .carePlan(let carePlan):
                let _ = CarePlan(careKitEntity: carePlan, store: self.store){
                    copiedCarePlan in
                    guard let carePlan = copiedCarePlan as? CarePlan else{return}
                    carePlan.addToCloudInBackground(self.store)
                }
            case .contact(let contact):
                let _ = Contact(careKitEntity: contact, store: self.store){
                    copiedContact in
                    guard let contact = copiedContact as? Contact else{return}
                    contact.addToCloudInBackground(self.store)
                }
            case .task(let task):
                let _ = Task(careKitEntity: task, store: self.store){
                    copiedTask in
                    guard let task = copiedTask as? Task else{return}
                    task.addToCloudInBackground(self.store)
                }
            case .outcome(let outcome):
                let _ = Outcome(careKitEntity: outcome, store: self.store){
                    copiedOutcome in
                    guard let outcome = copiedOutcome as? Outcome else{return}
                    outcome.addToCloudInBackground(self.store)
                }
            }
        }
    }
    
    public func chooseConflictResolutionPolicy(_ conflict: OCKMergeConflictDescription, completion: @escaping (OCKMergeConflictResolutionPolicy) -> Void) {
        
    }
    
    
    
    
    
    
}
