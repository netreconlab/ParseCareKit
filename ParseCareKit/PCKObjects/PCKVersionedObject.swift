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
    
    open override func copyCommonValues(from other: PCKObject){
        super.copyCommonValues(from: other)
        guard let other = other as? PCKVersionedObject else{return}
        self.effectiveDate = other.effectiveDate
        self.previous = other.previous
        self.previousVersionUUIDString = other.previousVersionUUIDString
        self.next = other.next
        self.nextVersionUUIDString = other.nextVersionUUIDString
    }
    
    //This query doesn't filter nextVersion effectiveDate >= interval.end
    public class func query(for date: Date) -> PFQuery<PFObject> {
        let query = self.queryVersion(for: date, queryToAndWith: self.queryWhereNoNextVersionOrNextVersionGreaterThanEqualToDate(for: date))
        query.includeKeys([kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        return query
    }
    
    private class func queryVersion(for date: Date, queryToAndWith: PFQuery<PFObject>)-> PFQuery<PFObject>{
        let interval = createCurrentDateInterval(for: date)
        
        queryToAndWith.whereKeyDoesNotExist(kPCKObjectDeletedDateKey) //Only consider non deleted keys
        queryToAndWith.whereKey(kPCKVersionedObjectEffectiveDateKey, lessThan: interval.end)
        return queryToAndWith
    }
    
    private class func queryWhereNoNextVersionOrNextVersionGreaterThanEqualToDate(for date: Date)-> PFQuery<PFObject>{
        
        let query = self.query()!
        query.whereKeyDoesNotExist(kPCKVersionedObjectNextKey)
        
        let interval = createCurrentDateInterval(for: date)
        let greaterEqualEffectiveDate = self.query()!
        greaterEqualEffectiveDate.whereKey(kPCKVersionedObjectEffectiveDateKey, greaterThanOrEqualTo: interval.end)
        
        return PFQuery.orQuery(withSubqueries: [query,greaterEqualEffectiveDate])
    }
    
    func find(for date: Date) throws -> [PCKVersionedObject] {
        let query = type(of: self).query(for: date)
        let entities = try (query.findObjects() as! [PCKVersionedObject])
        return entities
    }
    
    public func findInBackground(for date: Date, completion: @escaping([PCKVersionedObject]?,Error?)->Void) {
        let query = type(of: self).query(for: date)
        query.findObjectsInBackground{
            (objects,error) in
            guard let entities = objects as? [PCKVersionedObject] else{
                completion(nil,error)
                return
            }
            completion(entities,error)
        }
    }
    
    func fixVersionLinkedList(_ versionFixed: PCKVersionedObject, backwards:Bool){
        
        if backwards{
            if versionFixed.previousVersionUUIDString != nil && versionFixed.previous == nil{
                self.getFirstPCKObject(versionFixed.previousVersionUUID, classType: versionFixed, relatedObject: versionFixed.previous){
                    (isNew,previousFound) in
                    
                    guard let previousFound = previousFound as? PCKVersionedObject else{
                        //Previous version not found, stop fixing
                        return
                    }
                    versionFixed.previousVersion = previousFound
                    if isNew{
                        versionFixed.saveInBackground(){
                            (success,_) in
                            if success{
                                if previousFound.next == nil{
                                    previousFound.nextVersion = versionFixed
                                    previousFound.saveInBackground(){
                                        (success,_) in
                                        if success{
                                            self.fixVersionLinkedList(previousFound, backwards: backwards)
                                        }
                                    }
                                }else{
                                    self.fixVersionLinkedList(previousFound, backwards: backwards)
                                }
                            }
                        }
                    }
                }
            }
            //We are done fixing
        }else{
            if versionFixed.nextVersionUUIDString != nil && versionFixed.next == nil{
                self.getFirstPCKObject(versionFixed.nextVersionUUID, classType: versionFixed, relatedObject: versionFixed.next){
                    (isNew,nextFound) in
                    
                    guard let nextFound = nextFound as? PCKVersionedObject else{
                        //Next version not found, stop fixing
                        return
                    }
                    versionFixed.nextVersion = nextFound
                    if isNew{
                        versionFixed.saveInBackground(){
                            (success,_) in
                            if success{
                                if nextFound.previous == nil{
                                    nextFound.previousVersion = versionFixed
                                    nextFound.saveInBackground(){
                                    (success,_) in
                                        if success{
                                            self.fixVersionLinkedList(nextFound, backwards: backwards)
                                        }
                                    }
                                }else{
                                    self.fixVersionLinkedList(nextFound, backwards: backwards)
                                }
                            }
                        }
                    }
                }
            }
            //We are done fixing
        }
    }
    
    ///Link versions and related classes
    public func linkRelated(completion: @escaping(Bool,PCKVersionedObject)->Void){
        var linkedNew = false
        self.getFirstPCKObject(self.previousVersionUUID, classType: self, relatedObject: self.previous, includeKeys: true){
            (isNew,previousObject) in
            
            guard let previousObject  = previousObject as? PCKVersionedObject else{
                completion(false,self)
                return
            }
            
            self.previousVersion = previousObject
            if isNew{
                linkedNew = true
            }
            
            self.getFirstPCKObject(self.nextVersionUUID, classType: self, relatedObject: self.next, includeKeys: true){
                (isNew,nextObject) in
                
                guard let nextObject  = nextObject as? PCKVersionedObject else{
                    completion(false,self)
                    return
                }
                
                self.nextVersion = nextObject
                if isNew{
                    linkedNew = true
                }
                
                completion(linkedNew,self)
            }
        }
    }
    
    public func save(_ versionedObject: PCKVersionedObject, completion: @escaping(Bool,Error?) -> Void){
        
        switch versionedObject{
        case is CarePlan:
            
            guard let versionedObject = versionedObject as? CarePlan else{
                completion(false,ParseCareKitError.cantCastToNeededClassType)
                return
            }
            
            versionedObject.stampRelationalEntities()
            
            versionedObject.saveInBackground{
                (success, error) in
                if success{
                    print("Successfully added \(versionedObject) to Cloud")
                    
                    versionedObject.linkRelated{
                        (linked,_) in
                        
                        if linked{
                            versionedObject.saveInBackground()
                        }
                        
                        //Fix versioning doubly linked list if it's broken in the cloud
                        if versionedObject.previous != nil {
                            if versionedObject.previous!.next == nil{
                                versionedObject.previous!.nextVersion = versionedObject
                                versionedObject.previous!.saveInBackground(){
                                    (success,_) in
                                    if success{
                                        versionedObject.fixVersionLinkedList(versionedObject.previous!, backwards: true)
                                    }
                                }
                            }
                        }
                        
                        if versionedObject.next != nil {
                            if versionedObject.next!.previous == nil{
                                versionedObject.next!.previousVersion = versionedObject
                                versionedObject.next!.saveInBackground(){
                                    (success,_) in
                                    if success{
                                        versionedObject.fixVersionLinkedList(versionedObject.next! as! CarePlan, backwards: false)
                                    }
                                }
                            }
                        }
                        completion(success,error)
                    }
                }else{
                    print("Error in \(self.parseClassName).save(). \(String(describing: error))")
                    completion(success,error)
                }
            }
            
        case is Contact:
            guard let versionedObject = versionedObject as? Contact else{
                completion(false,ParseCareKitError.cantCastToNeededClassType)
                return
            }
            
            versionedObject.stampRelationalEntities()
            
            versionedObject.saveInBackground{
                (success, error) in
                if success{
                    print("Successfully added \(versionedObject) to Cloud")
                    
                    versionedObject.linkRelated{
                        (linked,_) in
                        
                        if linked{
                            versionedObject.saveInBackground()
                        }
                        
                        //Fix versioning doubly linked list if it's broken in the cloud
                        if versionedObject.previous != nil {
                            if versionedObject.previous!.next == nil{
                                versionedObject.previous!.nextVersion = versionedObject
                                versionedObject.previous!.saveInBackground(){
                                    (success,_) in
                                    if success{
                                        versionedObject.fixVersionLinkedList(versionedObject.previous!, backwards: true)
                                    }
                                }
                            }
                        }
                        
                        if versionedObject.next != nil {
                            if versionedObject.next!.previous == nil{
                                versionedObject.next!.previousVersion = versionedObject
                                versionedObject.next!.saveInBackground(){
                                    (success,_) in
                                    if success{
                                        versionedObject.fixVersionLinkedList(versionedObject.next! as! CarePlan, backwards: false)
                                    }
                                }
                            }
                        }
                        completion(success,error)
                    }
                }else{
                    print("Error in \(self.parseClassName).save(). \(String(describing: error))")
                    completion(success,error)
                }
            }
        case is Patient:
            guard let versionedObject = versionedObject as? Patient else{
                completion(false,ParseCareKitError.cantCastToNeededClassType)
                return
            }
            
            versionedObject.stampRelationalEntities()
            
            versionedObject.saveInBackground{
                (success, error) in
                if success{
                    print("Successfully added \(versionedObject) to Cloud")
                    
                    versionedObject.linkRelated{
                        (linked,_) in
                        
                        if linked{
                            versionedObject.saveInBackground()
                        }
                        
                        //Fix versioning doubly linked list if it's broken in the cloud
                        if versionedObject.previous != nil {
                            if versionedObject.previous!.next == nil{
                                versionedObject.previous!.nextVersion = versionedObject
                                versionedObject.previous!.saveInBackground(){
                                    (success,_) in
                                    if success{
                                        versionedObject.fixVersionLinkedList(versionedObject.previous!, backwards: true)
                                    }
                                }
                            }
                        }
                        
                        if versionedObject.next != nil {
                            if versionedObject.next!.previous == nil{
                                versionedObject.next!.previousVersion = versionedObject
                                versionedObject.next!.saveInBackground(){
                                    (success,_) in
                                    if success{
                                        versionedObject.fixVersionLinkedList(versionedObject.next! as! CarePlan, backwards: false)
                                    }
                                }
                            }
                        }
                        completion(success,error)
                    }
                }else{
                    print("Error in \(self.parseClassName).save(). \(String(describing: error))")
                    completion(success,error)
                }
            }
        case is Task:
            guard let versionedObject = versionedObject as? Task else{
                completion(false,ParseCareKitError.cantCastToNeededClassType)
                return
            }
            
            versionedObject.stampRelationalEntities()
            
            versionedObject.saveInBackground{
                (success, error) in
                if success{
                    print("Successfully added \(versionedObject) to Cloud")
                    
                    versionedObject.linkRelated{
                        (linked,_) in
                        
                        if linked{
                            versionedObject.saveInBackground()
                        }
                        
                        //Fix versioning doubly linked list if it's broken in the cloud
                        if versionedObject.previous != nil {
                            if versionedObject.previous!.next == nil{
                                versionedObject.previous!.nextVersion = versionedObject
                                versionedObject.previous!.saveInBackground(){
                                    (success,_) in
                                    if success{
                                        versionedObject.fixVersionLinkedList(versionedObject.previous!, backwards: true)
                                    }
                                }
                            }
                        }
                        
                        if versionedObject.next != nil {
                            if versionedObject.next!.previous == nil{
                                versionedObject.next!.previousVersion = versionedObject
                                versionedObject.next!.saveInBackground(){
                                    (success,_) in
                                    if success{
                                        versionedObject.fixVersionLinkedList(versionedObject.next! as! CarePlan, backwards: false)
                                    }
                                }
                            }
                        }
                        completion(success,error)
                    }
                }else{
                    print("Error in \(self.parseClassName).save(). \(String(describing: error))")
                    completion(success,error)
                }
            }
        default:
            completion(false,ParseCareKitError.classTypeNotAnEligibleType)
        }
    }
}
