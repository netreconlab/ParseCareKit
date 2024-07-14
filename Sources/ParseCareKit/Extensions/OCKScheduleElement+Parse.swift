//
//  OCKScheduleElement+Parse.swift
//  ParseCareKit
//
//  Created by Corey Baker on 7/13/24.
//  Copyright © 2024 Network Reconnaissance Lab. All rights reserved.
//

import CareKitStore
import Foundation

extension OCKScheduleElement: @unchecked Sendable {}

extension OCKScheduleElement.Duration: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self)
    }
}

extension OCKScheduleElement: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(text)
        hasher.combine(duration)
        hasher.combine(start)
        hasher.combine(end)
        hasher.combine(interval)
        hasher.combine(targetValues)
    }

}
