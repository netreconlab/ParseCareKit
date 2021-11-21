//
//  LoggerTests.swift
//  ParseCareKitTests
//
//  Created by Corey Baker on 12/13/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import XCTest
@testable import ParseCareKit
import os.log

class LoggerTests: XCTestCase {

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testCarePlan() throws {
        if #available(iOS 14.0, watchOS 7.0, *) {
            Logger.carePlan.error("Testing")
        } else {
            os_log("Testing",
                   log: .carePlan, type: .error)
        }
    }

    func testContact() throws {
        if #available(iOS 14.0, watchOS 7.0, *) {
            Logger.contact.error("Testing")
        } else {
            os_log("Testing",
                   log: .contact, type: .error)
        }
    }

    func testPatient() throws {
        if #available(iOS 14.0, watchOS 7.0, *) {
            Logger.patient.error("Testing")
        } else {
            os_log("Testing",
                   log: .patient, type: .error)
        }
    }

    func testTask() throws {
        if #available(iOS 14.0, watchOS 7.0, *) {
            Logger.task.error("Testing")
        } else {
            os_log("Testing",
                   log: .task, type: .error)
        }
    }

    func testOutcome() throws {
        if #available(iOS 14.0, watchOS 7.0, *) {
            Logger.outcome.error("Testing")
        } else {
            os_log("Testing",
                   log: .outcome, type: .error)
        }
    }

    func testVersionable() throws {
        if #available(iOS 14.0, watchOS 7.0, *) {
            Logger.versionable.error("Testing")
        } else {
            os_log("Testing",
                   log: .versionable, type: .error)
        }
    }

    func testObjectable() throws {
        if #available(iOS 14.0, watchOS 7.0, *) {
            Logger.objectable.error("Testing")
        } else {
            os_log("Testing",
                   log: .objectable, type: .error)
        }
    }

    func testPullRevisions() throws {
        if #available(iOS 14.0, watchOS 7.0, *) {
            Logger.pullRevisions.error("Testing")
        } else {
            os_log("Testing",
                   log: .pullRevisions, type: .error)
        }
    }

    func testPushRevisions() throws {
        if #available(iOS 14.0, watchOS 7.0, *) {
            Logger.pushRevisions.error("Testing")
        } else {
            os_log("Testing",
                   log: .pushRevisions, type: .error)
        }
    }

    func testClock() throws {
        if #available(iOS 14.0, watchOS 7.0, *) {
            Logger.clock.error("Testing")
        } else {
            os_log("Testing",
                   log: .clock, type: .error)
        }
    }

    func testInitializer() throws {
        if #available(iOS 14.0, watchOS 7.0, *) {
            Logger.initializer.error("Testing")
        } else {
            os_log("Testing",
                   log: .initializer, type: .error)
        }
    }
}
