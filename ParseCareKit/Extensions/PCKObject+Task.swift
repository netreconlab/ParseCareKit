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
    
    public class func getSchemaVersionFromCareKitEntity(_ entity: OCKTask)->[String:Any]?{
        guard let json = Task.encodeCareKitToDictionary(entity) else{return nil}
        return json["schemaVersion"] as? [String:Any]
    }
}
