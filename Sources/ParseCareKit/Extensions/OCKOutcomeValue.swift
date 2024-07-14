//
//  OCKOutcomeValue.swift
//  ParseCareKit
//
//  Created by Corey Baker on 7/13/24.
//  Copyright © 2024 Network Reconnaissance Lab. All rights reserved.
//

import CareKitStore
import Foundation

extension OCKOutcomeValue: @unchecked Sendable {}

extension OCKOutcomeValue: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(kind)
        hasher.combine(units)
        hasher.combine(createdDate)
        hasher.combine(integerValue)
        hasher.combine(doubleValue)
        hasher.combine(booleanValue)
        hasher.combine(stringValue)
        hasher.combine(dataValue)
        hasher.combine(dateValue)
    }

}
