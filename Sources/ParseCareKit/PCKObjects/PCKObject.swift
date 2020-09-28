//
//  PCKObject.swift
//  ParseCareKit
//
//  Created by Corey Baker on 9/27/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift

open class PCKObject: PCKObjectCompatible {
    public var uuid: String?
    
    public var entityId: String?
    
    var schemaVersion: [String : Any]?
    
    var logicalClock: Int?
    
    public internal(set) var createdDate: Date?
    
    public internal(set) var updatedDate: Date?
    
    public internal(set) var deletedDate: Date?
    
    public internal(set) var timezone: String?
    
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
    
    public var ACL: ParseACL?
    
    init() {
        
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

    open func copyRelationalEntities(_ parse: PCKObject) {
        Note.replaceWithCloudVersion(&self.notes, cloud: parse.notes)
    }

    open func copyCommonValues(from other: PCKObject) {
        guard let other = other as? Self else{return}
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

    open func stampRelationalEntities() -> Bool {
        guard let logicalClock = self.logicalClock else {
            return false
        }
        self.notes?.forEach{$0.stamp(logicalClock)}
        return true
    }
}
