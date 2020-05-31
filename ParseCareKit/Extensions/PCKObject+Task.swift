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

    public func save(_ task: Task, completion: @escaping(Bool,Error?) -> Void){
       
        task.stampRelationalEntities()
        task.saveInBackground{(success, error) in
        
            if success{
                print("Successfully saved \(task) in Cloud.")
                
                //Fix versioning doubly linked list if it's broken in the cloud
                if task.previous != nil {
                    if task.previous!.next == nil{
                        task.previous!.next = task
                        task.previous!.next!.saveInBackground(){
                            (success,_) in
                            if success{
                                task.fixVersionLinkedList(task.previous! as! Task, backwards: true)
                            }
                        }
                    }
                }
                
                if task.next != nil {
                    if task.next!.previous == nil{
                        task.next!.previous = task
                        task.next!.previous!.saveInBackground(){
                            (success,_) in
                            if success{
                                task.fixVersionLinkedList(task.next! as! Task, backwards: false)
                            }
                        }
                    }
                }
                
            }else{
                print("Error in \(task.parseClassName).addToCloud(). \(String(describing: error))")
            }
            completion(success,error)
        }
    }
    
    public func compareUpdate(_ parse: Task, usingKnowledgeVector:Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void){
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
            }else if cloudUpdatedAt > careKitLastUpdated {
                //The cloud version is newer than local, update the local version instead
                print("Error updating Patient \(self) from the Cloud to CareStore")
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
