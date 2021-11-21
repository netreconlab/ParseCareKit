//
//  OCKCarePlan+Parse.swift
//  ParseCareKit
//
//  Created by Corey Baker on 11/21/21.
//  Copyright © 2021 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import CareKitStore
import ParseSwift

public extension OCKCarePlan {
    /**
    The Parse ACL for this object.
    */
    var acl: ParseACL? {
        guard let aclString = userInfo?[ParseCareKitConstants.acl],
              let aclData = aclString.data(using: .utf8),
              let acl = try? PCKUtility.decoder().decode(ParseACL.self, from: aclData) else {
                  return nil
              }
        return acl
    }

    /**
    Set the Parse ACL for this object.
    */
    mutating func setACL(_ acl: ParseACL) throws {
        let encodedACL = try PCKUtility.jsonEncoder().encode(acl)
        guard let aclString = String(data: encodedACL, encoding: .utf8) else {
            throw ParseCareKitError.cantEncodeACL
        }
        if var userInfo = userInfo {
            userInfo[ParseCareKitConstants.acl] = aclString
        } else {
            userInfo = [ParseCareKitConstants.acl: aclString]
        }
    }
}
