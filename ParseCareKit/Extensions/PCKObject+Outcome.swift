//
//  PCKObject+Outcome.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/28/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import Parse
import CareKitStore

extension PCKObject{

    public func saveAndCheckRemoteID(_ outcome: Outcome, usingKnowledgeVector: Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = UUID(uuidString: outcome.uuid) else {
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        outcome.stampRelationalEntities()
        outcome.saveInBackground{ [weak self] (success, error) in
            
            guard let self = self else{
                completion(false,ParseCareKitError.cantUnwrapSelf)
                return
            }
            
            if success{
                print("Successfully saved \(self) in Cloud.")
                
                var careKitQuery = OCKOutcomeQuery()
                careKitQuery.tags = [outcome.entityId]
                //careKitQuery.uuids = [entityUUID]
                self.store.fetchOutcome(query: careKitQuery, callbackQueue: .global(qos: .background)){ [weak self]
                    result in
                    
                    guard let self = self else{
                        completion(false,ParseCareKitError.cantUnwrapSelf)
                        return
                    }
                    
                    switch result{
                    case .success(var mutableOutcome):
                        var needToUpdate = false
                        if mutableOutcome.remoteID == nil{
                            mutableOutcome.remoteID = outcome.objectId
                            needToUpdate = true
                        }else if mutableOutcome.remoteID! != outcome.objectId!{
                            mutableOutcome.remoteID = outcome.objectId
                            needToUpdate = true
                        }
                        
                        //EntityIds are custom, make sure to add them as a tag for querying
                        if let outcomeTags = mutableOutcome.tags{
                            if !outcomeTags.contains(outcome.uuid){
                                mutableOutcome.tags!.append(outcome.uuid)
                                needToUpdate = true
                            }
                            if !outcomeTags.contains(outcome.entityId){
                                mutableOutcome.tags!.append(outcome.entityId)
                                needToUpdate = true
                            }
                        }else{
                            mutableOutcome.tags = [outcome.uuid, outcome.entityId]
                            needToUpdate = true
                        }
                        
                        outcome.values.forEach{
                            for (index,value) in mutableOutcome.values.enumerated(){
                                guard let uuid = OutcomeValue.getUUIDFromCareKitEntity(value),
                                    uuid == $0.uuid else{
                                    continue
                                }
                                
                                //Tag associatied outcome with this outcomevalue
                                if let outcomeValueTags = mutableOutcome.values[index].tags{
                                    if !outcomeValueTags.contains(outcome.uuid){
                                        mutableOutcome.values[index].tags!.append(outcome.uuid)
                                        needToUpdate = true
                                    }
                                    if !outcomeValueTags.contains(outcome.entityId){
                                        mutableOutcome.values[index].tags!.append(outcome.entityId)
                                        needToUpdate = true
                                    }
                                }else{
                                    mutableOutcome.values[index].tags = [outcome.uuid, outcome.entityId]
                                    needToUpdate = true
                                }
                                
                                if mutableOutcome.values[index].remoteID == nil{
                                    mutableOutcome.values[index].remoteID = $0.objectId
                                    needToUpdate = true
                                }
                                
                                guard let updatedValue = $0.compareUpdate(mutableOutcome.values[index], parse: $0, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, newClockValue: outcome.logicalClock, store: self.store) else {continue}
                                mutableOutcome.values[index] = updatedValue
                                needToUpdate = true
                            }
                        }
                        
                        if needToUpdate{
                            self.store.updateOutcome(mutableOutcome){
                                result in
                                switch result{
                                case .success(let updatedContact):
                                    print("Updated remoteID of \(outcome.parseClassName): \(updatedContact)")
                                    completion(true,nil)
                                case .failure(let error):
                                    print("Error updating remoteID. \(error)")
                                    completion(false,error)
                                }
                            }
                        }else{
                            completion(true,nil)
                        }
                    case .failure(let error):
                        print("Error in Outcome.saveAndCheckRemoteID(). \(error)")
                        completion(false,error)
                    }
                }
            }else{
                print("Error in CarePlan.addToCloud(). \(String(describing: error))")
                completion(false,error)
            }
        }
    }
    
    public func compareUpdate(_ careKit: OCKOutcome, parse: Outcome, usingKnowledgeVector:Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void){
        
        if !usingKnowledgeVector{
            guard let careKitLastUpdated = careKit.updatedDate,
                let cloudUpdatedAt = parse.updatedDate else{
                completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                return
            }
            if ((cloudUpdatedAt < careKitLastUpdated) || overwriteRemote){
                parse.copyCareKit(careKit, clone: overwriteRemote){[weak self] _ in
                    
                    guard let self = self else{
                        completion(false,ParseCareKitError.cantUnwrapSelf)
                        return
                    }
                    
                    //An update may occur when Internet isn't available, try to update at some point
                    self.saveAndCheckRemoteID(parse, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote){
                        (success,error) in
                        
                        if !success{
                            print("Error in \(self.parseClassName).updateCloud(). Couldn't update in cloud: \(careKit)")
                        }else{
                            print("Successfully updated \(self.parseClassName) \(self) in the Cloud")
                        }
                        completion(success,error)
                    }
                }
            }else if cloudUpdatedAt > careKitLastUpdated {
                guard let updatedCarePlanFromCloud = parse.convertToCareKit() else{
                    completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                    return
                }
                    
                store.updateAnyOutcome(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(_):
                        print("Successfully updated \(self.parseClassName) \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                        completion(true,nil)
                    case .failure(let error):
                        print("Error updating \(self.parseClassName) \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                        completion(false,error)
                    }
                }
            }else{
                completion(true,nil)
            }
        }else{
            if ((self.logicalClock > parse.logicalClock) || overwriteRemote){
                parse.copyCareKit(careKit, clone: overwriteRemote){[weak self] _ in
                    guard let self = self else{
                        completion(false,ParseCareKitError.cantUnwrapSelf)
                        return
                    }
                    
                    parse.logicalClock = self.logicalClock //Place stamp on this entity since it's correctly linked to Parse
                    self.saveAndCheckRemoteID(parse, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote){
                        (success,error) in
                        
                        if !success{
                            print("Error in \(self.parseClassName).updateCloud(). Couldn't update in cloud: \(careKit)")
                        }else{
                            print("Successfully updated \(self.parseClassName) \(self) in the Cloud")
                        }
                        completion(success,error)
                    }
                }
                
            }else if self.logicalClock == parse.logicalClock{
               
                //This should throw a conflict as pullRevisions should have made sure it doesn't happen. Ignoring should allow the newer one to be pulled from the cloud, so we do nothing here
                print("Warning in \(self.parseClassName).compareUpdate(). KnowledgeVector in Cloud \(parse.logicalClock) == \(self.logicalClock). This means the data is already synced. Local: \(self)... Cloud: \(parse)")
                completion(true,nil)
                
            }else{
                //This should throw a conflict as pullRevisions should have made sure it doesn't happen. Ignoring should allow the newer one to be pulled from the cloud, so we do nothing here
                print("Warning in \(self.parseClassName).compareUpdate(). KnowledgeVector in Cloud \(parse.logicalClock) > \(self.logicalClock). This should never occur. It should get fixed in next pullRevision. Local: \(self)... Cloud: \(parse)")
                completion(false,ParseCareKitError.cloudClockLargerThanLocalWhilePushRevisions)
            }
        }
    }
    
    public func compareDelete(_ parse: Outcome, usingKnowledgeVector:Bool, completion: @escaping(Bool,Error?) -> Void){
        guard let careKitLastUpdated = self.updatedDate,
            let cloudUpdatedAt = parse.updatedDate else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        if ((cloudUpdatedAt <= careKitLastUpdated) || usingKnowledgeVector) {
            parse.values.forEach{
                $0.deleteInBackground()
            }
            parse.notes?.forEach{
                $0.deleteInBackground()
            }
            parse.deleteInBackground{
                (success, error) in
                if !success{
                    print("Error in \(self.parseClassName).deleteFromCloud(). \(String(describing: error))")
                }else{
                    print("Successfully deleted \(self.parseClassName) \(self) in the Cloud")
                }
                completion(success,error)
            }
        }else {
            guard let updatedCarePlanFromCloud = parse.convertToCareKit() else{
                completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                return
            }
            store.updateAnyOutcome(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                result in
                switch result{
                case .success(_):
                    print("Successfully deleting \(self.parseClassName) \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    completion(true,nil)
                case .failure(let error):
                    print("Error deleting \(self.parseClassName) \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    completion(false,error)
                }
            }
        }
    }
    
    public class func encodeCareKitToDictionary(_ entity: OCKOutcome)->[String:Any]?{
        let jsonDictionary:[String:Any]
        do{
            let data = try JSONEncoder().encode(entity)
            jsonDictionary = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers,.mutableLeaves]) as! [String:Any]
        }catch{
            print("Error in Outcome.encodeCareKitToDictionary(). \(error)")
            return nil
        }
        
        return jsonDictionary
    }
    
    public func decodedCareKitObject(_ task: Task?, taskOccurrenceIndex: Int, values: [OutcomeValue])->OCKOutcome?{
        guard let relatedTask = task,
            let taskUUID = UUID(uuidString: relatedTask.uuid),
            let createdDate = self.createdDate?.timeIntervalSinceReferenceDate,
            let updatedDate = self.updatedDate?.timeIntervalSinceReferenceDate else{
                print("Error in \(parseClassName).decodedCareKitObject(). Missing either task \(String(describing: task)), createdDate \(String(describing: self.createdDate)) or updatedDate \(String(describing: self.updatedDate))")
            return nil
        }
        let outcomeValues = values.compactMap{$0.convertToCareKit()}
        let tempEntity = OCKOutcome(taskUUID: taskUUID, taskOccurrenceIndex: taskOccurrenceIndex, values: outcomeValues)
        //Create bare CareKit entity from json
        guard var json = Outcome.encodeCareKitToDictionary(tempEntity) else{return nil}
        json["uuid"] = self.uuid
        json["createdDate"] = createdDate
        json["updatedDate"] = updatedDate
        let entity:OCKOutcome!
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            entity = try JSONDecoder().decode(OCKOutcome.self, from: data)
        }catch{
            print("Error in \(parseClassName).decodedCareKitObject(). \(error)")
            return nil
        }
        return entity
    }
    
    public func findOutcome(_ uuid:UUID?, completion: @escaping(Outcome?) -> Void){
       
        guard let _ = PFUser.current(),
            let uuidString = uuid?.uuidString else{
            completion(nil)
            return
        }
        
        let query = Outcome.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: uuidString)
        query.includeKeys([kPCKOutcomeTaskKey,kPCKOutcomeValuesKey,kPCKObjectNotesKey])
        query.getFirstObjectInBackground(){
            (object, parseError) in
            
            guard let foundObject = object as? Outcome else{
                completion(nil)
                return
            }
            completion(foundObject)
        }
    }
    
    public func fetchRelatedTask(_ taskUUID:UUID, completion: @escaping(Task?) -> Void){
        var query = OCKTaskQuery()
        query.uuids = [taskUUID]
        store.fetchTasks(query: query, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let anyTask):
                
                guard let task = anyTask.first else{
                    completion(nil)
                    return
                }
                
                guard let taskRemoteID = task.remoteID else{
                    completion(nil)
                    return
                }
                completion(Task(withoutDataWithObjectId: taskRemoteID))
                
            case .failure(let error):
                print("Error in \(self.parseClassName).copyCareKit(). \(error)")
                completion(nil)
            }
        }
    }
    
}
