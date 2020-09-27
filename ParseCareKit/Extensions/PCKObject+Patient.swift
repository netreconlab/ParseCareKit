//
//  PCKObject+Patient.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/28/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore

extension PCKObject {
    
    static func encodeCareKitToDictionary(_ entity: OCKPatient)->[String:Any]?{
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
    
    public static func getSchemaVersionFromCareKitEntity(_ entity: OCKPatient)->[String:Any]?{
        guard let json = Patient.encodeCareKitToDictionary(entity) else{return nil}
        return json["schemaVersion"] as? [String:Any]
    }
}
