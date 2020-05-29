//
//  PCKObject+CarePlan.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/28/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import Parse
import CareKitStore

extension PCKObject{
    
    public func saveAndCheckRemoteID(_ carePlan: CarePlan, completion: @escaping(Bool,Error?) -> Void){
        guard let carePlanUUID = UUID(uuidString: carePlan.uuid) else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        carePlan.stampRelationalEntities()
        carePlan.saveInBackground{[weak self] (success, error) in
            
            guard let self = self else{
                completion(false,ParseCareKitError.cantUnwrapSelf)
                return
            }
            
            if success{
                //Only save data back to CarePlanStore if it's never been saved before
                var careKitQuery = OCKCarePlanQuery()
                careKitQuery.uuids = [carePlanUUID]
                self.store.fetchCarePlans(query: careKitQuery, callbackQueue: .global(qos: .background)){ [weak self]
                    result in
                    
                    guard let self = self else{
                        completion(false,ParseCareKitError.cantUnwrapSelf)
                        return
                    }
                    
                    switch result{
                    case .success(let entities):
                        guard var mutableEntity = entities.first else{
                            completion(false, nil)
                            return
                        }
                        if mutableEntity.remoteID == nil{
                            mutableEntity.remoteID = carePlan.objectId
                            self.store.updateCarePlan(mutableEntity, callbackQueue: .global(qos: .background)){
                                result in
                                switch result{
                                case .success(let updatedEntity):
                                    print("Successfully added CarePlan \(updatedEntity) to Cloud")
                                    completion(true, nil)
                                case .failure(let error):
                                    print("Error in CarePlan.saveAndCheckRemoteID() adding CarePlan \(mutableEntity) to Cloud")
                                    completion(false, error)
                                }
                            }
                        }else{
                            if mutableEntity.remoteID! != carePlan.objectId{
                                //Neesd to update remoteId
                                mutableEntity.remoteID = carePlan.objectId
                                self.store.updateAnyCarePlan(mutableEntity, callbackQueue: .global(qos: .background)){
                                    result in
                                    switch result{
                                    case .success(let updatedEntity):
                                        print("Successfully added CarePlan \(updatedEntity) to Cloud")
                                        completion(true, nil)
                                    case .failure(let error):
                                        print("Error in CarePlan.saveAndCheckRemoteID() adding CarePlan \(mutableEntity) to Cloud")
                                        completion(false, error)
                                    }
                                }
                            }else{
                                completion(true, nil)
                            }
                        }
                    case .failure(let error):
                        print("Error in Contact.addToCloud(). \(error)")
                        completion(false, error)
                    }
                }
            }else{
                /*guard let unwrappedError = error else{
                    completion(false, error)
                    return
                }*/
                print("Error in CarePlan.saveAndCheckRemoteID(). \(String(describing: error))")
                completion(false, error)
            }
        }
    }
    
    public func compareUpdate(_ careKit: OCKCarePlan, parse: CarePlan, usingKnowledgeVector: Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void){
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
                    self.saveAndCheckRemoteID(parse){
                        (success,error) in
                        if !success{
                            print("Error in CarePlan.updateCloud(). Couldn't update \(careKit)")
                        }else{
                            print("Successfully updated CarePlan \(self) in the Cloud")
                        }
                        completion(success,error)
                    }
                }
            }else if ((cloudUpdatedAt > careKitLastUpdated) || !overwriteRemote) {
                //The cloud version is newer than local, update the local version instead
                guard let updatedCarePlanFromCloud = parse.convertToCareKit() else{
                    completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                    return
                }
                store.updateAnyCarePlan(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(_):
                        print("Successfully updated CarePlan \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                        completion(true,nil)
                    case .failure(let error):
                        print("Error updating CarePlan \(updatedCarePlanFromCloud) from the Cloud to CareStore")
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
                    self.saveAndCheckRemoteID(parse){
                        (success,error) in
                        
                        if !success{
                            print("Error in CarePlan.updateCloud(). Couldn't update \(careKit)")
                        }else{
                            print("Successfully updated CarePlan \(self) in the Cloud")
                        }
                        completion(success,error)
                    }
                }
            } else if self.logicalClock == parse.logicalClock{
               
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
    
    public func compareDelete(_ local: CarePlan, parse: CarePlan, usingKnowledgeVector:Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void){
        
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
                    
                store.updateCarePlan(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
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
    
    public class func encodeCareKitToDictionary(_ entity: OCKCarePlan)->[String:Any]?{
        let jsonDictionary:[String:Any]
        do{
            let data = try JSONEncoder().encode(entity)
            jsonDictionary = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers,.mutableLeaves]) as! [String:Any]
        }catch{
            print("Error in CarePlan.encodeCareKitToDictionary(). \(error)")
            return nil
        }
        
        return jsonDictionary
    }
    
    public func findCarePlan(_ uuid:UUID?, completion: @escaping(CarePlan?) -> Void){
       
        guard let _ = PFUser.current(),
        let uuidString = uuid?.uuidString else{
            completion(nil)
            return
        }
        
        let query = CarePlan.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: uuidString)
        query.includeKeys([kPCKCarePlanPatientKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.getFirstObjectInBackground(){
            (object, parseError) in
            
            guard let foundObject = object as? CarePlan else{
                completion(nil)
                return
            }
            completion(foundObject)
        }
    }
    
    public func fetchRelatedPatient(_ patientUUID: UUID, completion: @escaping(Patient?)->Void){
        
        //ID's are the same for related Plans
        var query = OCKPatientQuery()
        query.uuids = [patientUUID]
        store.fetchPatients(query: query, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let authors):
                //Should only be one patient returned
                guard let careKitPatient = authors.first else{
                    completion(nil)
                    return
                }
                
                guard let authorRemoteId = careKitPatient.remoteID else{
                    completion(nil)
                    return
                }
                
                completion(Patient(withoutDataWithObjectId: authorRemoteId))
                
            case .failure(_):
                completion(nil)
            }
        }
    }
}
