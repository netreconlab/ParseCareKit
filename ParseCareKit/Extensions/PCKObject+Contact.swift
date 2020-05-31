//
//  PCKObject+Contact.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/28/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import Parse
import CareKitStore

extension PCKObject{

    public func save(_ contact: Contact, completion: @escaping(Bool,Error?) -> Void){
        
        contact.stampRelationalEntities()
        contact.saveInBackground{(success, error) in
            if success{
                print("Successfully saved \(self) in Cloud.")
                
                //Fix versioning doubly linked list if it's broken in the cloud
                if contact.previous != nil {
                    if contact.previous!.next == nil{
                        contact.previous!.next = contact
                        contact.previous!.next!.saveInBackground(){
                            (success,_) in
                            if success{
                                contact.fixVersionLinkedList(contact.previous! as! Contact, backwards: true)
                            }
                        }
                    }
                }
                
                if contact.next != nil {
                    if contact.next!.previous == nil{
                        contact.next!.previous = contact
                        contact.next!.previous!.saveInBackground(){
                            (success,_) in
                            if success{
                                contact.fixVersionLinkedList(contact.next! as! Contact, backwards: false)
                            }
                        }
                    }
                }
            }else{
                print("Error in Contact.save(). \(String(describing: error))")
            }
            completion(success,error)
        }
    }
    
    public func compareUpdate(_ parse: Contact, usingKnowledgeVector: Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void){
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
            }else if ((cloudUpdatedAt > careKitLastUpdated) || overwriteRemote) {
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
    
    public class func encodeCareKitToDictionary(_ entity: OCKContact)->[String:Any]?{
        let jsonDictionary:[String:Any]
        do{
            let data = try JSONEncoder().encode(entity)
            jsonDictionary = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers,.mutableLeaves]) as! [String:Any]
        }catch{
            print("Error in Contact.encodeCareKitToDictionary(). \(error)")
            return nil
        }
        
        return jsonDictionary
    }
    
    public func findContact(_ uuid:UUID?, completion: @escaping(Contact?) -> Void){
       
        guard let _ = PFUser.current(),
            let uuidString = uuid?.uuidString else{
            completion(nil)
            return
        }
        
        let query = Contact.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: uuidString)
        query.includeKeys([kPCKContactCarePlanKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.getFirstObjectInBackground(){
            (object, parseError) in
            
            guard let foundObject = object as? Contact else{
                completion(nil)
                return
            }
            completion(foundObject)
        }
    }
    
}
