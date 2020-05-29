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

    public func saveAndCheckRemoteID(_ contact: Contact, completion: @escaping(Bool,Error?) -> Void){
        
        guard let contactUUID = UUID(uuidString: contact.uuid) else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        contact.stampRelationalEntities()
        contact.saveInBackground{(success, error) in
            if success{
                print("Successfully saved \(self) in Cloud.")
                //Need to save remoteId for this and all relational data
                var careKitQuery = OCKContactQuery()
                careKitQuery.uuids = [contactUUID]
                self.store.fetchContacts(query: careKitQuery, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(let entities):
                        guard var mutableEntity = entities.first else{
                            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                            return
                        }
                        if mutableEntity.remoteID == nil{
                            mutableEntity.remoteID = contact.objectId
                            self.store.updateAnyContact(mutableEntity){
                                result in
                                switch result{
                                case .success(let updatedContact):
                                    print("Updated remoteID of Contact \(updatedContact)")
                                    completion(true,nil)
                                case .failure(let error):
                                    print("Error in Contact.saveAndCheckRemoteID() updating remoteID of Contact. \(error)")
                                    completion(false,error)
                                }
                            }
                        }else{
                            if mutableEntity.remoteID! != contact.objectId{
                                mutableEntity.remoteID = contact.objectId
                                self.store.updateAnyContact(mutableEntity){
                                    result in
                                    switch result{
                                    case .success(let updatedContact):
                                        print("Updated remoteID of Contact \(updatedContact)")
                                        completion(true,nil)
                                    case .failure(let error):
                                        print("Error in Contact.saveAndCheckRemoteID() updating remoteID of Contact. \(error)")
                                        completion(false,error)
                                    }
                                }
                            }else{
                                completion(true,nil)
                            }
                        }
                    case .failure(let error):
                        print("Error adding contact to cloud \(error)")
                        completion(false,error)
                    }
                }
                
            }else{
                print("Error in Contact.saveAndCheckRemoteID(). \(String(describing: error))")
                completion(false,error)
            }
        }
    }
    
    public func compareUpdate(_ careKit: OCKContact, parse: Contact, usingKnowledgeVector: Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void){
        if !usingKnowledgeVector{
            guard let careKitLastUpdated = careKit.updatedDate,
                let cloudUpdatedAt = parse.updatedDate else{
                completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                return
            }
            if ((cloudUpdatedAt < careKitLastUpdated) || overwriteRemote){
                parse.copyCareKit(careKit, clone: overwriteRemote){_ in
                    self.saveAndCheckRemoteID(parse){
                        (success,error) in
                        
                        if !success{
                            print("Error in \(self.parseClassName).updateCloud(). Couldn't update \(careKit)")
                        }else{
                            print("Successfully updated Contact \(parse) in the Cloud")
                        }
                        completion(success,error)
                    }
                }
            }else if ((cloudUpdatedAt > careKitLastUpdated) || overwriteRemote) {
                //The cloud version is newer than local, update the local version instead
                guard let updatedCarePlanFromCloud = parse.convertToCareKit() else{
                    completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                    return
                }
                store.updateAnyContact(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(_):
                        print("Successfully updated Contact \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                        completion(true,nil)
                    case .failure(let error):
                        print("Error updating Contact \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                        completion(false,error)
                    }
                }
            }else{
                completion(true,nil)
            }
        }else{
            if ((self.logicalClock > parse.logicalClock) || overwriteRemote){
                parse.copyCareKit(careKit, clone: overwriteRemote){_ in
                    parse.logicalClock = self.logicalClock //Place stamp on this entity since it's correctly linked to Parse
                    self.saveAndCheckRemoteID(parse){
                        (success,error) in
                        
                        if !success{
                            print("Error in \(self.parseClassName).updateCloud(). Couldn't update \(careKit)")
                        }else{
                            print("Successfully updated Contact \(parse) in the Cloud")
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
    
    public func compareDelete(_ parse: Contact, completion: @escaping(Bool,Error?) -> Void){
        guard let careKitLastUpdated = self.updatedDate,
            let cloudUpdatedAt = parse.updatedDate else{
                completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        if cloudUpdatedAt <= careKitLastUpdated{
            parse.deleteInBackground{
                (success, error) in
                if !success{
                    guard let error = error else{return}
                    print("Error in Contact.deleteFromCloud(). \(error)")
                }else{
                    print("Successfully deleted Contact \(self) in the Cloud")
                }
                completion(success,error)
            }
        }else {
            //The updated version in the cloud is newer, local delete has already occured, so updated the device with the newer one from the cloud
            guard let updatedCarePlanFromCloud = parse.convertToCareKit() else{
                completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                return
            }
            store.updateAnyContact(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                result in
                
                switch result{
                    
                case .success(_):
                    print("Successfully deleting Contact \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    completion(true,nil)
                case .failure(let error):
                    print("Error deleting Contact \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    completion(false,error)
                }
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
