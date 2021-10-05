//
//  ParseCareKitTests.swift
//  ParseCareKitTests
//
//  Created by Corey Baker on 9/12/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import XCTest
@testable import ParseCareKit
@testable import CareKitStore
@testable import ParseSwift

struct LoginSignupResponse: ParseUser {

    var authData: [String: [String: String]?]?
    var objectId: String?
    var createdAt: Date?
    var sessionToken: String?
    var updatedAt: Date?
    var ACL: ParseACL?

    // provided by User
    var username: String?
    var email: String?
    var emailVerified: Bool?
    var password: String?

    // Your custom keys
    var customKey: String?

    init() {
        self.createdAt = Date()
        self.updatedAt = Date()
        self.objectId = "yarr"
        self.ACL = nil
        self.customKey = "blah"
        self.sessionToken = "myToken"
        self.username = "hello10"
        self.password = "world"
        self.email = "hello@parse.com"
    }
}

func userLogin() {
    let loginResponse = LoginSignupResponse()

    MockURLProtocol.mockRequests { _ in
        do {
            let encoded = try ParseCoding.jsonEncoder().encode(loginResponse)
            return MockURLResponse(data: encoded, statusCode: 200, delay: 0.0)
        } catch {
            return nil
        }
    }
    do {
       _ = try PCKUser.login(username: loginResponse.username!, password: loginResponse.password!)
    } catch {
        XCTFail(error.localizedDescription)
    }
}

func userLoginToRealServer() {
    let loginResponse = LoginSignupResponse()
    do {
        _ = try PCKUser.signup(username: loginResponse.username!, password: loginResponse.password!)
    } catch {
        do {
            _ = try PCKUser.login(username: loginResponse.username!, password: loginResponse.password!)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}

// swiftlint:disable:next type_body_length
class ParseCareKitTests: XCTestCase {

    private var parse: ParseRemote!
    private var store: OCKStore!

    override func setUpWithError() throws {
        guard let url = URL(string: "http://localhost:1337/1") else {
                    XCTFail("Should create valid URL")
                    return
                }
                ParseSwift.initialize(applicationId: "applicationId",
                                      clientKey: "clientKey",
                                      masterKey: "masterKey",
                                      serverURL: url)
        // userLogin()
        // userLoginToRealServer()
        do {
        parse = try ParseRemote(uuid: UUID(uuidString: "3B5FD9DA-C278-4582-90DC-101C08E7FC98")!,
                                auto: false,
                                subscribeToServerUpdates: false)
        } catch {
            print(error.localizedDescription)
        }
        store = OCKStore(name: "SampleAppStore", type: .onDisk(), remote: parse)
        parse?.parseRemoteDelegate = self

    }

    override func tearDownWithError() throws {
        MockURLProtocol.removeAll()
        try KeychainStore.shared.deleteAll()
        try ParseStorage.shared.deleteAll()
        try store.delete()
    }

    // swiftlint:disable:next function_body_length
    func testPatient() throws {
        var careKit = OCKPatient(id: "myId", givenName: "hello", familyName: "world")
        let careKitNote = OCKNote(author: "myId", title: "hello", content: "world")
        // Special
        careKit.birthday = Date().addingTimeInterval(-300)
        careKit.allergies = ["sneezing"]
        careKit.sex = .female

        // Objectable
        careKit.uuid = UUID()
        careKit.createdDate = Date().addingTimeInterval(-200)
        careKit.deletedDate = Date().addingTimeInterval(-100)
        careKit.updatedDate = Date().addingTimeInterval(-99)
        careKit.timezone = .current
        careKit.userInfo = ["String": "String"]
        careKit.remoteID = "we"
        careKit.groupIdentifier = "mine"
        careKit.tags = ["one", "two"]
        careKit.schemaVersion = .init(majorVersion: 4)
        careKit.source = "yo"
        careKit.asset = "pic"
        careKit.notes = [careKitNote]

        // Versionable
        careKit.previousVersionUUIDs = [UUID()]
        careKit.nextVersionUUIDs = [UUID()]
        careKit.effectiveDate = Date().addingTimeInterval(-199)

        // Test CareKit -> Parse
        var parse = try Patient.copyCareKit(careKit)

        // Special
        XCTAssertEqual(parse.name, careKit.name)
        XCTAssertEqual(parse.sex, careKit.sex)
        XCTAssertNotNil(parse.birthday)
        XCTAssertEqual(parse.allergies, careKit.allergies)

        // Objectable
        XCTAssertEqual(parse.className, "Patient")
        XCTAssertEqual(parse.entityId, careKit.id)
        XCTAssertEqual(parse.uuid, careKit.uuid)
        XCTAssertNotNil(parse.createdDate)
        XCTAssertNotNil(parse.updatedDate)
        XCTAssertNotNil(parse.deletedDate)
        XCTAssertEqual(parse.timezone, careKit.timezone)
        XCTAssertEqual(parse.userInfo, careKit.userInfo)
        XCTAssertEqual(parse.remoteID, careKit.remoteID)
        XCTAssertEqual(parse.source, careKit.source)
        XCTAssertEqual(parse.asset, careKit.asset)
        XCTAssertEqual(parse.schemaVersion, careKit.schemaVersion)
        XCTAssertEqual(parse.groupIdentifier, careKit.groupIdentifier)
        XCTAssertEqual(parse.tags, careKit.tags)
        XCTAssertEqual(parse.notes?.count, 1)
        XCTAssertEqual(parse.notes?.first?.author, "myId")
        XCTAssertEqual(parse.notes?.first?.title, "hello")
        XCTAssertEqual(parse.notes?.first?.content, "world")

        // Versionable
        XCTAssertNotNil(parse.effectiveDate)
        XCTAssertEqual(parse.previousVersionUUIDs, careKit.previousVersionUUIDs)
        XCTAssertEqual(parse.nextVersionUUIDs, careKit.nextVersionUUIDs)

        // Test Parse -> CareKit
        let parse2 = try parse.convertToCareKit()

        // Special
        XCTAssertEqual(parse2.name, careKit.name)
        XCTAssertEqual(parse2.sex, careKit.sex)
        XCTAssertNotNil(parse2.birthday)
        XCTAssertEqual(parse2.allergies, careKit.allergies)

        // Objectable
        XCTAssertEqual(parse2.id, careKit.id)
        XCTAssertEqual(parse2.uuid, careKit.uuid)
        XCTAssertNotNil(parse2.createdDate)
        XCTAssertNotNil(parse2.updatedDate)
        XCTAssertNotNil(parse2.deletedDate)
        XCTAssertEqual(parse2.timezone, careKit.timezone)
        XCTAssertEqual(parse2.userInfo, careKit.userInfo)
        XCTAssertEqual(parse2.remoteID, careKit.remoteID)
        XCTAssertEqual(parse2.source, careKit.source)
        XCTAssertEqual(parse2.asset, careKit.asset)
        XCTAssertEqual(parse2.schemaVersion, careKit.schemaVersion)
        XCTAssertEqual(parse2.groupIdentifier, careKit.groupIdentifier)
        XCTAssertEqual(parse2.tags, careKit.tags)
        XCTAssertEqual(parse2.notes?.count, 1)
        XCTAssertEqual(parse2.notes?.first?.author, "myId")
        XCTAssertEqual(parse2.notes?.first?.title, "hello")
        XCTAssertEqual(parse2.notes?.first?.content, "world")

        // Versionable
        XCTAssertNotNil(parse2.effectiveDate)
        XCTAssertEqual(parse2.previousVersionUUIDs, careKit.previousVersionUUIDs)
        XCTAssertEqual(parse2.nextVersionUUIDs, careKit.nextVersionUUIDs)

        // Encode to cloud format
        guard let note = parse.notes?.first else {
            XCTFail("Should have unwrapped note")
            return
        }
        parse.notes = [note]
        let cloudEncoded = try ParseCoding.parseEncoder().encode(parse)
        let cloudDecoded = try ParseCoding.jsonDecoder().decode(Patient.self, from: cloudEncoded)

        // Objectable
        XCTAssertEqual(parse.className, cloudDecoded.className)
        XCTAssertEqual(parse.uuid, cloudDecoded.uuid)
        XCTAssertEqual(parse.entityId, cloudDecoded.entityId)
        XCTAssertNotNil(cloudDecoded.createdDate)
        XCTAssertNotNil(cloudDecoded.updatedDate)
        XCTAssertEqual(parse.timezone, cloudDecoded.timezone)
        XCTAssertEqual(parse.userInfo, cloudDecoded.userInfo)
        XCTAssertEqual(parse.remoteID, cloudDecoded.remoteID)
        XCTAssertEqual(parse.source, cloudDecoded.source)
        XCTAssertEqual(parse.schemaVersion, cloudDecoded.schemaVersion)
        XCTAssertEqual(parse.tags, cloudDecoded.tags)
        XCTAssertEqual(parse.groupIdentifier, cloudDecoded.groupIdentifier)
        XCTAssertEqual(parse.asset, cloudDecoded.asset)
        XCTAssertEqual(parse.notes, cloudDecoded.notes)

        // Special
        XCTAssertEqual(parse.name, cloudDecoded.name)
        XCTAssertEqual(parse.sex, cloudDecoded.sex)
        XCTAssertNotNil(cloudDecoded.birthday)
        XCTAssertEqual(parse.allergies, cloudDecoded.allergies)

        // Versionable
        XCTAssertNotNil(cloudDecoded.effectiveDate)
        XCTAssertEqual(parse.previousVersionUUIDs, cloudDecoded.previousVersionUUIDs)
        XCTAssertEqual(parse.nextVersionUUIDs, cloudDecoded.nextVersionUUIDs)
    }

    // swiftlint:disable:next function_body_length
    func testOutcome() throws {
        var careKit = OCKOutcome(taskUUID: UUID(), taskOccurrenceIndex: 0, values: [.init(10)])
        let careKitNote = OCKNote(author: "myId", title: "hello", content: "world")

        // Objectable
        careKit.uuid = UUID()
        careKit.createdDate = Date().addingTimeInterval(-200)
        careKit.updatedDate = Date().addingTimeInterval(-99)
        careKit.deletedDate = Date().addingTimeInterval(-1)
        careKit.schemaVersion = .init(majorVersion: 4)
        careKit.remoteID = "we"
        careKit.groupIdentifier = "mine"
        careKit.tags = ["one", "two"]
        careKit.source = "yo"
        careKit.userInfo = ["String": "String"]
        careKit.asset = "pic"
        careKit.notes = [careKitNote]
        careKit.timezone = .current

        // Versionable
        careKit.previousVersionUUIDs = [UUID()]
        careKit.nextVersionUUIDs = [UUID()]
        careKit.effectiveDate = Date().addingTimeInterval(-199)

        // Test CareKit -> Parse
        var parse = try Outcome.copyCareKit(careKit)

        // Special
        XCTAssertEqual(parse.taskUUID, careKit.taskUUID)
        XCTAssertEqual(parse.taskOccurrenceIndex, careKit.taskOccurrenceIndex)
        XCTAssertEqual(parse.values?.count, 1)
        XCTAssertEqual(careKit.values.count, 1)
        guard let value = parse.values?.first?.value as? Int,
              let careKitValue = careKit.values.first?.value as? Int else {
            XCTFail("Should have casted")
            return
        }
        XCTAssertEqual(value, careKitValue)

        // Objectable
        XCTAssertEqual(parse.className, "Outcome")
        XCTAssertEqual(parse.uuid, careKit.uuid)
        XCTAssertEqual(parse.entityId, careKit.id)
        XCTAssertNotNil(parse.createdDate)
        XCTAssertNotNil(parse.updatedDate)
        XCTAssertEqual(parse.timezone, careKit.timezone)
        XCTAssertEqual(parse.userInfo, careKit.userInfo)
        XCTAssertEqual(parse.remoteID, careKit.remoteID)
        XCTAssertEqual(parse.source, careKit.source)
        XCTAssertEqual(parse.schemaVersion, careKit.schemaVersion)
        XCTAssertEqual(parse.tags, careKit.tags)
        XCTAssertEqual(parse.groupIdentifier, careKit.groupIdentifier)
        XCTAssertEqual(parse.asset, careKit.asset)
        XCTAssertEqual(parse.notes?.count, 1)
        XCTAssertEqual(parse.notes?.first?.author, "myId")
        XCTAssertEqual(parse.notes?.first?.title, "hello")
        XCTAssertEqual(parse.notes?.first?.content, "world")

        // Test Parse -> CareKit
        let parse2 = try parse.convertToCareKit()

        // Special
        XCTAssertEqual(parse2.taskUUID, careKit.taskUUID)
        XCTAssertEqual(parse2.taskOccurrenceIndex, careKit.taskOccurrenceIndex)
        XCTAssertEqual(parse2.values.count, 1)
        if let value2 = parse2.values.first?.value as? Int,
            let careKitValue = careKit.values.first?.value as? Int {
            XCTAssertEqual(value2, careKitValue)
        } else {
            XCTFail("Should have casted")
        }

        // Objectable
        XCTAssertEqual(parse2.uuid, careKit.uuid)
        XCTAssertNotNil(parse2.createdDate)
        XCTAssertNotNil(parse2.updatedDate)
        XCTAssertEqual(parse2.timezone, careKit.timezone)
        XCTAssertEqual(parse2.userInfo, careKit.userInfo)
        XCTAssertEqual(parse2.remoteID, careKit.remoteID)
        XCTAssertEqual(parse2.source, careKit.source)
        XCTAssertEqual(parse2.schemaVersion, careKit.schemaVersion)
        XCTAssertEqual(parse2.tags, careKit.tags)
        XCTAssertEqual(parse2.groupIdentifier, careKit.groupIdentifier)
        XCTAssertEqual(parse2.asset, careKit.asset)
        XCTAssertEqual(parse2.notes?.count, 1)
        XCTAssertEqual(parse2.notes?.first?.author, "myId")
        XCTAssertEqual(parse2.notes?.first?.title, "hello")
        XCTAssertEqual(parse2.notes?.first?.content, "world")

        // Versionable
        XCTAssertNotNil(parse2.effectiveDate)
        XCTAssertEqual(parse2.previousVersionUUIDs, careKit.previousVersionUUIDs)
        XCTAssertEqual(parse2.nextVersionUUIDs, careKit.nextVersionUUIDs)

        // Encode to cloud format
        guard let valueWithObjectId = parse.values?.first else {
            XCTFail("Should have unwrapped note")
            return
        }

        parse.values = [valueWithObjectId]
        guard let note = parse.notes?.first else {
            XCTFail("Should have unwrapped note")
            return
        }

        parse.notes = [note]
        let cloudEncoded = try ParseCoding.parseEncoder().encode(parse)
        let cloudDecoded = try ParseCoding.jsonDecoder().decode(Outcome.self, from: cloudEncoded)

        // Objectable
        XCTAssertEqual(parse.className, cloudDecoded.className)
        XCTAssertEqual(parse.uuid, cloudDecoded.uuid)
        XCTAssertEqual(parse.entityId, cloudDecoded.entityId)
        XCTAssertNotNil(cloudDecoded.createdDate)
        XCTAssertNotNil(cloudDecoded.updatedDate)
        XCTAssertEqual(parse.timezone, cloudDecoded.timezone)
        XCTAssertEqual(parse.userInfo, cloudDecoded.userInfo)
        XCTAssertEqual(parse.remoteID, cloudDecoded.remoteID)
        XCTAssertEqual(parse.source, cloudDecoded.source)
        XCTAssertEqual(parse.schemaVersion, cloudDecoded.schemaVersion)
        XCTAssertEqual(parse.tags, cloudDecoded.tags)
        XCTAssertEqual(parse.groupIdentifier, cloudDecoded.groupIdentifier)
        XCTAssertEqual(parse.asset, cloudDecoded.asset)
        XCTAssertEqual(parse.notes, cloudDecoded.notes)

        // Special
        XCTAssertEqual(parse.taskUUID, cloudDecoded.taskUUID)
        XCTAssertEqual(parse.taskOccurrenceIndex, cloudDecoded.taskOccurrenceIndex)
        XCTAssertEqual(parse.values, cloudDecoded.values)

        // Versionable
        XCTAssertNotNil(cloudDecoded.effectiveDate)
        XCTAssertEqual(parse.previousVersionUUIDs, cloudDecoded.previousVersionUUIDs)
        XCTAssertEqual(parse.nextVersionUUIDs, cloudDecoded.nextVersionUUIDs)
    }

    // swiftlint:disable:next function_body_length
    func testTask() throws {
        let careKitSchedule = OCKScheduleElement(start: Date(),
                                                 end: Date().addingTimeInterval(3000), interval: .init(day: 1))
        var careKit = OCKTask(id: "myId", title: "hello", carePlanUUID: UUID(),
                              schedule: .init(composing: [careKitSchedule]))
        let careKitNote = OCKNote(author: "myId", title: "hello", content: "world")

        // Special
        careKit.impactsAdherence = true
        careKit.instructions = "sneezing"
        careKit.carePlanUUID = UUID()

        // Objectable
        careKit.uuid = UUID()
        careKit.createdDate = Date().addingTimeInterval(-200)
        careKit.deletedDate = Date().addingTimeInterval(-100)
        careKit.updatedDate = Date().addingTimeInterval(-99)
        careKit.timezone = .current
        careKit.userInfo = ["String": "String"]
        careKit.remoteID = "we"
        careKit.groupIdentifier = "mine"
        careKit.tags = ["one", "two"]
        careKit.schemaVersion = .init(majorVersion: 4)
        careKit.source = "yo"
        careKit.asset = "pic"
        careKit.notes = [careKitNote]

        // Versionable
        careKit.previousVersionUUIDs = [UUID()]
        careKit.nextVersionUUIDs = [UUID()]
        careKit.effectiveDate = Date().addingTimeInterval(-199)

        // Test CareKit -> Parse
        var parse = try PCKTask.copyCareKit(careKit)

        // Special
        XCTAssertEqual(parse.impactsAdherence, careKit.impactsAdherence)
        XCTAssertEqual(parse.title, careKit.title)
        XCTAssertEqual(parse.carePlanUUID, careKit.carePlanUUID)
        // XCTAssertEqual(parse.allergies, careKit.allergies)

        // Objectable
        XCTAssertEqual(parse.className, "Task")
        XCTAssertEqual(parse.entityId, careKit.id)
        XCTAssertEqual(parse.uuid, careKit.uuid)
        XCTAssertNotNil(parse.createdDate)
        XCTAssertNotNil(parse.updatedDate)
        XCTAssertNotNil(parse.deletedDate)
        XCTAssertEqual(parse.timezone, careKit.timezone)
        XCTAssertEqual(parse.userInfo, careKit.userInfo)
        XCTAssertEqual(parse.remoteID, careKit.remoteID)
        XCTAssertEqual(parse.source, careKit.source)
        XCTAssertEqual(parse.asset, careKit.asset)
        XCTAssertEqual(parse.schemaVersion, careKit.schemaVersion)
        XCTAssertEqual(parse.groupIdentifier, careKit.groupIdentifier)
        XCTAssertEqual(parse.tags, careKit.tags)
        XCTAssertEqual(parse.notes?.count, 1)
        XCTAssertEqual(parse.notes?.first?.author, "myId")
        XCTAssertEqual(parse.notes?.first?.title, "hello")
        XCTAssertEqual(parse.notes?.first?.content, "world")

        // Versionable
        XCTAssertNotNil(parse.effectiveDate)
        XCTAssertEqual(parse.previousVersionUUIDs, careKit.previousVersionUUIDs)
        XCTAssertEqual(parse.nextVersionUUIDs, careKit.nextVersionUUIDs)

        // Test Parse -> CareKit
        let parse2 = try parse.convertToCareKit()

        // Special
        XCTAssertEqual(parse2.impactsAdherence, careKit.impactsAdherence)
        XCTAssertEqual(parse2.title, careKit.title)
        XCTAssertEqual(parse2.carePlanUUID, careKit.carePlanUUID)

        // Objectable
        XCTAssertEqual(parse2.id, careKit.id)
        XCTAssertEqual(parse2.uuid, careKit.uuid)
        XCTAssertNotNil(parse2.createdDate)
        XCTAssertNotNil(parse2.updatedDate)
        XCTAssertNotNil(parse2.deletedDate)
        XCTAssertEqual(parse2.timezone, careKit.timezone)
        XCTAssertEqual(parse2.userInfo, careKit.userInfo)
        XCTAssertEqual(parse2.remoteID, careKit.remoteID)
        XCTAssertEqual(parse2.source, careKit.source)
        XCTAssertEqual(parse2.asset, careKit.asset)
        XCTAssertEqual(parse2.schemaVersion, careKit.schemaVersion)
        XCTAssertEqual(parse2.groupIdentifier, careKit.groupIdentifier)
        XCTAssertEqual(parse2.tags, careKit.tags)
        XCTAssertEqual(parse2.notes?.count, 1)
        XCTAssertEqual(parse2.notes?.first?.author, "myId")
        XCTAssertEqual(parse2.notes?.first?.title, "hello")
        XCTAssertEqual(parse2.notes?.first?.content, "world")

        // Versionable
        XCTAssertNotNil(parse2.effectiveDate)
        XCTAssertEqual(parse2.previousVersionUUIDs, careKit.previousVersionUUIDs)
        XCTAssertEqual(parse2.nextVersionUUIDs, careKit.nextVersionUUIDs)

        // Encode to cloud format
        guard let note = parse.notes?.first else {
            XCTFail("Should have unwrapped note")
            return
        }
        parse.notes = [note]
        let cloudEncoded = try ParseCoding.parseEncoder().encode(parse)
        let cloudDecoded = try ParseCoding.jsonDecoder().decode(PCKTask.self, from: cloudEncoded)

        // Objectable
        XCTAssertEqual(parse.className, cloudDecoded.className)
        XCTAssertEqual(parse.uuid, cloudDecoded.uuid)
        XCTAssertEqual(parse.entityId, cloudDecoded.entityId)
        XCTAssertNotNil(cloudDecoded.createdDate)
        XCTAssertNotNil(cloudDecoded.updatedDate)
        XCTAssertEqual(parse.timezone, cloudDecoded.timezone)
        XCTAssertEqual(parse.userInfo, cloudDecoded.userInfo)
        XCTAssertEqual(parse.remoteID, cloudDecoded.remoteID)
        XCTAssertEqual(parse.source, cloudDecoded.source)
        XCTAssertEqual(parse.schemaVersion, cloudDecoded.schemaVersion)
        XCTAssertEqual(parse.tags, cloudDecoded.tags)
        XCTAssertEqual(parse.groupIdentifier, cloudDecoded.groupIdentifier)
        XCTAssertEqual(parse.asset, cloudDecoded.asset)
        XCTAssertEqual(parse.notes, cloudDecoded.notes)

        // Special
        XCTAssertEqual(parse.impactsAdherence, cloudDecoded.impactsAdherence)
        XCTAssertEqual(parse.title, cloudDecoded.title)
        XCTAssertEqual(parse.carePlanUUID, cloudDecoded.carePlanUUID)

        // Versionable
        XCTAssertNotNil(cloudDecoded.effectiveDate)
        XCTAssertEqual(parse.previousVersionUUIDs, cloudDecoded.previousVersionUUIDs)
        XCTAssertEqual(parse.nextVersionUUIDs, cloudDecoded.nextVersionUUIDs)
    }

    // swiftlint:disable:next function_body_length
    func testHealthKitTask() throws {
        let careKitSchedule = OCKScheduleElement(start: Date(),
                                                 end: Date().addingTimeInterval(3000), interval: .init(day: 1))
        var careKit = OCKHealthKitTask(id: "myId", title: "hello", carePlanUUID: UUID(),
                                       schedule: .init(composing: [careKitSchedule]),
                                       healthKitLinkage: .init(quantityIdentifier: .bodyTemperature,
                                                               quantityType: .discrete,
                                                               unit: .degreeCelsius()))
        let careKitNote = OCKNote(author: "myId", title: "hello", content: "world")

        // Special
        careKit.impactsAdherence = true
        careKit.instructions = "sneezing"
        careKit.carePlanUUID = UUID()

        // Objectable
        careKit.uuid = UUID()
        careKit.createdDate = Date().addingTimeInterval(-200)
        careKit.deletedDate = Date().addingTimeInterval(-100)
        careKit.updatedDate = Date().addingTimeInterval(-99)
        careKit.timezone = .current
        careKit.userInfo = ["String": "String"]
        careKit.remoteID = "we"
        careKit.groupIdentifier = "mine"
        careKit.tags = ["one", "two"]
        careKit.schemaVersion = .init(majorVersion: 4)
        careKit.source = "yo"
        careKit.asset = "pic"
        careKit.notes = [careKitNote]

        // Versionable
        careKit.previousVersionUUIDs = [UUID()]
        careKit.nextVersionUUIDs = [UUID()]
        careKit.effectiveDate = Date().addingTimeInterval(-199)

        // Test CareKit -> Parse
        var parse = try HealthKitTask.copyCareKit(careKit)

        // Special
        XCTAssertEqual(parse.impactsAdherence, careKit.impactsAdherence)
        XCTAssertEqual(parse.title, careKit.title)
        XCTAssertEqual(parse.carePlanUUID, careKit.carePlanUUID)
        // XCTAssertEqual(parse.allergies, careKit.allergies)

        // Objectable
        XCTAssertEqual(parse.className, "HealthKitTask")
        XCTAssertEqual(parse.entityId, careKit.id)
        XCTAssertEqual(parse.uuid, careKit.uuid)
        XCTAssertNotNil(parse.createdDate)
        XCTAssertNotNil(parse.updatedDate)
        XCTAssertNotNil(parse.deletedDate)
        XCTAssertEqual(parse.timezone, careKit.timezone)
        XCTAssertEqual(parse.userInfo, careKit.userInfo)
        XCTAssertEqual(parse.remoteID, careKit.remoteID)
        XCTAssertEqual(parse.source, careKit.source)
        XCTAssertEqual(parse.asset, careKit.asset)
        XCTAssertEqual(parse.schemaVersion, careKit.schemaVersion)
        XCTAssertEqual(parse.groupIdentifier, careKit.groupIdentifier)
        XCTAssertEqual(parse.tags, careKit.tags)
        XCTAssertEqual(parse.notes?.count, 1)
        XCTAssertEqual(parse.notes?.first?.author, "myId")
        XCTAssertEqual(parse.notes?.first?.title, "hello")
        XCTAssertEqual(parse.notes?.first?.content, "world")

        // Versionable
        XCTAssertNotNil(parse.effectiveDate)
        XCTAssertEqual(parse.previousVersionUUIDs, careKit.previousVersionUUIDs)
        XCTAssertEqual(parse.nextVersionUUIDs, careKit.nextVersionUUIDs)

        // Test Parse -> CareKit
        let parse2 = try parse.convertToCareKit()

        // Special
        XCTAssertEqual(parse2.impactsAdherence, careKit.impactsAdherence)
        XCTAssertEqual(parse2.title, careKit.title)
        XCTAssertEqual(parse2.carePlanUUID, careKit.carePlanUUID)

        // Objectable
        XCTAssertEqual(parse2.id, careKit.id)
        XCTAssertEqual(parse2.uuid, careKit.uuid)
        XCTAssertNotNil(parse2.createdDate)
        XCTAssertNotNil(parse2.updatedDate)
        XCTAssertNotNil(parse2.deletedDate)
        XCTAssertEqual(parse2.timezone, careKit.timezone)
        XCTAssertEqual(parse2.userInfo, careKit.userInfo)
        XCTAssertEqual(parse2.remoteID, careKit.remoteID)
        XCTAssertEqual(parse2.source, careKit.source)
        XCTAssertEqual(parse2.asset, careKit.asset)
        XCTAssertEqual(parse2.schemaVersion, careKit.schemaVersion)
        XCTAssertEqual(parse2.groupIdentifier, careKit.groupIdentifier)
        XCTAssertEqual(parse2.tags, careKit.tags)
        XCTAssertEqual(parse2.notes?.count, 1)
        XCTAssertEqual(parse2.notes?.first?.author, "myId")
        XCTAssertEqual(parse2.notes?.first?.title, "hello")
        XCTAssertEqual(parse2.notes?.first?.content, "world")

        // Versionable
        XCTAssertNotNil(parse2.effectiveDate)
        XCTAssertEqual(parse2.previousVersionUUIDs, careKit.previousVersionUUIDs)
        XCTAssertEqual(parse2.nextVersionUUIDs, careKit.nextVersionUUIDs)

        // Encode to cloud format
        guard let note = parse.notes?.first else {
            XCTFail("Should have unwrapped note")
            return
        }
        parse.notes = [note]
        let cloudEncoded = try ParseCoding.parseEncoder().encode(parse)
        let cloudDecoded = try ParseCoding.jsonDecoder().decode(HealthKitTask.self, from: cloudEncoded)

        // Objectable
        XCTAssertEqual(parse.className, cloudDecoded.className)
        XCTAssertEqual(parse.uuid, cloudDecoded.uuid)
        XCTAssertEqual(parse.entityId, cloudDecoded.entityId)
        XCTAssertNotNil(cloudDecoded.createdDate)
        XCTAssertNotNil(cloudDecoded.updatedDate)
        XCTAssertEqual(parse.timezone, cloudDecoded.timezone)
        XCTAssertEqual(parse.userInfo, cloudDecoded.userInfo)
        XCTAssertEqual(parse.remoteID, cloudDecoded.remoteID)
        XCTAssertEqual(parse.source, cloudDecoded.source)
        XCTAssertEqual(parse.schemaVersion, cloudDecoded.schemaVersion)
        XCTAssertEqual(parse.tags, cloudDecoded.tags)
        XCTAssertEqual(parse.groupIdentifier, cloudDecoded.groupIdentifier)
        XCTAssertEqual(parse.asset, cloudDecoded.asset)
        XCTAssertEqual(parse.notes, cloudDecoded.notes)

        // Special
        XCTAssertEqual(parse.impactsAdherence, cloudDecoded.impactsAdherence)
        XCTAssertEqual(parse.title, cloudDecoded.title)
        XCTAssertEqual(parse.carePlanUUID, cloudDecoded.carePlanUUID)

        // Versionable
        XCTAssertNotNil(cloudDecoded.effectiveDate)
        XCTAssertEqual(parse.previousVersionUUIDs, cloudDecoded.previousVersionUUIDs)
        XCTAssertEqual(parse.nextVersionUUIDs, cloudDecoded.nextVersionUUIDs)
    }

    // swiftlint:disable:next function_body_length
    func testCarePlan() throws {
        var careKit = OCKCarePlan(id: "myId", title: "hello", patientUUID: UUID())
        let careKitNote = OCKNote(author: "myId", title: "hello", content: "world")

        // Objectable
        careKit.uuid = UUID()
        careKit.createdDate = Date().addingTimeInterval(-200)
        careKit.deletedDate = Date().addingTimeInterval(-100)
        careKit.updatedDate = Date().addingTimeInterval(-99)
        careKit.timezone = .current
        careKit.userInfo = ["String": "String"]
        careKit.remoteID = "we"
        careKit.groupIdentifier = "mine"
        careKit.tags = ["one", "two"]
        careKit.schemaVersion = .init(majorVersion: 4)
        careKit.source = "yo"
        careKit.asset = "pic"
        careKit.notes = [careKitNote]

        // Versionable
        careKit.previousVersionUUIDs = [UUID()]
        careKit.nextVersionUUIDs = [UUID()]
        careKit.effectiveDate = Date().addingTimeInterval(-199)

        // Test CareKit -> Parse
        var parse = try CarePlan.copyCareKit(careKit)

        // Special
        XCTAssertEqual(parse.title, careKit.title)
        XCTAssertEqual(parse.patientUUID, careKit.patientUUID)

        // Objectable
        XCTAssertEqual(parse.className, "CarePlan")
        XCTAssertEqual(parse.entityId, careKit.id)
        XCTAssertEqual(parse.uuid, careKit.uuid)
        XCTAssertNotNil(parse.createdDate)
        XCTAssertNotNil(parse.updatedDate)
        XCTAssertNotNil(parse.deletedDate)
        XCTAssertEqual(parse.timezone, careKit.timezone)
        XCTAssertEqual(parse.userInfo, careKit.userInfo)
        XCTAssertEqual(parse.remoteID, careKit.remoteID)
        XCTAssertEqual(parse.source, careKit.source)
        XCTAssertEqual(parse.asset, careKit.asset)
        XCTAssertEqual(parse.schemaVersion, careKit.schemaVersion)
        XCTAssertEqual(parse.groupIdentifier, careKit.groupIdentifier)
        XCTAssertEqual(parse.tags, careKit.tags)
        XCTAssertEqual(parse.notes?.count, 1)
        XCTAssertEqual(parse.notes?.first?.author, "myId")
        XCTAssertEqual(parse.notes?.first?.title, "hello")
        XCTAssertEqual(parse.notes?.first?.content, "world")

        // Versionable
        XCTAssertNotNil(parse.effectiveDate)
        XCTAssertEqual(parse.previousVersionUUIDs, careKit.previousVersionUUIDs)
        XCTAssertEqual(parse.nextVersionUUIDs, careKit.nextVersionUUIDs)

        // Test Parse -> CareKit
        let parse2 = try parse.convertToCareKit()

        // Special
        XCTAssertEqual(parse2.title, careKit.title)
        XCTAssertEqual(parse2.patientUUID, careKit.patientUUID)

        // Objectable
        XCTAssertEqual(parse2.id, careKit.id)
        XCTAssertEqual(parse2.uuid, careKit.uuid)
        XCTAssertNotNil(parse2.createdDate)
        XCTAssertNotNil(parse2.updatedDate)
        XCTAssertNotNil(parse2.deletedDate)
        XCTAssertEqual(parse2.timezone, careKit.timezone)
        XCTAssertEqual(parse2.userInfo, careKit.userInfo)
        XCTAssertEqual(parse2.remoteID, careKit.remoteID)
        XCTAssertEqual(parse2.source, careKit.source)
        XCTAssertEqual(parse2.asset, careKit.asset)
        XCTAssertEqual(parse2.schemaVersion, careKit.schemaVersion)
        XCTAssertEqual(parse2.groupIdentifier, careKit.groupIdentifier)
        XCTAssertEqual(parse2.tags, careKit.tags)
        XCTAssertEqual(parse2.notes?.count, 1)
        XCTAssertEqual(parse2.notes?.first?.author, "myId")
        XCTAssertEqual(parse2.notes?.first?.title, "hello")
        XCTAssertEqual(parse2.notes?.first?.content, "world")

        // Versionable
        XCTAssertNotNil(parse2.effectiveDate)
        XCTAssertEqual(parse2.previousVersionUUIDs, careKit.previousVersionUUIDs)
        XCTAssertEqual(parse2.nextVersionUUIDs, careKit.nextVersionUUIDs)

        // Encode to cloud format
        guard let note = parse.notes?.first else {
            XCTFail("Should have unwrapped note")
            return
        }
        parse.notes = [note]
        let cloudEncoded = try ParseCoding.parseEncoder().encode(parse)
        let cloudDecoded = try ParseCoding.jsonDecoder().decode(CarePlan.self, from: cloudEncoded)

        // Objectable
        XCTAssertEqual(parse.className, cloudDecoded.className)
        XCTAssertEqual(parse.uuid, cloudDecoded.uuid)
        XCTAssertEqual(parse.entityId, cloudDecoded.entityId)
        XCTAssertNotNil(cloudDecoded.createdDate)
        XCTAssertNotNil(cloudDecoded.updatedDate)
        XCTAssertEqual(parse.timezone, cloudDecoded.timezone)
        XCTAssertEqual(parse.userInfo, cloudDecoded.userInfo)
        XCTAssertEqual(parse.remoteID, cloudDecoded.remoteID)
        XCTAssertEqual(parse.source, cloudDecoded.source)
        XCTAssertEqual(parse.schemaVersion, cloudDecoded.schemaVersion)
        XCTAssertEqual(parse.tags, cloudDecoded.tags)
        XCTAssertEqual(parse.groupIdentifier, cloudDecoded.groupIdentifier)
        XCTAssertEqual(parse.asset, cloudDecoded.asset)
        XCTAssertEqual(parse.notes, cloudDecoded.notes)

        // Special
        XCTAssertEqual(parse.title, cloudDecoded.title)
        XCTAssertEqual(parse.patientUUID, cloudDecoded.patientUUID)

        // Versionable
        XCTAssertNotNil(cloudDecoded.effectiveDate)
        XCTAssertEqual(parse.previousVersionUUIDs, cloudDecoded.previousVersionUUIDs)
        XCTAssertEqual(parse.nextVersionUUIDs, cloudDecoded.nextVersionUUIDs)
    }

    // swiftlint:disable:next function_body_length
    func testContact() throws {
        var careKit = OCKContact(id: "myId", givenName: "hello", familyName: "world", carePlanUUID: UUID())
        let careKitNote = OCKNote(author: "myId", title: "hello", content: "world")

        // Special
        let address = OCKPostalAddress()
        address.state = "KY"
        careKit.address = address
        careKit.category = .careProvider
        careKit.organization = "yo"
        careKit.role = "nope"
        careKit.title = "wep"
        careKit.messagingNumbers = [.init(label: "home", value: "555-4325")]
        careKit.emailAddresses = [.init(label: "mine", value: "netrecon@uky.edu")]
        careKit.phoneNumbers = [.init(label: "wer", value: "232-45")]
        careKit.otherContactInfo = [.init(label: "qp", value: "rest")]

        // Objectable
        careKit.uuid = UUID()
        careKit.createdDate = Date().addingTimeInterval(-200)
        careKit.deletedDate = Date().addingTimeInterval(-100)
        careKit.updatedDate = Date().addingTimeInterval(-99)
        careKit.timezone = .current
        careKit.userInfo = ["String": "String"]
        careKit.remoteID = "we"
        careKit.groupIdentifier = "mine"
        careKit.tags = ["one", "two"]
        careKit.schemaVersion = .init(majorVersion: 4)
        careKit.source = "yo"
        careKit.asset = "pic"
        careKit.notes = [careKitNote]

        // Versionable
        careKit.previousVersionUUIDs = [UUID()]
        careKit.nextVersionUUIDs = [UUID()]
        careKit.effectiveDate = Date().addingTimeInterval(-199)

        // Test CareKit -> Parse
        var parse = try Contact.copyCareKit(careKit)

        // Special
        XCTAssertEqual(parse.title, careKit.title)
        XCTAssertEqual(parse.carePlanUUID, careKit.carePlanUUID)
        XCTAssertEqual(parse.address, careKit.address)
        XCTAssertEqual(parse.category, careKit.category)
        XCTAssertEqual(parse.role, careKit.role)
        XCTAssertEqual(parse.messagingNumbers, careKit.messagingNumbers)
        XCTAssertEqual(parse.emailAddresses, careKit.emailAddresses)
        XCTAssertEqual(parse.phoneNumbers, careKit.phoneNumbers)
        XCTAssertEqual(parse.otherContactInfo, careKit.otherContactInfo)

        // Objectable
        XCTAssertEqual(parse.className, "Contact")
        XCTAssertEqual(parse.entityId, careKit.id)
        XCTAssertEqual(parse.uuid, careKit.uuid)
        XCTAssertNotNil(parse.createdDate)
        XCTAssertNotNil(parse.updatedDate)
        XCTAssertNotNil(parse.deletedDate)
        XCTAssertEqual(parse.timezone, careKit.timezone)
        XCTAssertEqual(parse.userInfo, careKit.userInfo)
        XCTAssertEqual(parse.remoteID, careKit.remoteID)
        XCTAssertEqual(parse.source, careKit.source)
        XCTAssertEqual(parse.asset, careKit.asset)
        XCTAssertEqual(parse.schemaVersion, careKit.schemaVersion)
        XCTAssertEqual(parse.groupIdentifier, careKit.groupIdentifier)
        XCTAssertEqual(parse.tags, careKit.tags)
        XCTAssertEqual(parse.notes?.count, 1)
        XCTAssertEqual(parse.notes?.first?.author, "myId")
        XCTAssertEqual(parse.notes?.first?.title, "hello")
        XCTAssertEqual(parse.notes?.first?.content, "world")

        // Versionable
        XCTAssertNotNil(parse.effectiveDate)
        XCTAssertEqual(parse.previousVersionUUIDs, careKit.previousVersionUUIDs)
        XCTAssertEqual(parse.nextVersionUUIDs, careKit.nextVersionUUIDs)

        // Test Parse -> CareKit
        let parse2 = try parse.convertToCareKit()

        // Special
        XCTAssertEqual(parse2.title, careKit.title)
        XCTAssertEqual(parse2.carePlanUUID, careKit.carePlanUUID)
        XCTAssertEqual(parse2.address, careKit.address)
        XCTAssertEqual(parse2.category, careKit.category)
        XCTAssertEqual(parse2.role, careKit.role)
        XCTAssertEqual(parse2.messagingNumbers, careKit.messagingNumbers)
        XCTAssertEqual(parse2.emailAddresses, careKit.emailAddresses)
        XCTAssertEqual(parse2.phoneNumbers, careKit.phoneNumbers)
        XCTAssertEqual(parse2.otherContactInfo, careKit.otherContactInfo)

        // Objectable
        XCTAssertEqual(parse2.id, careKit.id)
        XCTAssertEqual(parse2.uuid, careKit.uuid)
        XCTAssertNotNil(parse2.createdDate)
        XCTAssertNotNil(parse2.updatedDate)
        XCTAssertNotNil(parse2.deletedDate)
        XCTAssertEqual(parse2.timezone, careKit.timezone)
        XCTAssertEqual(parse2.userInfo, careKit.userInfo)
        XCTAssertEqual(parse2.remoteID, careKit.remoteID)
        XCTAssertEqual(parse2.source, careKit.source)
        XCTAssertEqual(parse2.asset, careKit.asset)
        XCTAssertEqual(parse2.schemaVersion, careKit.schemaVersion)
        XCTAssertEqual(parse2.groupIdentifier, careKit.groupIdentifier)
        XCTAssertEqual(parse2.tags, careKit.tags)
        XCTAssertEqual(parse2.notes?.count, 1)
        XCTAssertEqual(parse2.notes?.first?.author, "myId")
        XCTAssertEqual(parse2.notes?.first?.title, "hello")
        XCTAssertEqual(parse2.notes?.first?.content, "world")

        // Versionable
        XCTAssertNotNil(parse2.effectiveDate)
        XCTAssertEqual(parse2.previousVersionUUIDs, careKit.previousVersionUUIDs)
        XCTAssertEqual(parse2.nextVersionUUIDs, careKit.nextVersionUUIDs)

        // Encode to cloud format
        guard let note = parse.notes?.first else {
            XCTFail("Should have unwrapped note")
            return
        }
        parse.notes = [note]
        let cloudEncoded = try ParseCoding.parseEncoder().encode(parse)
        let cloudDecoded = try ParseCoding.jsonDecoder().decode(Contact.self, from: cloudEncoded)

        // Objectable
        XCTAssertEqual(parse.className, cloudDecoded.className)
        XCTAssertEqual(parse.uuid, cloudDecoded.uuid)
        XCTAssertEqual(parse.entityId, cloudDecoded.entityId)
        XCTAssertNotNil(cloudDecoded.createdDate)
        XCTAssertNotNil(cloudDecoded.updatedDate)
        XCTAssertEqual(parse.timezone, cloudDecoded.timezone)
        XCTAssertEqual(parse.userInfo, cloudDecoded.userInfo)
        XCTAssertEqual(parse.remoteID, cloudDecoded.remoteID)
        XCTAssertEqual(parse.source, cloudDecoded.source)
        XCTAssertEqual(parse.schemaVersion, cloudDecoded.schemaVersion)
        XCTAssertEqual(parse.tags, cloudDecoded.tags)
        XCTAssertEqual(parse.groupIdentifier, cloudDecoded.groupIdentifier)
        XCTAssertEqual(parse.asset, cloudDecoded.asset)
        XCTAssertEqual(parse.notes, cloudDecoded.notes)

        // Special
        XCTAssertEqual(parse.title, cloudDecoded.title)
        XCTAssertEqual(parse.carePlanUUID, cloudDecoded.carePlanUUID)
        XCTAssertEqual(parse.address, cloudDecoded.address)
        XCTAssertEqual(parse.category, cloudDecoded.category)
        XCTAssertEqual(parse.role, cloudDecoded.role)
        XCTAssertEqual(parse.messagingNumbers, cloudDecoded.messagingNumbers)
        XCTAssertEqual(parse.emailAddresses, cloudDecoded.emailAddresses)
        XCTAssertEqual(parse.phoneNumbers, cloudDecoded.phoneNumbers)
        XCTAssertEqual(parse.otherContactInfo, cloudDecoded.otherContactInfo)

        // Versionable
        XCTAssertNotNil(cloudDecoded.effectiveDate)
        XCTAssertEqual(parse.previousVersionUUIDs, cloudDecoded.previousVersionUUIDs)
        XCTAssertEqual(parse.nextVersionUUIDs, cloudDecoded.nextVersionUUIDs)
    }
/*
    func testAddContact() throws {
        let contact = OCKContact(id: "test", givenName: "hello", familyName: "world", carePlanUUID: nil)
        var savedContact = try store.addContactAndWait(contact)
        //savedContact.title = "me"
        //parse.automaticallySynchronizes = true
        try self.store.updateContactAndWait(savedContact)
        /*
        let revision = store.computeRevision(since: 0)
        XCTAssert(revision.entities.count == 1)
        XCTAssert(revision.entities.first?.entityType == .contact)*/
        let expectation = XCTestExpectation(description: "Synch")
        self.store.synchronize{ error in
            if let error = error {
                XCTFail("\(error.localizedDescription)")
            }
            savedContact.title = "me"
            do {
                let updatedContact = try self.store.updateContactAndWait(savedContact)
                let revision2 = self.store.computeRevision(since: 1)
                XCTAssert(updatedContact.name.familyName == "me")
                XCTAssert(revision2.entities.count == 1)
                XCTAssert(revision2.entities.first?.entityType == .contact)
            } catch {
                XCTFail(error.localizedDescription)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 50.0)
    }*/
}

extension ParseCareKitTests: ParseRemoteDelegate {
    func didRequestSynchronization(_ remote: OCKRemoteSynchronizable) {
        print("Implement")
    }

    func remote(_ remote: OCKRemoteSynchronizable, didUpdateProgress progress: Double) {
        print("Implement")
    }

    func successfullyPushedDataToCloud() {
        print("Implement")
    }

    func chooseConflictResolution(conflicts: [OCKEntity], completion: @escaping OCKResultClosure<OCKEntity>) {
        if let first = conflicts.first {
            completion(.success(first))
        } else {
            completion(.failure(.remoteSynchronizationFailed(reason: "Error, non selected for conflict")))
        }
    }
} // swiftlint:disable:this file_length
