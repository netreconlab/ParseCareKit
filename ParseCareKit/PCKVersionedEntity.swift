//
//  PCKVersionedEntity.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/26/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import Parse

open class PCKVersionedEntity: PCKEntity {
    @NSManaged public var effectiveDate: Date
    @NSManaged public var deletedDate: Date?
    @NSManaged public var previous: PCKVersionedEntity?
    @NSManaged public var next: PCKVersionedEntity?
    var nextVersionUUID: String? {
        return next?.uuid
    }

    var previousVersionUUID: String? {
        return previous?.uuid
    }
    
    //This query doesn't filter nextVersion effectiveDate >= interval.end
    public class func query(_ className: String, for date: Date) -> PFQuery<PFObject> {
        return self.queryVersionByDate(className, for: date)
    }
    
    private class func queryVersionByDate(_ className: String, for date: Date)-> PFQuery<PFObject>{
        let query = self.queryWhereNoNextVersion(className)
        let interval = createCurrentDateInterval(for: date)
        
        query.whereKeyDoesNotExist(kPCKVersionedEntityDeletedDateKey) //Only consider non deleted keys
        query.whereKey(kPCKVersionedEntityEffectiveDateKey, lessThan: interval.end)
        query.includeKey(kPCKVersionedEntityNextKey)
        return query
    }
    
    open class func createCurrentDateInterval(for date: Date)->DateInterval{
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay)!
        return DateInterval(start: startOfDay, end: endOfDay)
    }
    
    private class func queryWhereNoNextVersion(_ className: String)-> PFQuery<PFObject>{
        let query = PFQuery(className: className)
        query.whereKeyDoesNotExist(kPCKVersionedEntityNextKey)
        return query
    }
    
    open func find(for date: Date) throws -> [PCKVersionedEntity] {
        let interval = PCKVersionedEntity.createCurrentDateInterval(for: date)
        let query = PCKVersionedEntity.query(parseClassName, for: date)
        let entities = try (query.findObjects() as! [PCKVersionedEntity]).filter{$0.effectiveDate >= interval.end}
        return entities
    }
    
    open func findInBackground(for date: Date, completion: @escaping([PCKVersionedEntity]?,Error?)->Void) {
        let query = PCKVersionedEntity.query(parseClassName, for: date)
        query.findObjectsInBackground{
            (objects,error) in
            guard let entities = objects as? [PCKVersionedEntity] else{
                completion(nil,error)
                return
            }
            let interval = PCKVersionedEntity.createCurrentDateInterval(for: date)
            completion(entities.filter{$0.effectiveDate >= interval.end},error)
        }
    }
}
