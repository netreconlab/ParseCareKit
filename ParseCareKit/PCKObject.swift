//
//  PCKObject.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/26/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import Parse

open class PCKObject: PFObject {
    
    @NSManaged public var uuid: String
    @NSManaged public var entityId:String
    @NSManaged public var logicalClock: Int
    @NSManaged public var createdDate: Date?
    @NSManaged public var updatedDate: Date?
    @NSManaged public var deletedDate: Date?
    @NSManaged public var userInfo: [String: String]?
    @NSManaged public var groupIdentifier: String?
    @NSManaged public var tags: [String]?
    @NSManaged public var source: String?
    @NSManaged public var asset: String?
    @NSManaged public var notes: [Note]?
    @NSManaged public var timezoneIdentifier: String
    
    open func stampRelationalEntities(){
        self.notes?.forEach{$0.stamp(self.logicalClock)}
    }
}
