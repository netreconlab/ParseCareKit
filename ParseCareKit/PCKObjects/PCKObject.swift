//
//  PCKObject.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/26/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import Parse
import CareKitStore

open class PCKObject: PFObject {
    
    @NSManaged public internal(set) var uuid: String
    @NSManaged public internal(set) var entityId:String
    @NSManaged var schemaVersion:[String:Any]
    @NSManaged var logicalClock: Int
    @NSManaged public internal(set) var createdDate: Date?
    @NSManaged public internal(set) var updatedDate: Date?
    @NSManaged public internal(set) var deletedDate: Date?
    @NSManaged public internal(set) var timezone: String
    @NSManaged public var userInfo: [String: String]?
    @NSManaged public var groupIdentifier: String?
    @NSManaged public var tags: [String]?
    @NSManaged public var source: String?
    @NSManaged public var asset: String?
    @NSManaged public var notes: [Note]?
    @NSManaged public var remoteID: String?
    
    open func stampRelationalEntities(){
        self.notes?.forEach{$0.stamp(self.logicalClock)}
    }
    
    open func copyCommonValues(from other: PCKObject){
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
    
    open func copyRelationalEntities(_ parse: PCKObject){
        Note.replaceWithCloudVersion(&self.notes, cloud: parse.notes)
    }
    
    public func getFirstPCKObject(_ uuid:UUID?, classType: PCKObject, relatedObject:PCKObject?=nil, includeKeys:Bool=true, completion: @escaping(Bool,PCKObject?) -> Void){
          
        guard let _ = PFUser.current(),
            let uuidString = uuid?.uuidString else{
                completion(false,nil)
                return
        }
            
        guard relatedObject == nil else{
            //No need to query the Cloud, it's already present
            completion(false,relatedObject)
            return
        }
             
        let query = type(of: classType).query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: uuidString)
        
        switch classType{
        case is CarePlan:
            if includeKeys{
                query.includeKeys([kPCKCarePlanPatientKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
            }
        case is Contact:
            if includeKeys{
                query.includeKeys([kPCKContactCarePlanKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
            }
        case is Outcome:
            if includeKeys{
                query.includeKeys([kPCKOutcomeTaskKey,kPCKOutcomeValuesKey,kPCKObjectNotesKey])
            }
        case is Patient:
            if includeKeys{
                query.includeKeys([kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
            }
        case is Task:
            if includeKeys{
                query.includeKeys([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
            }
        default:
            completion(false,nil)
        }
        
        query.getFirstObjectInBackground(){
            (object, parseError) in
            
            guard let foundObject = object as? PCKObject else{
                completion(false,nil)
                return
            }
            completion(true,foundObject)
        }
    }
    
    public func findPCKObjects(_ uuid:UUID?, classType: PCKObject, includeKeys:Bool=true, completion: @escaping([PCKObject]?,Error?) -> Void){
          
        guard let _ = PFUser.current(),
            let uuidString = uuid?.uuidString else{
                completion(nil,ParseCareKitError.couldntUnwrapKnowledgeVector)
                return
        }
            
        let query = type(of: classType).query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: uuidString)
        
        switch classType{
        case is CarePlan:
            if includeKeys{
                query.includeKeys([kPCKCarePlanPatientKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
            }
        case is Contact:
            if includeKeys{
                query.includeKeys([kPCKContactCarePlanKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
            }
        case is Outcome:
            if includeKeys{
                query.includeKeys([kPCKOutcomeTaskKey,kPCKOutcomeValuesKey,kPCKObjectNotesKey])
            }
        case is Patient:
            if includeKeys{
                query.includeKeys([kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
            }
        case is Task:
            if includeKeys{
                query.includeKeys([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
            }
        default:
            completion(nil,ParseCareKitError.classTypeNotAnEligibleType)
        }
        
        query.findObjectsInBackground(){
            (objects, error) in
            
            guard let foundObjects = objects as? [PCKObject] else{
                print("Error in \(self.parseClassName).findPCKObjects(). \(String(describing: error?.localizedDescription))")
                completion(nil,error)
                return
            }
            completion(foundObjects,error)
        }
    }
    
    public class func createCurrentDateInterval(for date: Date)->DateInterval{
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay)!
        return DateInterval(start: startOfDay, end: endOfDay)
    }
}
