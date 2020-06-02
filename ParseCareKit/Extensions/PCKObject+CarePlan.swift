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
    
    public func save(_ carePlan: CarePlan, completion: @escaping(Bool,Error?) -> Void){
        carePlan.stampRelationalEntities()
        carePlan.saveInBackground{ (success, error) in
    
            if success{
                print("Successfully added CarePlan \(carePlan) to Cloud")
                
                carePlan.linkRelated{
                    (linked,_) in
                    
                    if linked{
                        carePlan.saveInBackground()
                    }
                    
                    //Fix versioning doubly linked list if it's broken in the cloud
                    if carePlan.previous != nil {
                        if carePlan.previous!.next == nil{
                            carePlan.previous!.next = carePlan
                            carePlan.previous!.next!.saveInBackground(){
                                (success,_) in
                                if success{
                                    carePlan.fixVersionLinkedList(carePlan.previous! as! CarePlan, backwards: true)
                                }
                            }
                        }
                    }
                    
                    if carePlan.next != nil {
                        if carePlan.next!.previous == nil{
                            carePlan.next!.previous = carePlan
                            carePlan.next!.previous!.saveInBackground(){
                                (success,_) in
                                if success{
                                    carePlan.fixVersionLinkedList(carePlan.next! as! CarePlan, backwards: false)
                                }
                            }
                        }
                    }
                    completion(success,error)
                }
            }else{
                print("Error in CarePlan.save(). \(String(describing: error))")
                completion(success,error)
            }
        }
    }
    
    public func compareUpdate(_ parse: CarePlan, usingKnowledgeVector: Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void){
        if !usingKnowledgeVector{
            guard let careKitLastUpdated = self.updatedDate,
                let cloudUpdatedAt = parse.updatedDate else{
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
            }else if ((cloudUpdatedAt > careKitLastUpdated) || !overwriteRemote) {
                
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
}
