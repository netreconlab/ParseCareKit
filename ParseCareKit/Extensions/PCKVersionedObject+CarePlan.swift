//
//  PCKVersionedObject+CarePlan.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/28/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import Parse
import CareKitStore

extension PCKVersionedObject{
    
    class func cloneCareKit(_ carePlanAny: OCKAnyCarePlan, carePlanToCopy: CarePlan?, store: OCKAnyStoreProtocol, completion: @escaping(CarePlan?) -> Void){
        
        guard let _ = PFUser.current(),
            let carePlan = carePlanAny as? OCKCarePlan,
            let store = store as? OCKStore else{
            completion(nil)
            return
        }
        let newCarePlan = CarePlan()
        if let uuid = carePlan.uuid?.uuidString{
            newCarePlan.uuid = uuid
        }else{
            print("Warning in PCKVersionedObject.cloneCareKit(). Entity missing uuid: \(carePlan)")
        }
        newCarePlan.entityId = carePlan.id
        newCarePlan.deletedDate = carePlan.deletedDate
        newCarePlan.title = carePlan.title
        newCarePlan.groupIdentifier = carePlan.groupIdentifier
        newCarePlan.tags = carePlan.tags
        newCarePlan.source = carePlan.source
        newCarePlan.asset = carePlan.asset
        newCarePlan.timezoneIdentifier = carePlan.timezone.abbreviation()!
        newCarePlan.effectiveDate = carePlan.effectiveDate
        newCarePlan.updatedDate = carePlan.updatedDate
        newCarePlan.userInfo = carePlan.userInfo
        newCarePlan.createdDate = carePlan.createdDate
        newCarePlan.notes = carePlan.notes?.compactMap{Note(careKitEntity: $0)}
        
        //Setting up CarePlan query
        var uuidsToQuery = [UUID]()
        if let previousUUID = carePlan.previousVersionUUID{
            uuidsToQuery.append(previousUUID)
        }
        if let nextUUID = carePlan.nextVersionUUID{
            uuidsToQuery.append(nextUUID)
        }
        
        if uuidsToQuery.isEmpty{
            newCarePlan.previous = nil
            newCarePlan.next = nil
            
            guard let carePlanUUID = carePlan.uuid else{
                completion(newCarePlan)
                return
            }
            newCarePlan.fetchRelatedPatient(carePlanUUID){
                patient in
                if patient != nil && carePlan.patientUUID != nil{
                    newCarePlan.patient = patient
                    completion(newCarePlan)
                }else if patient == nil && carePlan.patientUUID == nil{
                    completion(newCarePlan)
                }else{
                    completion(nil)
                }
            }
        }else{
            var query = OCKCarePlanQuery()
            query.uuids = uuidsToQuery
            store.fetchCarePlans(query: query, callbackQueue: .global(qos: .background)){
                results in
                switch results{
                    
                case .success(let entities):
                    let previousRemoteId = entities.filter{$0.uuid == carePlan.previousVersionUUID}.first?.remoteID
                    if previousRemoteId != nil && carePlan.previousVersionUUID != nil{
                        newCarePlan.previous = CarePlan(withoutDataWithObjectId: previousRemoteId!)
                    }else if previousRemoteId == nil && carePlan.previousVersionUUID == nil{
                        newCarePlan.previous = nil
                    }else{
                        completion(nil)
                        return
                    }
                    
                    let nextRemoteId = entities.filter{$0.uuid == carePlan.nextVersionUUID}.first?.remoteID
                    if nextRemoteId != nil{
                        newCarePlan.next = CarePlan(withoutDataWithObjectId: nextRemoteId!)
                    }
                case .failure(let error):
                    print("Error in \(newCarePlan.parseClassName).copyCareKit(). Error \(error)")
                    newCarePlan.previous = nil
                    newCarePlan.next = nil
                }
                
                guard let carePlanUUID = carePlan.uuid else{
                    completion(newCarePlan)
                    return
                }
                newCarePlan.fetchRelatedPatient(carePlanUUID){
                    patient in
                    if patient != nil && carePlan.patientUUID != nil{
                        newCarePlan.patient = patient
                        completion(newCarePlan)
                    }else if patient == nil && carePlan.patientUUID == nil{
                        completion(newCarePlan)
                    }else{
                        completion(nil)
                    }
                }
            }
        }
    }
    
    public func decodedCareKitObject(_ bareCareKitObject: OCKCarePlan)->OCKCarePlan?{
        guard let createdDate = self.createdDate?.timeIntervalSinceReferenceDate,
            let updatedDate = self.updatedDate?.timeIntervalSinceReferenceDate else{
                print("Error in \(parseClassName).decodedCareKitObject(). Missing either createdDate \(String(describing: self.createdDate)) or updatedDate \(String(describing: self.updatedDate))")
            return nil
        }
        
        //Create bare CareKit entity from json
        guard var json = CarePlan.encodeCareKitToDictionary(bareCareKitObject) else{return nil}
        json["uuid"] = self.uuid
        json["createdDate"] = createdDate
        json["updatedDate"] = updatedDate
        if let deletedDate = self.deletedDate?.timeIntervalSinceReferenceDate{
            json["deletedDate"] = deletedDate
        }
        if let previous = self.previousVersionUUID{
            json["previousVersionUUID"] = previous
        }
        if let next = self.nextVersionUUID{
            json["nextVersionUUID"] = next
        }
        let entity:OCKCarePlan!
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            entity = try JSONDecoder().decode(OCKCarePlan.self, from: data)
        }catch{
            print("Error in \(parseClassName).decodedCareKitObject(). \(error)")
            return nil
        }
        return entity
    }
}
