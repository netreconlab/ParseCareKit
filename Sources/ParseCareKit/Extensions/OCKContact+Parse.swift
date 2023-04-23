//
//  OCKContact+Parse.swift
//  ParseCareKit
//
//  Created by Corey Baker on 11/21/21.
//  Copyright © 2021 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import CareKitStore
import ParseSwift
import os.log

public extension OCKContact {
    /**
     The Parse ACL for this object.
    */
    var acl: ParseACL? {
        get {
            guard let aclString = userInfo?[ParseCareKitConstants.acl],
                  let aclData = aclString.data(using: .utf8),
                  let acl = try? PCKUtility.decoder().decode(ParseACL.self, from: aclData) else {
                      return nil
                  }
            return acl
        }
        set {
            do {
                let encodedACL = try PCKUtility.jsonEncoder().encode(newValue)
                guard let aclString = String(data: encodedACL, encoding: .utf8) else {
                    throw ParseCareKitError.cantEncodeACL
                }
                if userInfo != nil {
                    userInfo?[ParseCareKitConstants.acl] = aclString
                } else {
                    userInfo = [ParseCareKitConstants.acl: aclString]
                }
            } catch {
                Logger.ockContact.error("Cannot set ACL: \(error)")
            }
        }
    }

    /**
     The Parse `className` for this object.
    */
    var className: String? {
        get {
            return userInfo?[CustomKey.className]
        }
        set {
            if userInfo != nil {
                userInfo?[CustomKey.className] = newValue
            } else if let newValue = newValue {
                userInfo = [CustomKey.className: newValue]
            }
        }
    }
}
