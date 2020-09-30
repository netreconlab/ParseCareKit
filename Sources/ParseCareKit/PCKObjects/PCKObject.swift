//
//  PCKObject.swift
//  ParseCareKit
//
//  Created by Corey Baker on 9/27/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore
/*
open class PCKObject: PCKObjectable {

    public var uuid: UUID?
    
    public var entityId: String?
    
    var schemaVersion: OCKSemanticVersion?
    
    var logicalClock: Int?
    
    public internal(set) var createdDate: Date?
    
    public internal(set) var updatedDate: Date?
    
    public internal(set) var deletedDate: Date?
    
    public internal(set) var timezone: TimeZone?
    
    public var userInfo: [String : String]?
    
    public var groupIdentifier: String?
    
    public var tags: [String]?
    
    public var source: String?
    
    public var asset: String?
    
    public var notes: [Note]?
    
    public var remoteID: String?
    
    public var objectId: String?
    
    public var createdAt: Date?
    
    public var updatedAt: Date?
    
    public var ACL: ParseACL? = try? ParseACL.defaultACL()
    
    var encodingForParse = true

    private let id = "" //This value is to never be set, used for key
    
    init() {}
    
    enum CodingKeys: String, CodingKey { // swiftlint:disable:this nesting
        case entityId, id
        case uuid, schemaVersion, createdDate, updatedDate, deletedDate, timezone, userInfo, groupIdentifier, tags, source, asset, remoteID
    }

    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        if encodingForParse {
            try container.encode(entityId, forKey: .entityId)
        } else {
            try container.encode(entityId, forKey: .id)
        }

        try container.encode(entityId, forKey: .entityId)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(updatedDate, forKey: .updatedDate)
        try container.encode(deletedDate, forKey: .deletedDate)
        try container.encode(timezone, forKey: .timezone)
        try container.encode(userInfo, forKey: .userInfo)
        try container.encode(groupIdentifier, forKey: .groupIdentifier)
        try container.encode(tags, forKey: .tags)
        try container.encode(source, forKey: .source)
        try container.encode(asset, forKey: .asset)
        try container.encode(remoteID, forKey: .remoteID)
    }
/*
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ParseCareKitCodingKeys.self)
        entityId = try container.decode(, forKey: .entityId)
        uuid = try container.decode(uuid, forKey: .uuid)
        schemaVersion = try container.decode(schemaVersion, forKey: .schemaVersion)
        createdDate = try container.decode(createdDate, forKey: .createdDate)
        updatedDate = try container.decode(updatedDate, forKey: .updatedDate)
        deletedDate = try container.decode(deletedDate, forKey: .deletedDate)
        try container.decode(timezone, forKey: .timezone)
        try container.decode(userInfo, forKey: .userInfo)
        try container.decode(groupIdentifier, forKey: .groupIdentifier)
        try container.decode(tags, forKey: .tags)
        try container.decode(source, forKey: .source)
        try container.decode(asset, forKey: .asset)
        try container.decode(remoteID, forKey: .remoteID)
    }*/
    
}
*/
