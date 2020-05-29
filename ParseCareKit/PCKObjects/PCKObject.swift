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
    
    public weak var store:OCKStore!
    
    open func stampRelationalEntities(){
        self.notes?.forEach{$0.stamp(self.logicalClock)}
    }
}
