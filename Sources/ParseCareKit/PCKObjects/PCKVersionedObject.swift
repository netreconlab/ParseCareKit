//
//  PCKVersionedObject.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/26/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift

open class PCKVersionedObject: PCKObject, PCKVersionable {
    
    public internal(set) var nextVersion: PCKVersionedObject? {
        didSet {
            nextVersionUUID = nextVersion?.uuid
        }
    }
    
    public internal(set) var nextVersionUUID:UUID? {
        didSet {
            if nextVersionUUID != nextVersion?.uuid {
                nextVersion = nil
            }
        }
    }

    public internal(set) var previousVersion: PCKVersionedObject? {
        didSet {
            previousVersionUUID = previousVersion?.uuid
        }
    }
    
    public internal(set) var previousVersionUUID: UUID? {
        didSet {
            if previousVersionUUID != previousVersion?.uuid {
                previousVersion = nil
            }
        }
    }
    
    var effectiveDate: Date?

    override init() {
        super.init()
    }
    
    enum CodingKeys: String, CodingKey { // swiftlint:disable:this nesting
        case nextVersion, previousVersion, effectiveDate, previousVersionUUID, nextVersionUUID
    }
    
    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        if encodingForParse {
            try container.encode(nextVersion, forKey: .nextVersion)
            try container.encode(previousVersion, forKey: .previousVersion)
        }
        try container.encode(previousVersionUUID, forKey: .previousVersionUUID)
        try container.encode(nextVersionUUID, forKey: .nextVersionUUID)
        try container.encode(effectiveDate, forKey: .effectiveDate)
    }
    
    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
    
    public func copyVersionedValues(from other: PCKVersionedObject) {
        self.effectiveDate = other.effectiveDate
        self.previousVersion = other.previousVersion
        self.nextVersion = other.nextVersion
        self.copyCommonValues(from: other)
    }

    private class func queryVersion(for date: Date, queryToAndWith: Query<PCKVersionedObject>)-> Query<PCKVersionedObject> {
        let interval = createCurrentDateInterval(for: date)
    
        var query = queryToAndWith
        query.where(doesNotExist(key: kPCKObjectableDeletedDateKey)) //Only consider non deleted keys
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
            if versionFixed.previousVersionUUID != nil && versionFixed.previousVersion == nil{
                self.first(versionFixed.previousVersionUUID, classType: versionFixed, relatedObject: versionFixed.previousVersion){
                    (isNew,previousFound) in
                    
                    guard let previousFound = previousFound else{
                        //Previous version not found, stop fixing
                        return
                    }
                    versionFixed.previousVersion = previousFound
                    if isNew{
                        versionFixed.save(callbackQueue: .global(qos: .background)) { results in
                            switch results {
                            
                            case .success(_):
                                if previousFound.nextVersion == nil{
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
            if versionFixed.nextVersionUUID != nil && versionFixed.nextVersion == nil{
                self.first(versionFixed.nextVersionUUID, classType: versionFixed, relatedObject: versionFixed.nextVersion){
                    (isNew,nextFound) in
                    
                    guard let nextFound = nextFound else{
                        //Next version not found, stop fixing
                        return
                    }
                    versionFixed.nextVersion = nextFound
                    if isNew{
                        versionFixed.save(callbackQueue: .global(qos: .background)){ results in
                            switch results {
                            
                            case .success(_):
                                if nextFound.previousVersion == nil{
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
        query.include([kPCKObjectableNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
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
        self.first(self.previousVersionUUID, classType: self, relatedObject: self.previousVersion, include: true){
            (isNew,previousObject) in
            
            guard let previousObject  = previousObject else{
                completion(false,self)
                return
            }
            
            self.previousVersion = previousObject
            if isNew{
                linkedNew = true
            }
            
            self.first(self.nextVersionUUID, classType: self, relatedObject: self.nextVersion, include: true){
                (isNew,nextObject) in
                
                guard let nextObject  = nextObject else{
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
                    if versionedObject.previousVersion != nil {
                        if versionedObject.previousVersion!.nextVersion == nil{
                            versionedObject.previousVersion!.nextVersion = versionedObject
                            versionedObject.previousVersion!.save(callbackQueue: .global(qos: .background)){ results in
                                switch results {
                                    
                                case .success(_):
                                    versionedObject.fixVersionLinkedList(versionedObject.previousVersion!, backwards: true)
                                case .failure(let error):
                                    print("Couldn't save(). Error: \(error). Object: \(versionedObject)")
                                }
                            }
                        }
                    }
                    
                    if versionedObject.nextVersion != nil {
                        if versionedObject.nextVersion!.previousVersion == nil{
                            versionedObject.nextVersion!.previousVersion = versionedObject
                            versionedObject.nextVersion!.save(callbackQueue: .global(qos: .background)){ results in
                                switch results {
                                
                                case .success(_):
                                    versionedObject.fixVersionLinkedList(versionedObject.nextVersion!, backwards: false)
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
