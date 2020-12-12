//
//  ParseCareKitLog.swift
//  ParseCareKit
//
//  Created by Corey Baker on 12/12/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import os.log

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier!
    static let category = "ParseCareKit"
    static let carePlan = OSLog(subsystem: subsystem, category: "\(category).carePlan")
    static let contact = OSLog(subsystem: subsystem, category: "\(category).carePlan")
    static let patient = OSLog(subsystem: subsystem, category: "\(category).patient")
    static let task = OSLog(subsystem: subsystem, category: "\(category).task")
    static let outcome = OSLog(subsystem: subsystem, category: "\(category).outcome")
    static let versionable = OSLog(subsystem: subsystem, category: "\(category).versionable")
    static let objectable = OSLog(subsystem: subsystem, category: "\(category).objectable")
    static let pullRevisions = OSLog(subsystem: subsystem, category: "\(category).pullRevisions")
    static let pushRevisions = OSLog(subsystem: subsystem, category: "\(category).pushRevisions")
    static let clock = OSLog(subsystem: subsystem, category: "\(category).clock")
}

@available(iOS 14.0, watchOS 7.0, *)
extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!
    static let category = "ParseCareKit"
    static let carePlan = Logger(subsystem: subsystem, category: "\(category).carePlan")
    static let contact = Logger(subsystem: subsystem, category: "\(category).carePlan")
    static let patient = Logger(subsystem: subsystem, category: "\(category).patient")
    static let task = Logger(subsystem: subsystem, category: "\(category).task")
    static let outcome = Logger(subsystem: subsystem, category: "\(category).outcome")
    static let versionable = Logger(subsystem: subsystem, category: "\(category).versionable")
    static let objectable = Logger(subsystem: subsystem, category: "\(category).objectable")
    static let pullRevisions = Logger(subsystem: subsystem, category: "\(category).pullRevisions")
    static let pushRevisions = Logger(subsystem: subsystem, category: "\(category).pushRevisions")
    static let clock = Logger(subsystem: subsystem, category: "\(category).clock")
}
