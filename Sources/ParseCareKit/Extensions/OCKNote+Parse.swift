//
//  OCKNote+Parse.swift
//  ParseCareKit
//
//  Created by Corey Baker on 7/13/24.
//  Copyright © 2024 Network Reconnaissance Lab. All rights reserved.
//

import CareKitStore
import Foundation

extension OCKNote: @unchecked Sendable {}

extension OCKNote: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(author)
        hasher.combine(title)
        hasher.combine(content)
    }

}
