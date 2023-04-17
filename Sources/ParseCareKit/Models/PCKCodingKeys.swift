//
//  PCKCodingKeys.swift
//  ParseCareKit
//
//  Created by Corey Baker on 4/17/23.
//  Copyright © 2023 Network Reconnaissance Lab. All rights reserved.
//

import Foundation

// MARK: Coding
enum PCKCodingKeys: String, CodingKey {
    case entityId, id
    case uuid, schemaVersion, createdDate, updatedDate, deletedDate, timezone,
         userInfo, groupIdentifier, tags, source, asset, remoteID, notes,
         logicalClock, clock, className, ACL, objectId, updatedAt, createdAt
    case effectiveDate, previousVersionUUIDs, nextVersionUUIDs
}
