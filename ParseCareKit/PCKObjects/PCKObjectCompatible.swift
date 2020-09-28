//
//  PCKObjectCompatible.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/26/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore

internal protocol PCKObjectCompatible: ParseObject {

    var uuid: String? {get set}
    var entityId:String? {get set}
    var schemaVersion: [String:Any]? {get set}
    var logicalClock: Int? {get set}
    var createdDate: Date? {get set}
    var updatedDate: Date? {get set}
    var deletedDate: Date? {get set}
    var timezone: String? {get set}
    var userInfo: [String: String]? {get set}
    var groupIdentifier: String? {get set}
    var tags: [String]? {get set}
    var source: String? {get set}
    var asset: String? {get set}
    var notes: [Note]? {get set}
    var remoteID: String? {get set}
}

extension PCKObjectCompatible {
    
    public func canConvertToCareKit()->Bool {
        guard let _ = self.entityId,
              let _ = self.timezone else {
            return false
        }
        return true
    }

    public func first<T>(_ uuid:UUID?, classType: T, relatedObject:T?=nil, include:Bool=true, completion: @escaping(Bool,T?) -> Void) where T: PCKObjectCompatible {
          
        guard let _ = PCKUser.current,
            let uuidString = uuid?.uuidString else{
                completion(false,nil)
                return
        }
            
        guard relatedObject == nil else{
            //No need to query the Cloud, it's already present
            completion(false,relatedObject)
            return
        }
             
        var query = T.query(kPCKObjectCompatibleUUIDKey == uuidString)
        
        switch classType{
        case is CarePlan:
            if include{
                query.include(kPCKCarePlanPatientKey,kPCKObjectCompatibleNotesKey,
                                  kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey)
            }
        case is Contact:
            if include{
                query.include(kPCKContactCarePlanKey,kPCKObjectCompatibleNotesKey,
                              kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey)
            }
        case is Outcome:
            if include{
                query.include(kPCKOutcomeTaskKey,
                                      kPCKOutcomeValuesKey,kPCKObjectCompatibleNotesKey)
            }
        case is Patient:
            if include{
                query.include(kPCKObjectCompatibleNotesKey,
                              kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey)
            }
        case is Task:
            if include{
                query.include(kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectCompatibleNotesKey,
                              kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey)
            }
        default:
            completion(false,nil)
        }
        
        query.first(callbackQueue: .global(qos: .background)) { result in
            
            switch result {
            
            case .success(let object):
                completion(true, object)
            case .failure(_):
                completion(false,nil)
            }
            
        }
    }
    
    public func find<T> (_ uuid:UUID?, classType: T, include:Bool=true,
                         completion: @escaping([Self]?,Error?) -> Void) where T: PCKObjectCompatible {
          
        guard let _ = PCKUser.current,
            let uuidString = uuid?.uuidString else{
                print("Error in \(self.className).find(). \(ParseCareKitError.requiredValueCantBeUnwrapped)")
                completion(nil,ParseCareKitError.couldntUnwrapKnowledgeVector)
                return
        }
            
        var query = Self.query(kPCKObjectCompatibleUUIDKey == uuidString)

        switch classType{
        case is CarePlan:
            if include{
                query.include(kPCKCarePlanPatientKey,kPCKObjectCompatibleNotesKey,
                              kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey)
            }
        case is Contact:
            if include{
                query.include([kPCKContactCarePlanKey,kPCKObjectCompatibleNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
            }
        case is Outcome:
            if include{
                query.include([kPCKOutcomeTaskKey,kPCKOutcomeValuesKey,kPCKObjectCompatibleNotesKey])
            }
        case is Patient:
            if include{
                query.include([kPCKObjectCompatibleNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
            }
        case is Task:
            if include{
                query.include([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectCompatibleNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
            }
        default:
            completion(nil,ParseCareKitError.classTypeNotAnEligibleType)
        }
        
        query.find(callbackQueue: .global(qos: .background)){
            results in
            
            switch results {
            
            case .success(let foundObjects):
                completion(foundObjects, nil)
            case .failure(let error):
                print("Error in \(self.className).find(). \(error.localizedDescription)")
                completion(nil,error)
            }
            
        }
    }
    
    public static func createCurrentDateInterval(for date: Date)->DateInterval{
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay)!
        return DateInterval(start: startOfDay, end: endOfDay)
    }
}

