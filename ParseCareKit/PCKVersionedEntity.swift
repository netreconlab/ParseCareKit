//
//  PCKVersionedEntity.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/26/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import Parse

open class PCKVersionedEntity: PCKEntity {
    @NSManaged public var effectiveDate: Date
    @NSManaged public var deletedDate: Date?
    @NSManaged public var nextVersionUUID:String?
    @NSManaged public var previousVersionUUID:String?
    /*
    public override class func query() -> PFQuery<PFObject>? {
        <#code#>
    }*/
    
    public class func query(for date: Date) -> PFQuery<PFObject>? {
        let query = self.query()
        
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay)!
        
        return self.query()
    }
}
