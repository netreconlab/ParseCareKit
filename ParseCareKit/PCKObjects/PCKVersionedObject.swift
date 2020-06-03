//
//  PCKVersionedObject.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/26/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import Parse

open class PCKVersionedObject: PCKObject {
    @NSManaged public var effectiveDate: Date?
    @NSManaged var previous: PCKVersionedObject?
    @NSManaged var previousVersionUUIDString: String?
    @NSManaged var next: PCKVersionedObject?
    @NSManaged var nextVersionUUIDString: String?
    
    public internal(set) var nextVersionUUID:UUID? {
        get {
            if next != nil{
                return UUID(uuidString: next!.uuid)
            }else if nextVersionUUIDString != nil {
                return UUID(uuidString: nextVersionUUIDString!)
            }else{
                return nil
            }
        }
        set{
            nextVersionUUIDString = newValue?.uuidString
            if newValue?.uuidString != next?.uuid{
                next = nil
            }
        }
    }
    
    var nextVersion: PCKVersionedObject?{
        get{
            return next
        }
        set{
            next = newValue
            nextVersionUUIDString = newValue?.uuid
        }
    }

    public internal(set) var previousVersionUUID: UUID? {
        get {
            if previous != nil{
                return UUID(uuidString: previous!.uuid)
            }else if previousVersionUUIDString != nil{
                return UUID(uuidString: previousVersionUUIDString!)
            }else{
                return nil
            }
        }
        set{
            previousVersionUUIDString = newValue?.uuidString
            if newValue?.uuidString != previous?.uuid{
                previous = nil
            }
        }
    }
    
    var previousVersion: PCKVersionedObject?{
        get{
            return previous
        }
        set{
            previous = newValue
            previousVersionUUIDString = newValue?.uuid
        }
    }
    
    override func copy(_ parse: PCKObject){
        super.copy(parse)
        guard let parse = parse as? PCKVersionedObject else{return}
        self.effectiveDate = parse.effectiveDate
        self.previous = parse.previous
        self.previousVersionUUIDString = parse.previousVersionUUIDString
        self.next = parse.next
        self.nextVersionUUIDString = parse.nextVersionUUIDString
    }
    
    //This query doesn't filter nextVersion effectiveDate >= interval.end
    public class func query(_ className: String, for date: Date) -> PFQuery<PFObject> {
        let query1 = self.queryVersionByDate(className, for: date, queryToAndWith: self.queryWhereNoNextVersion(className))
        let query2 = self.queryVersionByDate(className, for: date, queryToAndWith: self.queryWhereNextVersionGreaterThanEqualToDate(className, for: date))
        let query = PFQuery.orQuery(withSubqueries: [query1,query2])
        query.includeKeys([kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        return query
    }
    
    private class func queryVersionByDate(_ className: String, for date: Date, queryToAndWith: PFQuery<PFObject>)-> PFQuery<PFObject>{
        let interval = createCurrentDateInterval(for: date)
        
        queryToAndWith.whereKeyDoesNotExist(kPCKObjectDeletedDateKey) //Only consider non deleted keys
        queryToAndWith.whereKey(kPCKVersionedObjectEffectiveDateKey, lessThan: interval.end)
        return queryToAndWith
    }
    
    private class func queryWhereNoNextVersion(_ className: String)-> PFQuery<PFObject>{
        let query = PFQuery(className: className)
        query.whereKeyDoesNotExist(kPCKVersionedObjectNextKey)
        return query
    }
    
    private class func queryWhereNextVersionGreaterThanEqualToDate(_ className: String, for date: Date)-> PFQuery<PFObject>{
        let interval = createCurrentDateInterval(for: date)
        let query = PFQuery(className: className)
        query.whereKeyExists(kPCKVersionedObjectPreviousKey)
        query.whereKey(kPCKVersionedObjectNextKey, greaterThan: interval.end)
        return query
    }
    
    open class func createCurrentDateInterval(for date: Date)->DateInterval{
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay)!
        return DateInterval(start: startOfDay, end: endOfDay)
    }
    
    open func find(for date: Date) throws -> [PCKVersionedObject] {
        let query = PCKVersionedObject.query(parseClassName, for: date)
        let entities = try (query.findObjects() as! [PCKVersionedObject])
        return entities
    }
    
    open func findInBackground(for date: Date, completion: @escaping([PCKVersionedObject]?,Error?)->Void) {
        let query = PCKVersionedObject.query(parseClassName, for: date)
        query.findObjectsInBackground{
            (objects,error) in
            guard let entities = objects as? [PCKVersionedObject] else{
                completion(nil,error)
                return
            }
            completion(entities,error)
        }
    }
}
