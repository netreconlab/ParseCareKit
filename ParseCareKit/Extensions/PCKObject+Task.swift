//
//  PCKObject+Task.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/28/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import Parse
import CareKitStore

extension PCKObject{

    public func saveAndCheckRemoteID(_ task: Task, completion: @escaping(Bool,Error?) -> Void){
        guard let taskUUID = UUID(uuidString: task.uuid) else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        task.stampRelationalEntities()
        task.saveInBackground{[weak self] (success, error) in
        
            if success{
                
                guard let self = self else{
                    completion(false,ParseCareKitError.cantUnwrapSelf)
                    return
                }
                
                print("Successfully saved \(self) in Cloud.")
                //Need to save remoteId for this and all relational data
                var careKitQuery = OCKTaskQuery()
                careKitQuery.uuids = [taskUUID]
                self.store.fetchTasks(query: careKitQuery, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(let entities):
                        guard var mutableEntity = entities.first else{
                            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                            return
                        }
                        if mutableEntity.remoteID == nil{
                            mutableEntity.remoteID = task.objectId
                            self.store.updateAnyTask(mutableEntity){
                                result in
                                switch result{
                                case .success(let updatedTask):
                                    print("Updated remoteID of task \(updatedTask)")
                                    completion(true, nil)
                                case .failure(let error):
                                    print("Error in \(task.parseClassName).addToCloud() updating remoteID. \(error)")
                                    completion(false,error)
                                }
                            }
                        }else{
                            if mutableEntity.remoteID! != task.objectId{
                                mutableEntity.remoteID = task.objectId
                                self.store.updateAnyTask(mutableEntity){
                                    result in
                                    switch result{
                                    case .success(let updatedTask):
                                        print("Updated remoteID of task \(updatedTask)")
                                        completion(true, nil)
                                    case .failure(let error):
                                        print("Error in \(task.parseClassName).addToCloud() updating remoteID. \(error)")
                                        completion(false,error)
                                    }
                                }
                            }else{
                                completion(true,nil)
                            }
                            return
                        }
                    case .failure(let error):
                        print("Error in Contact.addToCloud(). \(error)")
                        completion(false,error)
                    }
                }
            }else{
                print("Error in \(task.parseClassName).addToCloud(). \(String(describing: error))")
                completion(false,error)
            }
        }
    }
    
    public func compareUpdate(_ careKit: OCKTask, parse: Task, usingKnowledgeVector:Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void){
        if !usingKnowledgeVector{
            guard let careKitLastUpdated = careKit.updatedDate,
                let cloudUpdatedAt = parse.updatedDate else{
                completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                return
            }
            if ((cloudUpdatedAt < careKitLastUpdated) || overwriteRemote){
                parse.copyCareKit(careKit, clone: overwriteRemote){ [weak self] _ in
                    
                    guard let self = self else{
                        completion(false,ParseCareKitError.cantUnwrapSelf)
                        return
                    }
                    
                    //An update may occur when Internet isn't available, try to update at some point
                    self.saveAndCheckRemoteID(parse){
                        (success,error) in
                        
                        if !success{
                            print("Error in \(self.parseClassName).compareUpdate(). Error updating \(careKit)")
                        }else{
                            print("Successfully updated Task \(self) in the Cloud")
                        }
                        completion(success,error)
                    }
                }
            }else if cloudUpdatedAt > careKitLastUpdated {
                //The cloud version is newer than local, update the local version instead
                guard let updatedCarePlanFromCloud = parse.convertToCareKit() else{
                    completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                    return
                }
                store.updateAnyTask(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                    result in
                    
                    switch result{
                        
                    case .success(_):
                        print("Successfully updated Task \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                        completion(true,nil)
                    case .failure(let error):
                        print("Error updating Task \(updatedCarePlanFromCloud) from the Cloud to CareStore")
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
                    //An update may occur when Internet isn't available, try to update at some point
                    self.saveAndCheckRemoteID(parse){
                        (success,error) in
                        
                        if !success{
                            print("Error in \(self.parseClassName).compareUpdate(). Error updating \(careKit)")
                        }else{
                            print("Successfully updated Task \(self) in the Cloud")
                        }
                        completion(success,nil)
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
    
    func compareDelete(_ local: Task, parse: Task, usingKnowledgeVector:Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void){
        
        if !usingKnowledgeVector{
            guard let careKitLastUpdated = self.updatedDate,
                let cloudUpdatedAt = parse.updatedDate else{
                completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                return
            }
            
            if ((cloudUpdatedAt < careKitLastUpdated) || overwriteRemote){
                guard let careKit = local.convertToCareKit() else{
                    completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                    return
                }
                parse.copyCareKit(careKit, clone: overwriteRemote){[weak self] _ in
                    
                    guard let self = self else{
                        completion(false,ParseCareKitError.cantUnwrapSelf)
                        return
                    }
                    
                    //An update may occur when Internet isn't available, try to update at some point
                    self.saveAndCheckRemoteID(parse){
                        (success,error) in
                        
                        if !success{
                            print("Error in \(self.parseClassName).compareDelete(). Couldn't delete in cloud: \(careKit)")
                        }else{
                            print("Successfully deleted \(self.parseClassName) \(self) in the Cloud")
                        }
                        completion(success,error)
                    }
                }
            }else if cloudUpdatedAt > careKitLastUpdated {
                guard let updatedCarePlanFromCloud = parse.convertToCareKit() else{
                    completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                    return
                }
                    
                store.updateTask(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(_):
                        print("Successfully deleted \(self.parseClassName) \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                        completion(true,nil)
                    case .failure(let error):
                        print("Error deleting \(self.parseClassName) \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                        completion(false,error)
                    }
                }
            }else{
                completion(true,nil)
            }
        }else{
            if ((self.logicalClock > parse.logicalClock) || overwriteRemote){
                guard let careKit = local.convertToCareKit() else{
                    completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                    return
                }
                parse.copyCareKit(careKit, clone: overwriteRemote){[weak self] _ in
                    guard let self = self else{
                        completion(false,ParseCareKitError.cantUnwrapSelf)
                        return
                    }
                    
                    parse.logicalClock = self.logicalClock //Place stamp on this entity since it's correctly linked to Parse
                    self.saveAndCheckRemoteID(parse){
                        (success,error) in
                        
                        if !success{
                            print("Error in \(self.parseClassName).compareDelete(). Couldn't update in cloud: \(careKit)")
                        }else{
                            print("Successfully deleted \(self.parseClassName) \(self) in the Cloud")
                        }
                        completion(success,error)
                    }
                }
                
            }else if self.logicalClock == parse.logicalClock{
               
                //This should throw a conflict as pullRevisions should have made sure it doesn't happen. Ignoring should allow the newer one to be pulled from the cloud, so we do nothing here
                print("Warning in \(self.parseClassName).compareDelete(). KnowledgeVector in Cloud \(parse.logicalClock) == \(self.logicalClock). This means the data is already synced. Local: \(self)... Cloud: \(parse)")
                completion(true,nil)
                
            }else{
                //This should throw a conflict as pullRevisions should have made sure it doesn't happen. Ignoring should allow the newer one to be pulled from the cloud, so we do nothing here
                print("Warning in \(self.parseClassName).compareDelete(). KnowledgeVector in Cloud \(parse.logicalClock) > \(self.logicalClock). This should never occur. It should get fixed in next pullRevision. Local: \(self)... Cloud: \(parse)")
                completion(false,ParseCareKitError.cloudClockLargerThanLocalWhilePushRevisions)
            }
        }
    }
    
    public func findTask(_ uuid:UUID?, completion: @escaping(Task?) -> Void){
       
        guard let _ = PFUser.current(),
            let uuidString = uuid?.uuidString else{
            completion(nil)
            return
        }
        
        let query = Task.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: uuidString)
        query.includeKeys([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.getFirstObjectInBackground(){
            (object, parseError) in
            
            guard let foundObject = object as? Task else{
                completion(nil)
                return
            }
            completion(foundObject)
        }
    }
        
    
    public func fetchRelatedCarePlan(_ carePlanUUID:UUID, completion: @escaping(CarePlan?) -> Void){
       
        var query = OCKCarePlanQuery()
        query.uuids = [carePlanUUID]
        store.fetchCarePlans(query: query, callbackQueue: .global(qos: .background)){
            result in
            
            switch result{
            case .success(let plan):
                
                //Attempt to link based if entity is in the Cloud
                guard let foundPlan = plan.first,
                    let carePlanRemoteID = foundPlan.remoteID else{
                    //Local CarePlan hasn't been linked with it's Cloud version, see if we can link to Cloud version
                        completion(nil)
                        return
                }
                completion(CarePlan(withoutDataWithObjectId: carePlanRemoteID))
            case .failure(let error):
                print("Error in \(self.parseClassName).fetchRelatedCarePlan(). Error \(error)")
                completion(nil)
            }
        }
    }
    
    public class func encodeCareKitToDictionary(_ entity: OCKTask)->[String:Any]?{
        let jsonDictionary:[String:Any]
        do{
            let data = try JSONEncoder().encode(entity)
            jsonDictionary = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers,.mutableLeaves]) as! [String:Any]
        }catch{
            print("Error in Task.encodeCareKitToDictionary(). \(error)")
            return nil
        }
        
        return jsonDictionary
    }
}
