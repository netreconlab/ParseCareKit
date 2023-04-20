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

    override func setUpWithError() throws {}

    override func tearDownWithError() throws {}

    func testCarePlan() throws {
        Logger.carePlan.error("Testing")
    }

    func testContact() throws {
        Logger.contact.error("Testing")
    }

    func testPatient() throws {
        Logger.patient.error("Testing")
    }

    func testTask() throws {
        Logger.task.error("Testing")
    }

    func testOutcome() throws {
        Logger.outcome.error("Testing")
    }

    func testVersionable() throws {
        Logger.versionable.error("Testing")
    }

    func testObjectable() throws {
        Logger.objectable.error("Testing")
    }

    func testPullRevisions() throws {
        Logger.pullRevisions.error("Testing")
    }

    func testPushRevisions() throws {
        Logger.pushRevisions.error("Testing")
    }

    func testClock() throws {
        Logger.clock.error("Testing")
    }

    func testInitializer() throws {
        Logger.initializer.error("Testing")
    }
}
