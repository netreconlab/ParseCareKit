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
    
    public func save(_ patient: Patient, completion: @escaping(Bool,Error?) -> Void){
        
        patient.stampRelationalEntities()
        patient.saveInBackground{
            (success, error) in
        
            if success{
                print("Successfully saved \(patient) in Cloud.")
            }else{
                print("Error in Patient.addToCloud(). \(String(describing: error))")
                
            }
            completion(success,error)
        }
    }
    
    func compareUpdate(_ parse: Patient, usingKnowledgeVector:Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void){
        if !usingKnowledgeVector{
            
            guard let careKitLastUpdated = self.updatedDate,
                let cloudUpdatedAt = parse.updatedDate else{
                    //This occurs only on a Patient when they have logged in for the first time
                    //and CareKit and Parse isn't properly synced. Basically this is the first
                    //time the local dates are pushed to the cloud
                    /*parse.copy(self)
                    self.save(parse){
                        (success,error) in
                        if !success{
                            print("Error in \(parse.parseClassName).compareUpdate(). Error updating \(self)")
                        }else{
                            print("Successfully updated Patient \(parse) in the Cloud")
                        }
                        completion(success,error)
                    }*/
                    completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                return
            }
            
            if ((cloudUpdatedAt < careKitLastUpdated) || overwriteRemote){
                parse.copy(self)
                self.save(parse){
                    (success,error) in
                    if !success{
                        print("Error in \(parse.parseClassName).compareUpdate(). Error updating \(self)")
                    }else{
                        print("Successfully updated Patient \(parse) in the Cloud")
                    }
                    completion(success,error)
                }
            }else if cloudUpdatedAt > careKitLastUpdated{
                //The cloud version is newer than local, update the local version instead
                print("Error updating \(self) from the Cloud to CareStore")
                completion(false,ParseCareKitError.cloudVersionNewerThanLocal)
            }else{
                completion(true,nil)
            }
        }else{
            if ((self.logicalClock > parse.logicalClock) || overwriteRemote){
                parse.copy(self)
                self.save(parse){
                    (success,error) in
                    if !success{
                        print("Error in \(parse.parseClassName).compareUpdate(). Error updating \(self)")
                    }else{
                        print("Successfully updated Patient \(parse) in the Cloud")
                    }
                    completion(success,error)
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
    
    public func findPatient(_ uuid:UUID?, completion: @escaping(Patient?) -> Void){
       
        guard let _ = PFUser.current(),
            let uuidString = uuid?.uuidString else{
            completion(nil)
            return
        }
        
        let query = Patient.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: uuidString)
        query.includeKeys([kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.getFirstObjectInBackground(){
            (object, parseError) in
            
            guard let foundObject = object as? Patient else{
                completion(nil)
                return
            }
            completion(foundObject)
        }
    }
}
