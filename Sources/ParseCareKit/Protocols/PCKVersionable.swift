//
//  PCKVersionable.swift
//  ParseCareKit
//
//  Created by Corey Baker on 9/28/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation

internal protocol PCKVersionable: PCKObjectable {
    /// The UUID of the previous version of this object, or nil if there is no previous version.
    var previousVersionUUID: UUID? { get set }

    var previousVersion: PCKVersionedObject? { get set }
    
    /// The database UUID of the next version of this object, or nil if there is no next version.
    var nextVersionUUID: UUID? { get set }

    var nextVersion: PCKVersionedObject? { get set }
    
    /// The date that this version of the object begins to take precedence over the previous version.
    /// Often this will be the same as the `createdDate`, but is not required to be.
    var effectiveDate: Date? { get set }
    
}

