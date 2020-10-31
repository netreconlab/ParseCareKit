//
//  PCKVersionable.swift
//  ParseCareKit
//
//  Created by Corey Baker on 9/28/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift

internal protocol PCKVersionable: PCKObjectable {
    /// The UUID of the previous version of this object, or nil if there is no previous version.
    var previousVersionUUID: UUID? { get set }

    var previousVersion: Self? { get set }
    
    /// The database UUID of the next version of this object, or nil if there is no next version.
    var nextVersionUUID: UUID? { get set }

    var nextVersion: Self? { get set }
    
    /// The date that this version of the object begins to take precedence over the previous version.
    /// Often this will be the same as the `createdDate`, but is not required to be.
    var effectiveDate: Date { get set }

    /// The date on which this object was marked deleted. Note that objects are never actually deleted,
    /// but rather they are marked deleted and will no longer be returned from queries.
    var deletedDate: Date? {get set}
    
}

extension PCKVersionable {

    mutating public func copyVersionedValues(from other: Self) {
        self.effectiveDate = other.effectiveDate
        self.deletedDate = other.deletedDate
        self.previousVersion = other.previousVersion
        self.nextVersion = other.nextVersion
        //Copy UUID's after
        self.previousVersionUUID = other.previousVersionUUID
        self.nextVersionUUID = other.nextVersionUUID
        self.copyCommonValues(from: other)
    }

    ///Link versions and related classes
    func linkVersions(completion: @escaping (Bool, Self) -> Void) {
        var linkedNew = false
        var versionedObject = self
        Self.first(versionedObject.previousVersionUUID, relatedObject: versionedObject.previousVersion, include: true){
            (isNew,previousObject) in
            
            guard let previousObject  = previousObject else{
                completion(linkedNew, versionedObject)
                return
            }
            
            versionedObject.previousVersion = previousObject
            if isNew{
                linkedNew = true
            }
            
            Self.first(versionedObject.nextVersionUUID, relatedObject: versionedObject.nextVersion, include: true){
                (isNew,nextObject) in
                
                guard let nextObject  = nextObject else{
                    completion(linkedNew,versionedObject)
                    return
                }
                
                versionedObject.nextVersion = nextObject
                if isNew{
                    linkedNew = true
                }
                
                completion(linkedNew,versionedObject)
            }
        }
    }

    func fixVersionLinkedList(_ versionFixed: Self, backwards:Bool){
        var versionFixed = versionFixed
        
        if backwards{
            if versionFixed.previousVersionUUID != nil && versionFixed.previousVersion == nil{
                Self.first(versionFixed.previousVersionUUID, relatedObject: versionFixed.previousVersion){
                    (isNew,previousFound) in

                    
                    guard var previousFound = previousFound else{
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
                Self.first(versionFixed.nextVersionUUID, relatedObject: versionFixed.nextVersion){
                    (isNew,nextFound) in
                    
                    guard var nextFound = nextFound else{
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

    public func save(completion: @escaping(Bool, Error?) -> Void) {
        var versionedObject = self
        _ = try? versionedObject.stampRelationalEntities()
        versionedObject.save(callbackQueue: .global(qos: .background)){ results in
            switch results {
            
            case .success(_):
                print("Successfully added \(self) to Cloud")
                
                self.linkVersions { (linked, modifiedObject) in
                    var modifiedObject = modifiedObject
                    if linked{
                        modifiedObject.save(callbackQueue: .global(qos: .background)) { _ in }
                    }
                    
                    //Fix versioning doubly linked list if it's broken in the cloud
                    if modifiedObject.previousVersion != nil {
                        if modifiedObject.previousVersion!.nextVersion == nil {
                            modifiedObject.previousVersion!.find(modifiedObject.previousVersion!.uuid) {
                                results in
                                
                                switch results {
                                
                                case .success(let versionedObjectsFound):
                                    guard var previousObjectFound = versionedObjectsFound.first else {
                                        return
                                    }
                                    previousObjectFound = modifiedObject
                                    previousObjectFound.save(callbackQueue: .global(qos: .background)){ results in
                                        switch results {
                                            
                                        case .success(_):
                                            self.fixVersionLinkedList(previousObjectFound, backwards: true)
                                        case .failure(let error):
                                            print("Couldn't save(). Error: \(error). Object: \(self)")
                                        }
                                    }
                                case .failure(let error):
                                    print("Couldn't find object in save(). Error: \(error). Object: \(self)")
                                }
                            }
                            /*modifiedObject.previousVersion!.nextVersion = modifiedObject
                            modifiedObject.previousVersion!.save(callbackQueue: .global(qos: .background)){ results in
                                switch results {
                                    
                                case .success(_):
                                    self.fixVersionLinkedList(modifiedObject.previousVersion!, backwards: true)
                                case .failure(let error):
                                    print("Couldn't save(). Error: \(error). Object: \(self)")
                                }
                            }*/
                        }
                    }
                    
                    if modifiedObject.nextVersion != nil {
                        if modifiedObject.nextVersion!.previousVersion == nil{
                            modifiedObject.nextVersion!.previousVersion = modifiedObject
                            modifiedObject.nextVersion!.save(callbackQueue: .global(qos: .background)){ results in
                                switch results {
                                
                                case .success(_):
                                    self.fixVersionLinkedList(modifiedObject.nextVersion!, backwards: false)
                                case .failure(let error):
                                    print("Couldn't save(). Error: \(error). Object: \(self)")
                                }
                            }
                        }
                    }
                    completion(true, nil)
                }
            case .failure(let error):
                print("Error in \(versionedObject.className).save(). \(String(describing: error))")
                completion(false, error)
            }
        }
    }
}

//Fetching
extension PCKVersionable {
    private static func queryVersion(for date: Date, queryToAndWith: Query<Self>)-> Query<Self> {
        let interval = createCurrentDateInterval(for: date)
    
        let query = queryToAndWith
        _ = query.where(doesNotExist(key: kPCKObjectableDeletedDateKey)) //Only consider non deleted keys
        _ = query.where(kPCKVersionedObjectEffectiveDateKey < interval.end)
        return query
    }
    
    private static func queryWhereNoNextVersionOrNextVersionGreaterThanEqualToDate(for date: Date)-> Query<Self> {
        
        let query = Self.query(doesNotExist(key: kPCKVersionedObjectNextKey))
        
        let interval = createCurrentDateInterval(for: date)
        let greaterEqualEffectiveDate = self.query(kPCKVersionedObjectEffectiveDateKey >= interval.end)
        return Self.query(or(queries: [query,greaterEqualEffectiveDate]))
    }
    
    func find(for date: Date) throws -> [Self] {
        try Self.query(for: date).find()
    }
    
    

    //This query doesn't filter nextVersion effectiveDate >= interval.end
    public static func query(for date: Date) -> Query<Self> {
        let query = queryVersion(for: date, queryToAndWith: queryWhereNoNextVersionOrNextVersionGreaterThanEqualToDate(for: date))
        _ = query.includeAll()
        return query
    }

    public func find(for date: Date, completion: @escaping([Self]?, ParseError?) -> Void) {
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
}

//Encodable
extension PCKVersionable {
    
    public func encodeVersionable(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: PCKCodingKeys.self)
        
        if encodingForParse {
            try container.encodeIfPresent(nextVersion, forKey: .nextVersion)
            try container.encodeIfPresent(previousVersion, forKey: .previousVersion)
            
        }
        try container.encodeIfPresent(deletedDate, forKey: .deletedDate)
        try container.encodeIfPresent(previousVersionUUID, forKey: .previousVersionUUID)
        try container.encodeIfPresent(nextVersionUUID, forKey: .nextVersionUUID)
        try container.encode(effectiveDate, forKey: .effectiveDate)
        try encodeObjectable(to: encoder)
    }
}
