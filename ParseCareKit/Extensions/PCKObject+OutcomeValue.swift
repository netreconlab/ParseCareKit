//
//  PCKObject+OutcomeValue.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/28/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import Parse
import CareKitStore

extension PCKObject{

    public func compareUpdate(_ careKit: OCKOutcomeValue, parse: OutcomeValue, usingKnowledgeVector: Bool, overwriteRemote: Bool, newClockValue:Int, store: OCKAnyStoreProtocol)->OCKOutcomeValue?{
        
        if !usingKnowledgeVector{
            guard let careKitLastUpdated = careKit.updatedDate,
                let cloudUpdatedAt = parse.updatedDate else{
                return nil
            }
            if cloudUpdatedAt > careKitLastUpdated{
                //Item from cloud is newer, no change needed in the cloud
                return parse.convertToCareKit()
            }
            
            return nil //Items are the same, no need to do anything
        }else{
            if ((self.logicalClock <= parse.logicalClock) && !overwriteRemote){
                //This should throw a conflict as pullRevisions should have made sure it doesn't happen. Ignoring should allow the newer one to be pulled from the cloud, so we do nothing here
                print("Warning in \(self.parseClassName).compareUpdate(). KnowledgeVector in Cloud \(parse.logicalClock) >= \(self.logicalClock). This should never occur. It should get fixed in next pullRevision. Local: \(self)... Cloud: \(parse)")
            }
            return nil
        }
    }
    
    public func decodedCareKitObject(_ value: OCKOutcomeValueUnderlyingType, units: String?)->OCKOutcomeValue?{
        guard let createdDate = self.createdDate?.timeIntervalSinceReferenceDate,
            let updatedDate = self.updatedDate?.timeIntervalSinceReferenceDate else{
                print("Error in \(parseClassName).decodedCareKitObject(). Missing either createdDate \(String(describing: self.createdDate)) or updatedDate \(String(describing: self.updatedDate))")
            return nil
        }
            
        let tempEntity = OCKOutcomeValue(value, units: units)
        
        //Create bare CareKit entity from json
        guard var json = OutcomeValue.encodeCareKitToDictionary(tempEntity) else{return nil}
        json["uuid"] = self.uuid
        json["createdDate"] = createdDate
        json["updatedDate"] = updatedDate
        let entity:OCKOutcomeValue!
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            entity = try JSONDecoder().decode(OCKOutcomeValue.self, from: data)
        }catch{
            print("Error in \(parseClassName).decodedCareKitObject(). \(error)")
            return nil
        }
        return entity
    }
    
    public class func encodeCareKitToDictionary(_ entity: OCKOutcomeValue)->[String:Any]?{
        let jsonDictionary:[String:Any]
        do{
            let data = try JSONEncoder().encode(entity)
            jsonDictionary = try JSONSerialization.jsonObject(with: data, options: []) as! [String:Any]
        }catch{
            print("Error in OutcomeValue.encodeCareKitToDictionary(). \(error)")
            return nil
        }
        
        return jsonDictionary
    }
    
    public class func getUUIDFromCareKitEntity(_ entity: OCKOutcomeValue)->String?{
        guard let json = OutcomeValue.encodeCareKitToDictionary(entity) else{return nil}
        return json["uuid"] as? String
    }

}
