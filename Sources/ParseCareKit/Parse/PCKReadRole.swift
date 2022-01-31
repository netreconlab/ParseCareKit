//
//  PCKReadRole.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/30/22.
//  Copyright © 2022 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift

struct PCKReadRole: PCKRoleable {
    typealias RoleUser = PCKUser

    var originalData: Data?

    var objectId: String?

    var createdAt: Date?

    var updatedAt: Date?

    var ACL: ParseACL?

    var name: String?

    var owner: PCKUser?

    static var appendString: String {
        "_read"
    }
}
