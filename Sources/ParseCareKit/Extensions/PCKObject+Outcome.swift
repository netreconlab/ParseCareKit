//
//  PCKObjectable+Outcome.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/28/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore
/*
extension PCKObjectable {
    
    public static func encodeCareKitToDictionary(_ entity: OCKOutcome)->[String:Any]?{
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
                print("Error in \(className).decodedCareKitObject(). Missing either createdDate \(String(describing: self.createdDate)) or updatedDate \(String(describing: self.updatedDate))")
            return nil
        }
        
        //Create bare CareKit entity from json
        guard var json = Outcome.encodeCareKitToDictionary(bareCareKitObject) else{return nil}
        json["uuid"] = self.uuid
        json["createdDate"] = createdDate
        json["updatedDate"] = updatedDate
        if let deletedDate = self.deletedDate?.timeIntervalSinceReferenceDate{
            json["deletedDate"] = deletedDate
        }
        json["schemaVersion"] = self.schemaVersion
        let entity:OCKOutcome!
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            entity = try JSONDecoder().decode(OCKOutcome.self, from: data)
        }catch{
            print("Error in \(className).decodedCareKitObject(). \(error)")
            return nil
        }
        return entity
    }
    
    public static func getSchemaVersionFromCareKitEntity(_ entity: OCKOutcome)->[String:Any]?{
        guard let json = Outcome.encodeCareKitToDictionary(entity) else{return nil}
        return json["schemaVersion"] as? [String:Any]
    }
}*/
