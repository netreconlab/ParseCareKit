//
//  PCKObjectable.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/26/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore

internal protocol PCKObjectable: ParseObject {
    /// A universally unique identifier for this object.
    var uuid: UUID? {get set}

    /// A human readable unique identifier. It is used strictly by the developer and will never be shown to a user
    var id:String { get }
    
    /// A human readable unique identifier. It is used strictly by the developer and will never be shown to a user
    var entityId: String? {get set}
    
    var logicalClock: Int? {get set}
    
    /// The semantic version of the database schema when this object was created.
    /// The value will be nil for objects that have not yet been persisted.
    var schemaVersion: OCKSemanticVersion? {get set}
    
    /// The date at which the object was first persisted to the database.
    /// It will be nil for unpersisted values and objects.
    var createdDate: Date? {get set}
    
    /// The last date at which the object was updated.
    /// It will be nil for unpersisted values and objects.
    var updatedDate: Date? {get set}
    
    /// The timezone this record was created in.
    var timezone: TimeZone {get set}
    
    /// A dictionary of information that can be provided by developers to support their own unique
    /// use cases.
    var userInfo: [String: String]? {get set}
    
    /// A user-defined group identifier that can be used both for querying and sorting results.
    /// Examples may include: "medications", "exercises", "family", "males", "diabetics", etc.
    var groupIdentifier: String? {get set}
    
    /// An array of user-defined tags that can be used to sort or classify objects or values.
    var tags: [String]? {get set}
    
    /// Specifies where this object originated from. It could contain information about the device
    /// used to record the data, its software version, or the person who recorded the data.
    var source: String? {get set}
    
    /// Specifies the location of some asset associated with this object. It could be the URL for
    /// an image or video, the bundle name of a audio asset, or any other representation the
    /// developer chooses.
    var asset: String? {get set}
    
    /// Any array of notes associated with this object.
    var notes: [Note]? {get set}
    
    /// A unique id optionally used by a remote database. Its precise format will be
    /// determined by the remote database, but it is generally not expected to be human readable.
    var remoteID: String? {get set}
    
    var encodingForParse: Bool {get set}

    static func copyValues(from other: Self, to here: Self) throws -> Self
}

extension PCKObjectable {

    mutating func copyRelationalEntities(_ parse: Self) -> Self {
        var current = self
        Note.replaceWithCloudVersion(&current.notes, cloud: parse.notes)
        return current
    }
    
    mutating public func copyCommonValues(from other: Self) {
        uuid = other.uuid
        entityId = other.entityId
        updatedDate = other.updatedDate
        timezone = other.timezone
        userInfo = other.userInfo
        remoteID = other.remoteID
        createdDate = other.createdDate
        notes = other.notes
        logicalClock = other.logicalClock
        source = other.source
        asset = other.asset
        schemaVersion = other.schemaVersion
        groupIdentifier = other.groupIdentifier
        tags = other.tags
    }

    mutating public func stampRelationalEntities() throws -> Self {
        guard let logicalClock = self.logicalClock else {
            throw ParseCareKitError.cantUnwrapSelf
        }
        self.notes?.forEach{$0.stamp(logicalClock)}
        return self
    }

    public func canConvertToCareKit()->Bool {
        guard let _ = self.entityId else {
            return false
        }
        return true
    }

    public func first(_ uuid:UUID?, relatedObject:Self?=nil, include:Bool=true, completion: @escaping(Bool,Self?) -> Void) {
          
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
             
        let query = Self.query(kPCKObjectableUUIDKey == uuidString)
        
        switch self {
        case is CarePlan:
            if include{
                _ = query.include(kPCKCarePlanPatientKey,kPCKObjectableNotesKey,
                                  kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey)
            }
        case is Contact:
            if include{
                _ = query.include(kPCKContactCarePlanKey,kPCKObjectableNotesKey,
                              kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey)
            }
        case is Outcome:
            if include{
                _ = query.include(kPCKOutcomeTaskKey,
                                      kPCKOutcomeValuesKey,kPCKObjectableNotesKey)
            }
        case is Patient:
            if include{
                _ = query.include(kPCKObjectableNotesKey,
                              kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey)
            }
        case is Task:
            if include{
                _ = query.include(kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectableNotesKey,
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
    
    public func find(_ uuid:UUID?, include:Bool=true,
                         completion: @escaping([Self]?,Error?) -> Void) {
          
        guard let _ = PCKUser.current,
            let uuidString = uuid?.uuidString else{
                print("Error in \(self.className).find(). \(ParseCareKitError.requiredValueCantBeUnwrapped)")
                completion(nil,ParseCareKitError.couldntUnwrapClock)
                return
        }
            
        let query = Self.query(kPCKObjectableUUIDKey == uuidString)

        switch self {
        case is CarePlan:
            if include{
                _ = query.include(kPCKCarePlanPatientKey,kPCKObjectableNotesKey,
                              kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey)
            }
        case is Contact:
            if include{
                _ = query.include([kPCKContactCarePlanKey,kPCKObjectableNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
            }
        case is Outcome:
            if include{
                _ = query.include([kPCKOutcomeTaskKey,kPCKOutcomeValuesKey,kPCKObjectableNotesKey])
            }
        case is Patient:
            if include{
                _ = query.include([kPCKObjectableNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
            }
        case is Task:
            if include{
                _ = query.include([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectableNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
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

//Encodable
extension PCKObjectable {
    
    public func encodeObjectable(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: PCKCodingKeys.self)
        
        if encodingForParse {
            if !(self is Note) {
                try container.encodeIfPresent(entityId, forKey: .entityId)
            }
            try container.encodeIfPresent(ACL, forKey: .ACL)
            try container.encodeIfPresent(logicalClock, forKey: .logicalClock)
        } else {
            if !(self is Outcome) {
                try container.encodeIfPresent(entityId, forKey: .id)
            }
        }
        try container.encode(uuid, forKey: .uuid)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(updatedDate, forKey: .updatedDate)
        try container.encode(timezone, forKey: .timezone)
        try container.encodeIfPresent(userInfo, forKey: .userInfo)
        try container.encodeIfPresent(groupIdentifier, forKey: .groupIdentifier)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(asset, forKey: .asset)
        try container.encodeIfPresent(remoteID, forKey: .remoteID)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}
