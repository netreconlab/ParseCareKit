//
//  PCKVersionedObject+Contact.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/28/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import Parse
import CareKitStore

extension PCKVersionedObject{

    open func decodedCareKitObject(_ bareCareKitObject: OCKContact)->OCKContact?{
        guard let createdDate = self.createdDate?.timeIntervalSinceReferenceDate,
            let updatedDate = self.updatedDate?.timeIntervalSinceReferenceDate else{
                print("Error in \(parseClassName).decodedCareKitObject(). Missing either createdDate \(String(describing: self.createdDate)) or updatedDate \(String(describing: self.updatedDate))")
            return nil
        }
        
        //Create bare CareKit entity from json
        guard var json = Contact.encodeCareKitToDictionary(bareCareKitObject) else{return nil}
        json["uuid"] = self.uuid
        json["createdDate"] = createdDate
        json["updatedDate"] = updatedDate
        if let deletedDate = self.deletedDate?.timeIntervalSinceReferenceDate{
            json["deletedDate"] = deletedDate
        }
        if let previous = self.previousVersionUUID{
            json["previousVersionUUID"] = previous.uuidString
        }
        if let next = self.nextVersionUUID{
            json["nextVersionUUID"] = next.uuidString
        }
        let entity:OCKContact!
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            entity = try JSONDecoder().decode(OCKContact.self, from: data)
        }catch{
            print("Error in \(parseClassName).decodedCareKitObject(). \(error)")
            return nil
        }
        return entity
    }
    
    func fixVersionLinkedList(_ versionFixed: Contact, backwards:Bool){
        
        if backwards{
            if versionFixed.previousVersionUUIDString != nil && versionFixed.previous == nil{
                findContact(versionFixed.previousVersionUUID){
                    previousFound in
                    
                    guard let previousFound = previousFound else{
                        //Previous version not found, stop fixing
                        return
                    }
                    versionFixed.previous = previousFound
                    versionFixed.saveInBackground(){
                        (success,_) in
                        if success{
                            if previousFound.next == nil{
                                previousFound.next = versionFixed
                                previousFound.saveInBackground(){
                                    (success,_) in
                                    if success{
                                        self.fixVersionLinkedList(previousFound, backwards: backwards)
                                    }
                                }
                            }else{
                                self.fixVersionLinkedList(previousFound, backwards: backwards)
                            }
                        }
                    }
                }
            }
            //We are done fixing
        }else{
            if versionFixed.nextVersionUUIDString != nil && versionFixed.next == nil{
                findContact(versionFixed.nextVersionUUID){
                    nextFound in
                    
                    guard let nextFound = nextFound else{
                        //Next version not found, stop fixing
                        return
                    }
                    versionFixed.next = nextFound
                    versionFixed.saveInBackground(){
                        (success,_) in
                        if success{
                            if nextFound.previous == nil{
                                nextFound.previous = versionFixed
                                nextFound.saveInBackground(){
                                (success,_) in
                                    if success{
                                        self.fixVersionLinkedList(nextFound, backwards: backwards)
                                    }
                                }
                            }else{
                                self.fixVersionLinkedList(nextFound, backwards: backwards)
                            }
                        }
                    }
                }
            }
            //We are done fixing
        }
    }
}
