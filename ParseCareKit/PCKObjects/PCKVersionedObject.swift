//
//  PCKVersionedObject.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/26/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift

open class PCKVersionedObject: PCKObject {

    var effectiveDate: Date?
    var previous: PCKVersionedObject?
    var previousVersionUUIDString: String?
    var next: PCKVersionedObject?
    var nextVersionUUIDString: String?

    public internal(set) var nextVersionUUID:UUID? {
        get {
            if next?.uuid != nil{
                return UUID(uuidString: next!.uuid!)
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
            if previous?.uuid != nil{
                return UUID(uuidString: previous!.uuid!)
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

    public override init() {
        super.init()
    }

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    open override func copyCommonValues(from other: PCKObject) {
        super.copyCommonValues(from: other)
        guard let other = other as? Self else{return}
        self.effectiveDate = other.effectiveDate
        self.previous = other.previous
        self.previousVersionUUIDString = other.previousVersionUUIDString
        self.next = other.next
        self.nextVersionUUIDString = other.nextVersionUUIDString
    }
    
    private class func queryVersion(for date: Date, queryToAndWith: Query<PCKVersionedObject>)-> Query<PCKVersionedObject> {
        let interval = createCurrentDateInterval(for: date)
    
        var query = queryToAndWith
        query.where(doesNotExist(key: kPCKObjectDeletedDateKey)) //Only consider non deleted keys
        query.where(kPCKVersionedObjectEffectiveDateKey < interval.end)
        return query
    }
    
    private class func queryWhereNoNextVersionOrNextVersionGreaterThanEqualToDate(for date: Date)-> Query<PCKVersionedObject> {
        
        let query = self.query(doesNotExist(key: kPCKVersionedObjectNextKey))
        
        let interval = createCurrentDateInterval(for: date)
        let greaterEqualEffectiveDate = self.query(kPCKVersionedObjectEffectiveDateKey >= interval.end)
        return self.query(or(queries: [query,greaterEqualEffectiveDate]))
    }
    
    func find(for date: Date) throws -> [PCKVersionedObject] {
        try Self.query(for: date).find()
    }
    
    func fixVersionLinkedList(_ versionFixed: PCKVersionedObject, backwards:Bool){
        if backwards{
            if versionFixed.previousVersionUUIDString != nil && versionFixed.previous == nil{
                self.first(versionFixed.previousVersionUUID, classType: versionFixed, relatedObject: versionFixed.previous){
                    (isNew,previousFound) in
                    
                    guard let previousFound = previousFound as? PCKVersionedObject else{
                        //Previous version not found, stop fixing
                        return
                    }
                    versionFixed.previousVersion = previousFound
                    if isNew{
                        versionFixed.save(callbackQueue: .global(qos: .background)) { results in
                            switch results {
                            
                            case .success(_):
                                if previousFound.next == nil{
                                    previousFound.nextVersion = versionFixed
                                    previousFound.save(callbackQueue: .global(qos: .background)){ results in
                                        switch results {
                                        
                                        case .success(_):
                                            self.fixVersionLinkedList(previousFound, backwards: backwards)
                                        case .failure(let error):
                                            print("Couldn't save in fixVersionLinkedList(). Error: \(error). Object: \(versionFixed)")
                                        }
                                    }
                                }else{
                                    self.fixVersionLinkedList(previousFound, backwards: backwards)
                                }
                            case .failure(let error):
                                print("Couldn't save in fixVersionLinkedList(). Error: \(error). Object: \(versionFixed)")
                            }
                        }
                    }
                }
            }
            //We are done fixing
        }else{
            if versionFixed.nextVersionUUIDString != nil && versionFixed.next == nil{
                self.first(versionFixed.nextVersionUUID, classType: versionFixed, relatedObject: versionFixed.next){
                    (isNew,nextFound) in
                    
                    guard let nextFound = nextFound as? PCKVersionedObject else{
                        //Next version not found, stop fixing
                        return
                    }
                    versionFixed.nextVersion = nextFound
                    if isNew{
                        versionFixed.save(callbackQueue: .global(qos: .background)){ results in
                            switch results {
                            
                            case .success(_):
                                if nextFound.previous == nil{
                                    nextFound.previousVersion = versionFixed
                                    nextFound.save(callbackQueue: .global(qos: .background)){ results in
                                    
                                        switch results {
                                        
                                        case .success(_):
                                            self.fixVersionLinkedList(nextFound, backwards: backwards)
                                        case .failure(let error):
                                            print("Couldn't save in fixVersionLinkedList(). Error: \(error). Object: \(versionFixed)")
                                        }
                                    }
                                }else{
                                    self.fixVersionLinkedList(nextFound, backwards: backwards)
                                }
                            case .failure(let error):
                                print("Couldn't save in fixVersionLinkedList(). Error: \(error). Object: \(versionFixed)")
                            }
                        }
                    }
                }
            }
            //We are done fixing
        }
    }

    //This query doesn't filter nextVersion effectiveDate >= interval.end
    public class func query(for date: Date) -> Query<PCKVersionedObject> {
        var query = queryVersion(for: date, queryToAndWith: queryWhereNoNextVersionOrNextVersionGreaterThanEqualToDate(for: date))
        query.include([kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        return query
    }

    public func find(for date: Date, completion: @escaping([PCKVersionedObject]?, Error?) -> Void) {
        let query = Self.query(for: date)
        query.find(callbackQueue: .global(qos: .background)) { results in
            switch results {
            
            case .success(let entities):
                completion(entities, nil)
            case .failure(let error):
                completion(nil, error)
            }
            
        }
    }

    ///Link versions and related classes
    public func linkRelated(completion: @escaping(Bool, PCKVersionedObject)->Void){
        var linkedNew = false
        self.first(self.previousVersionUUID, classType: self, relatedObject: self.previous, include: true){
            (isNew,previousObject) in
            
            guard let previousObject  = previousObject as? PCKVersionedObject else{
                completion(false,self)
                return
            }
            
            self.previousVersion = previousObject
            if isNew{
                linkedNew = true
            }
            
            self.first(self.nextVersionUUID, classType: self, relatedObject: self.next, include: true){
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
    
    public func save(_ versionedObject: PCKVersionedObject, completion: @escaping(Bool, Error?) -> Void){
        switch versionedObject{
        case is CarePlan:
            
            guard let versionedObject = versionedObject as? CarePlan else{
                completion(false,ParseCareKitError.cantCastToNeededClassType)
                return
            }
            
            _ = versionedObject.stampRelationalEntities()
            
        case is Contact:
            guard let versionedObject = versionedObject as? Contact else{
                completion(false,ParseCareKitError.cantCastToNeededClassType)
                return
            }
            
            _ = versionedObject.stampRelationalEntities()

        case is Patient:
            guard let versionedObject = versionedObject as? Patient else{
                completion(false,ParseCareKitError.cantCastToNeededClassType)
                return
            }
            
            _ = versionedObject.stampRelationalEntities()

        case is Task:
            guard let versionedObject = versionedObject as? Task else{
                completion(false,ParseCareKitError.cantCastToNeededClassType)
                return
            }
            
            _ = versionedObject.stampRelationalEntities()

        default:
            completion(false,ParseCareKitError.classTypeNotAnEligibleType)
        }
        
        versionedObject.save(callbackQueue: .global(qos: .background)){ results in
            switch results {
            
            case .success(_):
                print("Successfully added \(versionedObject) to Cloud")
                
                versionedObject.linkRelated{
                    (linked,_) in
                    
                    if linked{
                        versionedObject.save(callbackQueue: .global(qos: .background)) { _ in }
                    }
                    
                    //Fix versioning doubly linked list if it's broken in the cloud
                    if versionedObject.previous != nil {
                        if versionedObject.previous!.next == nil{
                            versionedObject.previous!.nextVersion = versionedObject
                            versionedObject.previous!.save(callbackQueue: .global(qos: .background)){ results in
                                switch results {
                                    
                                case .success(_):
                                    versionedObject.fixVersionLinkedList(versionedObject.previous!, backwards: true)
                                case .failure(let error):
                                    print("Couldn't save(). Error: \(error). Object: \(versionedObject)")
                                }
                            }
                        }
                    }
                    
                    if versionedObject.next != nil {
                        if versionedObject.next!.previous == nil{
                            versionedObject.next!.previousVersion = versionedObject
                            versionedObject.next!.save(callbackQueue: .global(qos: .background)){ results in
                                switch results {
                                
                                case .success(_):
                                    versionedObject.fixVersionLinkedList(versionedObject.next!, backwards: false)
                                case .failure(let error):
                                    print("Couldn't save(). Error: \(error). Object: \(versionedObject)")
                                }
                            }
                        }
                    }
                    completion(true, nil)
                }
            case .failure(let error):
                print("Error in \(self.className).save(). \(String(describing: error))")
                completion(false, error)
            }
        }
    }
}
