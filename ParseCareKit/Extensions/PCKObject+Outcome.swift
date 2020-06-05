//
//  PCKObject+Outcome.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/28/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import Parse
import CareKitStore

extension PCKObject{

    public func save(_ outcome: Outcome, completion: @escaping(Bool,Error?) -> Void){
        
        outcome.stampRelationalEntities()
        outcome.saveInBackground{ (success, error) in
            
            if success{
                print("Successfully saved \(outcome) in Cloud.")
                
                outcome.linkRelated{
                    (linked,_) in
                    
                    if linked{
                        outcome.saveInBackground()
                    }
                    completion(success,error)
                }
            }else{
                print("Error in CarePlan.addToCloud(). \(String(describing: error))")
                completion(success,error)
            }
        }
    }
    
    public class func encodeCareKitToDictionary(_ entity: OCKOutcome)->[String:Any]?{
        let jsonDictionary:[String:Any]
        do{
            let data = try JSONEncoder().encode(entity)
            jsonDictionary = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers,.mutableLeaves]) as! [String:Any]
        }catch{
            print("Error in Outcome.encodeCareKitToDictionary(). \(error)")
            return nil
        }
        
        return jsonDictionary
    }
    
    public func decodedCareKitObject(_ bareCareKitObject: OCKOutcome)->OCKOutcome?{
        guard let createdDate = self.createdDate?.timeIntervalSinceReferenceDate,
            let updatedDate = self.updatedDate?.timeIntervalSinceReferenceDate else{
                print("Error in \(parseClassName).decodedCareKitObject(). Missing either createdDate \(String(describing: self.createdDate)) or updatedDate \(String(describing: self.updatedDate))")
            return nil
        }
        
        //Create bare CareKit entity from json
        guard var json = Outcome.encodeCareKitToDictionary(bareCareKitObject) else{return nil}
        json["uuid"] = self.uuid
        json["createdDate"] = createdDate
        json["updatedDate"] = updatedDate
        let entity:OCKOutcome!
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            entity = try JSONDecoder().decode(OCKOutcome.self, from: data)
        }catch{
            print("Error in \(parseClassName).decodedCareKitObject(). \(error)")
            return nil
        }
        return entity
    }
}
