//
//  PCKUser.swift
//  ParseCareKit
//
//  Created by Corey Baker on 9/25/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift

struct PCKUser: ParseUser {
    var authData: [String: [String: String]?]?

    var sessionToken: String?

    var username: String?

    var email: String?

    var password: String?

    var objectId: String?

    var createdAt: Date?

    var updatedAt: Date?

    var ACL: ParseACL?
}
