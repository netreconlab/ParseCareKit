//
//  PCKObject.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/26/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore

open class PCKObject: ParseObject {
    public var objectId: String?
    
    public var createdAt: Date?
    
    public var updatedAt: Date?
    
    public var ACL: ParseACL?

    public internal(set) var uuid: String?
    public internal(set) var entityId:String?
    var schemaVersion = [String:Any]()
    var logicalClock: Int?
    public internal(set) var createdDate: Date?
    public internal(set) var updatedDate: Date?
    public internal(set) var deletedDate: Date?
    public internal(set) var timezone: String?
    public var userInfo: [String: String]?
    public var groupIdentifier: String?
    public var tags: [String]?
    public var source: String?
    public var asset: String?
    public var notes: [Note]?
    public var remoteID: String?

    public init() {
        
    }

    public required init(from decoder: Decoder) throws {
        return
    }
    enum CodingKeys: String, CodingKey { // swiftlint:disable:this nesting
        case uuid
    }
    public func encode(to encoder: Encoder) throws {
        return
    }
    
    func stampRelationalEntities() -> Bool {
        guard let logicalClock = self.logicalClock else {
            return false
        }
        self.notes?.forEach{$0.stamp(logicalClock)}
        return true
    }

    func copyCommonValues(from other: PCKObject) {
        self.uuid = other.uuid
        self.entityId = other.entityId
        self.deletedDate = other.deletedDate
        self.updatedDate = other.updatedDate
        self.timezone = other.timezone
        self.userInfo = other.userInfo
        self.remoteID = other.remoteID
        self.createdDate = other.createdDate
        self.notes = other.notes
        self.logicalClock = other.logicalClock
    }
    
    func copyRelationalEntities(_ parse: PCKObject) {
        Note.replaceWithCloudVersion(&self.notes, cloud: parse.notes)
    }
    
    public func canConvertToCareKit()->Bool {
        guard let _ = self.entityId,
              let _ = self.timezone else {
            return false
        }
        return true
    }

    public func first(_ uuid:UUID?, classType: PCKObject, relatedObject:PCKObject?=nil, include:Bool=true, completion: @escaping(Bool,PCKObject?) -> Void) {
          
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
             
        var query = Self.query(kPCKObjectUUIDKey == uuidString)
        
        switch classType{
        case is CarePlan:
            if include{
                query.include(kPCKCarePlanPatientKey,kPCKObjectNotesKey,
                                  kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey)
            }
        case is Contact:
            if include{
                query.include(kPCKContactCarePlanKey,kPCKObjectNotesKey,
                              kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey)
            }
        case is Outcome:
            if include{
                query.include(kPCKOutcomeTaskKey,
                                      kPCKOutcomeValuesKey,kPCKObjectNotesKey)
            }
        case is Patient:
            if include{
                query.include(kPCKObjectNotesKey,
                              kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey)
            }
        case is Task:
            if include{
                query.include(kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectNotesKey,
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
    
    public func find(_ uuid:UUID?, classType: PCKObject, include:Bool=true,
                                   completion: @escaping([PCKObject]?,Error?) -> Void) {
          
        guard let _ = PCKUser.current,
            let uuidString = uuid?.uuidString else{
                print("Error in \(self.className).find(). \(ParseCareKitError.requiredValueCantBeUnwrapped)")
                completion(nil,ParseCareKitError.couldntUnwrapKnowledgeVector)
                return
        }
            
        var query = Self.query(kPCKObjectUUIDKey == uuidString)

        switch classType{
        case is CarePlan:
            if include{
                query.include(kPCKCarePlanPatientKey,kPCKObjectNotesKey,
                              kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey)
            }
        case is Contact:
            if include{
                query.include([kPCKContactCarePlanKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
            }
        case is Outcome:
            if include{
                query.include([kPCKOutcomeTaskKey,kPCKOutcomeValuesKey,kPCKObjectNotesKey])
            }
        case is Patient:
            if include{
                query.include([kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
            }
        case is Task:
            if include{
                query.include([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
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
    
    public class func createCurrentDateInterval(for date: Date)->DateInterval{
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay)!
        return DateInterval(start: startOfDay, end: endOfDay)
    }
}

