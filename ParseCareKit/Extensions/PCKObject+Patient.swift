//
//  PCKObject+Patient.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/28/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import Parse
import CareKitStore

extension PCKObject{
    
    class func saveAndCheckRemoteID(_ patient: Patient, store: OCKAnyStoreProtocol, completion: @escaping(Bool,Error?) -> Void){
        guard let store = store as? OCKStore,
            let patientUUID = UUID(uuidString: patient.uuid) else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        patient.stampRelationalEntities()
        patient.saveInBackground{
            (success, error) in
            if success{
                print("Successfully saved \(self) in Cloud.")
                //Only save data back to CarePlanStore if it's never been saved before
                var careKitQuery = OCKPatientQuery()
                careKitQuery.uuids = [patientUUID]
                store.fetchPatients(query: careKitQuery, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(let entities):
                        guard var mutableEntity = entities.first else{
                            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                            return
                        }
                        if mutableEntity.remoteID == nil{
                            mutableEntity.remoteID = patient.objectId
                            store.updateAnyPatient(mutableEntity, callbackQueue: .global(qos: .background)){
                                result in
                                switch result{
                                case .success(let updatedObject):
                                    print("Successfully added Patient \(updatedObject) to Cloud")
                                    completion(true, nil)
                                case .failure(let error):
                                    print("Error in \(patient.parseClassName).addToCloud() adding Patient \(mutableEntity) to Cloud. \(error)")
                                    completion(false,error)
                                }
                            }
                        }else{
                            if mutableEntity.remoteID! != patient.objectId{
                                mutableEntity.remoteID = patient.objectId
                                store.updateAnyPatient(mutableEntity, callbackQueue: .global(qos: .background)){
                                    result in
                                    switch result{
                                    case .success(let updatedObject):
                                        print("Successfully added Patient \(updatedObject) to Cloud")
                                        completion(true, nil)
                                    case .failure(let error):
                                        print("Error in \(patient.parseClassName).addToCloud() adding Patient \(mutableEntity) to Cloud. \(error)")
                                        completion(false,error)
                                    }
                                }
                            }else{
                                completion(true,nil)
                            }
                        }
                    case .failure(let error):
                        print("Error in Contact.addToCloud(). \(error)")
                        completion(false,error)
                    }
                }
            }else{
                print("Error in Patient.addToCloud(). \(String(describing: error))")
                completion(false,error)
            }
        }
    }
    
    func compareUpdate(_ careKit: OCKPatient, parse: Patient, store: OCKStore, usingKnowledgeVector:Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void){
        if !usingKnowledgeVector{
            guard let careKitLastUpdated = careKit.updatedDate,
                let cloudUpdatedAt = parse.updatedDate else{
                    //This occurs only on a Patient when they have logged in for the first time
                    //and CareKit and Parse isn't properly synced. Basically this is the first
                    //time the local dates are pushed to the cloud
                    parse.copyCareKit(careKit, clone: overwriteRemote, store: store){
                        _ in
                        Patient.saveAndCheckRemoteID(parse, store: store){
                            (success,error) in
                            if !success{
                                print("Error in \(self.parseClassName).compareUpdate(). Error updating \(careKit)")
                            }else{
                                print("Successfully updated Patient \(self) in the Cloud")
                            }
                            completion(success,error)
                        }
                        
                    }
                    return
            }
            if ((cloudUpdatedAt < careKitLastUpdated) || overwriteRemote){
                parse.copyCareKit(careKit, clone: overwriteRemote, store: store){ _ in
                    //An update may occur when Internet isn't available, try to update at some point
                    Patient.saveAndCheckRemoteID(parse, store: store){
                        (success,error) in
                        if !success{
                            print("Error in \(self.parseClassName).updateCloud(). Error updating \(careKit)")
                        }else{
                            print("Successfully updated Patient \(self) in the Cloud")
                        }
                        completion(success,error)
                    }
                }
            }else if cloudUpdatedAt > careKitLastUpdated{
                //The cloud version is newer than local, update the local version instead
                guard let updatedPatientFromCloud = parse.convertToCareKit() else{
                    completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                    return
                }
                store.updateAnyPatient(updatedPatientFromCloud, callbackQueue: .global(qos: .background)){
                    result in
                    
                    switch result{
                    case .success(_):
                        print("Successfully updated Patient \(updatedPatientFromCloud) from the Cloud to CareStore")
                        completion(true,nil)
                    case .failure(let error):
                        print("Error updating Patient \(updatedPatientFromCloud) from the Cloud to CareStore")
                        completion(false,error)
                    }
                }
            }else{
                completion(true,nil)
            }
        }else{
            if ((self.logicalClock > parse.logicalClock) || overwriteRemote){
                parse.copyCareKit(careKit, clone: overwriteRemote, store: store){ _ in
                    parse.logicalClock = self.logicalClock //Place stamp on this entity since it's correctly linked to Parse
                    //An update may occur when Internet isn't available, try to update at some point
                    Patient.saveAndCheckRemoteID(parse, store: store){
                        (success,error) in
                        if !success{
                            print("Error in \(self.parseClassName).updateCloud(). Error updating \(careKit)")
                        }else{
                            print("Successfully updated Patient \(self) in the Cloud")
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
    
    func compareDelete(_ parse: Patient, store: OCKStore, completion: @escaping(Bool,Error?) -> Void){
        guard let careKitLastUpdated = self.updatedDate,
            let cloudUpdatedAt = parse.updatedDate else{
            return
        }
        
        if cloudUpdatedAt <= careKitLastUpdated{
            parse.deleteInBackground{
                (success, error) in
                if !success{
                    print("Error in Patient.deleteFromCloud(). \(String(describing: error))")
                }else{
                    print("Successfully deleted Patient \(self) in the Cloud")
                }
                completion(success,error)
            }
        }else {
            guard let updatedCarePlanFromCloud = parse.convertToCareKit() else {return}
            store.updateAnyPatient(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                result in
                switch result{
                case .success(_):
                    print("Successfully deleting Patient \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    completion(true,nil)
                case .failure(let error):
                    print("Error deleting Patient \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    completion(false,error)
                }
            }
        }
    }
    
    open class func encodeCareKitToDictionary(_ entity: OCKPatient)->[String:Any]?{
        let jsonDictionary:[String:Any]
        do{
            let data = try JSONEncoder().encode(entity)
            jsonDictionary = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers,.mutableLeaves]) as! [String:Any]
        }catch{
            print("Error in Patient.encodeCareKitToDictionary(). \(error)")
            return nil
        }
        
        return jsonDictionary
    }
}
