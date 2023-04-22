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
    static let healthKitTask = OSLog(subsystem: subsystem, category: "\(category).healthKitTask")
    static let outcome = OSLog(subsystem: subsystem, category: "\(category).outcome")
    static let versionable = OSLog(subsystem: subsystem, category: "\(category).versionable")
    static let objectable = OSLog(subsystem: subsystem, category: "\(category).objectable")
    static let pullRevisions = OSLog(subsystem: subsystem, category: "\(category).pullRevisions")
    static let pushRevisions = OSLog(subsystem: subsystem, category: "\(category).pushRevisions")
    static let syncProgress = OSLog(subsystem: subsystem, category: "\(category).syncProgress")
    static let clock = OSLog(subsystem: subsystem, category: "\(category).clock")
    static let clockSubscription = OSLog(subsystem: subsystem, category: "\(category).clockSubscription")
    static let defaultACL = OSLog(subsystem: subsystem, category: "\(category).defaultACL")
    static let initializer = OSLog(subsystem: subsystem, category: "\(category).initializer")
    static let deinitializer = OSLog(subsystem: subsystem, category: "\(category).deinitializer")
    static let ockCarePlan = OSLog(subsystem: subsystem, category: "\(category).OCKCarePlan")
    static let ockContact = OSLog(subsystem: subsystem, category: "\(category).OCKContact")
    static let ockHealthKitTask = OSLog(subsystem: subsystem, category: "\(category).OCKHealthKitTask")
    static let ockOutcome = OSLog(subsystem: subsystem, category: "\(category).OCKOutcome")
    static let ockPatient = OSLog(subsystem: subsystem, category: "\(category).OCKPatient")
    static let ockTask = OSLog(subsystem: subsystem, category: "\(category).OCKTask")
}

@available(iOS 14.0, watchOS 7.0, *)
extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!
    static let category = "ParseCareKit"
    static let carePlan = Logger(subsystem: subsystem, category: "\(category).carePlan")
    static let contact = Logger(subsystem: subsystem, category: "\(category).carePlan")
    static let patient = Logger(subsystem: subsystem, category: "\(category).patient")
    static let task = Logger(subsystem: subsystem, category: "\(category).task")
    static let healthKitTask = Logger(subsystem: subsystem, category: "\(category).healthKitTask")
    static let outcome = Logger(subsystem: subsystem, category: "\(category).outcome")
    static let versionable = Logger(subsystem: subsystem, category: "\(category).versionable")
    static let objectable = Logger(subsystem: subsystem, category: "\(category).objectable")
    static let pullRevisions = Logger(subsystem: subsystem, category: "\(category).pullRevisions")
    static let pushRevisions = Logger(subsystem: subsystem, category: "\(category).pushRevisions")
    static let syncProgress = Logger(subsystem: subsystem, category: "\(category).syncProgress")
    static let clock = Logger(subsystem: subsystem, category: "\(category).clock")
    static let revisionRecordSubscription = Logger(subsystem: subsystem,
                                                   category: "\(category).revisionRecordSubscription")
    static let defaultACL = Logger(subsystem: subsystem, category: "\(category).defaultACL")
    static let initializer = Logger(subsystem: subsystem, category: "\(category).initializer")
    static let deinitializer = Logger(subsystem: subsystem, category: "\(category).deinitializer")
    static let ockCarePlan = Logger(subsystem: subsystem, category: "\(category).OCKCarePlan")
    static let ockContact = Logger(subsystem: subsystem, category: "\(category).OCKContact")
    static let ockHealthKitTask = Logger(subsystem: subsystem, category: "\(category).OCKHealthKitTask")
    static let ockOutcome = Logger(subsystem: subsystem, category: "\(category).OCKOutcome")
    static let ockHealthKitOutcome = Logger(subsystem: subsystem, category: "\(category).OCKHealthKitOutcome")
    static let ockPatient = Logger(subsystem: subsystem, category: "\(category).OCKPatient")
    static let ockTask = Logger(subsystem: subsystem, category: "\(category).OCKTask")
}
