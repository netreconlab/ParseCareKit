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
    @NSManaged var logicalClock: Int
    @NSManaged public internal(set) var createdDate: Date?
    @NSManaged public internal(set) var updatedDate: Date?
    @NSManaged public internal(set) var deletedDate: Date?
    @NSManaged public internal(set) var timezoneIdentifier: String
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
    
    func copy(_ parse: PCKObject){
        self.uuid = parse.uuid
        self.entityId = parse.entityId
        self.deletedDate = parse.deletedDate
        self.updatedDate = parse.updatedDate
        self.timezoneIdentifier = parse.timezoneIdentifier
        self.userInfo = parse.userInfo
        self.remoteID = parse.remoteID
        self.createdDate = parse.createdDate
        self.notes = parse.notes
        self.logicalClock = parse.logicalClock
    }
    
    open func copyRelationalEntities(_ parse: PCKObject){
        Note.replaceWithCloudVersion(&self.notes, cloud: parse.notes)
    }
}
