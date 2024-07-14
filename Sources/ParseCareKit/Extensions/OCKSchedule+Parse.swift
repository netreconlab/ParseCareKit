//
//  OCKSchedule+Parse.swift
//  ParseCareKit
//
//  Created by Corey Baker on 7/13/24.
//  Copyright © 2024 Network Reconnaissance Lab. All rights reserved.
//

import CareKitStore
import Foundation

extension OCKSchedule: @unchecked Sendable {}

extension OCKSchedule: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(elements)
    }

}
