//
//  UtilityTests.swift
//  ParseCareKitTests
//
//  Created by Corey Baker on 11/21/21.
//  Copyright © 2021 Network Reconnaissance Lab. All rights reserved.
//

import XCTest
@testable import ParseCareKit
@testable import ParseSwift

class UtilityTests: XCTestCase {

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
        MockURLProtocol.removeAll()
        try KeychainStore.shared.deleteAll()
        try ParseStorage.shared.deleteAll()
        UserDefaults.standard.removeObject(forKey: ParseCareKitConstants.defaultACL)
        UserDefaults.standard.synchronize()
    }

    func testSetupServer() throws {
        try PCKUtility.setupServer { (_, completionHandler) in
            completionHandler(.performDefaultHandling, nil)
        }
        XCTAssertEqual(ParseSwift.configuration.applicationId, "3B5FD9DA-C278-4582-90DC-101C08E7FC98")
        XCTAssertEqual(ParseSwift.configuration.clientKey, "hello")
        XCTAssertEqual(ParseSwift.configuration.serverURL, URL(string: "http://localhost:1337/parse"))
        XCTAssertEqual(ParseSwift.configuration.liveQuerysServerURL, URL(string: "ws://localhost:1337/parse"))
        XCTAssertTrue(ParseSwift.configuration.isUsingTransactions)
        XCTAssertTrue(ParseSwift.configuration.isDeletingKeychainIfNeeded)
    }
}
