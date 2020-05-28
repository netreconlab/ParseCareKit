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
            newCarePlan.fetchRelatedPatient(carePlan, store: store){
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
                newCarePlan.fetchRelatedPatient(carePlan, store: store){
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
    
    
    //Note that CarePlans have to be saved to CareKit first in order to properly convert to CareKit
    open func convertToCareKit(fromCloud:Bool=true, patient: Patient?, title: String)->OCKCarePlan?{
        var carePlan:OCKCarePlan!
        if fromCloud{
            guard let decodedCarePlan = createDecodedEntity(patient, title: title) else {
                print("Error in \(parseClassName). Couldn't decode entity \(self)")
                return nil
            }
            carePlan = decodedCarePlan
        }else{
            let patientUUID:UUID?
            if let patientUUIDString = patient?.uuid{
                patientUUID = UUID(uuidString: patientUUIDString)
                if patientUUID == nil{
                    print("Warning in \(parseClassName).convertToCareKit. Couldn't make UUID from \(patientUUIDString). Attempted to convert anyways...")
                }
            }else{
                patientUUID = nil
            }
            //Create bare Entity and replace contents with Parse contents
            carePlan = OCKCarePlan(id: self.entityId, title: title, patientUUID: patientUUID)
        }
        
        carePlan.groupIdentifier = self.groupIdentifier
        carePlan.tags = self.tags
        if let effectiveDate = self.effectiveDate{
            carePlan.effectiveDate = effectiveDate
        }
        carePlan.source = self.source
        carePlan.groupIdentifier = self.groupIdentifier
        carePlan.asset = self.asset
        carePlan.remoteID = self.objectId
        carePlan.notes = self.notes?.compactMap{$0.convertToCareKit()}
        carePlan.userInfo = self.userInfo
        if let timeZone = TimeZone(abbreviation: self.timezoneIdentifier){
            carePlan.timezone = timeZone
        }
        return carePlan
    }
    
    open func createDecodedEntity(_ patient: Patient?, title: String)->OCKCarePlan?{
        guard let createdDate = self.createdDate?.timeIntervalSinceReferenceDate,
            let updatedDate = self.updatedDate?.timeIntervalSinceReferenceDate else{
                print("Error in \(parseClassName).createDecodedEntity(). Missing either createdDate \(String(describing: self.createdDate)) or updatedDate \(String(describing: self.updatedDate))")
            return nil
        }
        
        let patientUUID:UUID?
        if let patientUUIDString = patient?.uuid{
            patientUUID = UUID(uuidString: patientUUIDString)
            if patientUUID == nil{
                print("Warning in \(parseClassName).createDecodedEntity. Couldn't make UUID from \(patientUUIDString). Attempted to decode anyways...")
            }
        }else{
            patientUUID = nil
        }
        
        let tempEntity = OCKCarePlan(id: entityId, title: title, patientUUID: patientUUID)
        //Create bare CareKit entity from json
        guard var json = CarePlan.getEntityAsJSONDictionary(tempEntity) else{return nil}
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
            let jsonString = String(data: data, encoding: .utf8)!
            print(jsonString)
            entity = try JSONDecoder().decode(OCKCarePlan.self, from: data)
        }catch{
            print("Error in \(parseClassName).createDecodedEntity(). \(error)")
            return nil
        }
        return entity
    }
}
