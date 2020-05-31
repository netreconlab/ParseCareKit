//
//  PCKVersionedObject+Task.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/28/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import Parse
import CareKitStore

extension PCKVersionedObject{

    public func decodedCareKitObject(_ bareCareKitObject: OCKTask)->OCKTask?{
        guard let createdDate = self.createdDate?.timeIntervalSinceReferenceDate,
            let updatedDate = self.updatedDate?.timeIntervalSinceReferenceDate else{
                print("Error in \(parseClassName).decodedCareKitObject(). Missing either createdDate \(String(describing: self.createdDate)) or updatedDate \(String(describing: self.updatedDate))")
            return nil
        }
        
        //Create bare CareKit entity from json
        guard var json = Task.encodeCareKitToDictionary(bareCareKitObject) else{return nil}
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
        let entity:OCKTask!
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            let jsonString = String(data: data, encoding: .utf8)!
            print(jsonString)
            entity = try JSONDecoder().decode(OCKTask.self, from: data)
        }catch{
            print("Error in \(parseClassName).decodedCareKitObject(). \(error)")
            return nil
        }
        return entity
    }
    
    func fixVersionLinkedList(_ versionFixed: Task, backwards:Bool){
        versionFixed.saveInBackground()
        
        if backwards{
            if versionFixed.previousVersionUUIDString != nil && versionFixed.previous == nil{
                findTask(versionFixed.previousVersionUUID){
                    previousFound in
                    
                    guard let previousFound = previousFound else{
                        //Previous version not found, stop fixing
                        return
                    }
                    previousFound.next = versionFixed
                    self.fixVersionLinkedList(previousFound, backwards: backwards)
                }
            }
            //We are done fixing
        }else{
            if versionFixed.nextVersionUUIDString != nil && versionFixed.next == nil{
                findTask(versionFixed.nextVersionUUID){
                    nextFound in
                    
                    guard let nextFound = nextFound else{
                        //Next version not found, stop fixing
                        return
                    }
                    nextFound.next = versionFixed
                    self.fixVersionLinkedList(nextFound, backwards: backwards)
                }
            }
            //We are done fixing
        }
    }
}
