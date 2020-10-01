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
    var objectId: String?
    var createdAt: Date?
    var sessionToken: String
    var updatedAt: Date?
    var ACL: ParseACL?

    // provided by User
    var username: String?
    var email: String?
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
            let encoded = try loginResponse.getEncoder(skipKeys: false).encode(loginResponse)
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

class ParseCareKitTests: XCTestCase {

    override func setUpWithError() throws {
        guard let url = URL(string: "http://localhost:1337/1") else {
                    XCTFail("Should create valid URL")
                    return
                }
                ParseSwift.initialize(applicationId: "applicationId",
                                      clientKey: "clientKey",
                                      masterKey: "masterKey",
                                      serverURL: url)
        userLogin()
    }

    override func tearDownWithError() throws {
        MockURLProtocol.removeAll()
        try? KeychainStore.shared.deleteAll()
        try? ParseStorage.shared.deleteAll()
    }
    
    func testNote() throws {
        var careKit = OCKNote(author: "myId", title: "hello", content: "world")

        //Objectable
        careKit.uuid = UUID()
        careKit.createdDate = Date().addingTimeInterval(-200)
        careKit.updatedDate = Date().addingTimeInterval(-99)
        careKit.timezone = .current
        careKit.userInfo = ["String": "String"]
        careKit.remoteID = "we"
        careKit.groupIdentifier = "mine"
        careKit.tags = ["one", "two"]
        careKit.schemaVersion = .init(majorVersion: 4)
        careKit.source = "yo"
        careKit.asset = "pic"
        careKit.notes = [careKit]
        
        do {
            //Test CareKit -> Parse
            let parse = try Note.copyCareKit(careKit)

            //Special
            XCTAssertEqual(parse.content, careKit.content)
            XCTAssertEqual(parse.title, careKit.title)
            XCTAssertEqual(parse.author, careKit.author)
            
            //Objectable
            XCTAssertEqual(parse.className, "Note")
            XCTAssertEqual(parse.uuid, careKit.uuid)
            XCTAssertEqual(parse.createdDate, careKit.createdDate)
            XCTAssertEqual(parse.updatedDate, careKit.updatedDate)
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
            
            //Test Parse -> CareKit
            let parse2 = try parse.convertToCareKit()
            
            //Special
            XCTAssertEqual(parse2.content, careKit.content)
            XCTAssertEqual(parse2.title, careKit.title)
            XCTAssertEqual(parse2.author, careKit.author)
            
            //Objectable
            XCTAssertEqual(parse2.uuid, careKit.uuid)
            XCTAssertEqual(parse2.createdDate, careKit.createdDate)
            XCTAssertEqual(parse2.updatedDate, careKit.updatedDate)
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
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testPatient() throws {
        var careKit = OCKPatient(id: "myId", givenName: "hello", familyName: "world")
        let careKitNote = OCKNote(author: "myId", title: "hello", content: "world")
        //Special
        careKit.birthday = Date().addingTimeInterval(-300)
        careKit.allergies = ["sneezing"]
        careKit.sex = .female

        //Objectable
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
        
        //Versionable
        careKit.previousVersionUUID = UUID()
        careKit.nextVersionUUID = UUID()
        careKit.effectiveDate = Date().addingTimeInterval(-199)
        
        do {
            //Test CareKit -> Parse
            let parse = try Patient.copyCareKit(careKit)
    /*
            let encoded = try JSONEncoder().encode(careKit)
            let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: encoded)
            print(decoded)
    */
            //Special
            XCTAssertEqual(parse.name, careKit.name)
            XCTAssertEqual(parse.sex, careKit.sex)
            XCTAssertEqual(parse.birthday, careKit.birthday)
            XCTAssertEqual(parse.allergies, careKit.allergies)
            
            //Objectable
            XCTAssertEqual(parse.className, "Patient")
            XCTAssertEqual(parse.entityId, careKit.id)
            XCTAssertEqual(parse.uuid, careKit.uuid)
            XCTAssertEqual(parse.createdDate, careKit.createdDate)
            XCTAssertEqual(parse.updatedDate, careKit.updatedDate)
            XCTAssertEqual(parse.deletedDate, careKit.deletedDate)
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
            
            //Versionable
            XCTAssertEqual(parse.effectiveDate, careKit.effectiveDate)
            XCTAssertEqual(parse.previousVersionUUID, careKit.previousVersionUUID)
            XCTAssertEqual(parse.nextVersionUUID, careKit.nextVersionUUID)
            
            //Test Parse -> CareKit
            let parse2 = try parse.convertToCareKit()

            //Special
            XCTAssertEqual(parse2.name, careKit.name)
            XCTAssertEqual(parse2.sex, careKit.sex)
            XCTAssertEqual(parse2.birthday, careKit.birthday)
            XCTAssertEqual(parse2.allergies, careKit.allergies)
            
            //Objectable
            XCTAssertEqual(parse2.id, careKit.id)
            XCTAssertEqual(parse2.uuid, careKit.uuid)
            XCTAssertEqual(parse2.createdDate, careKit.createdDate)
            XCTAssertEqual(parse2.updatedDate, careKit.updatedDate)
            XCTAssertEqual(parse2.deletedDate, careKit.deletedDate)
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
            
            //Versionable
            XCTAssertEqual(parse2.effectiveDate, careKit.effectiveDate)
            XCTAssertEqual(parse2.previousVersionUUID, careKit.previousVersionUUID)
            XCTAssertEqual(parse2.nextVersionUUID, careKit.nextVersionUUID)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testOutcomeValue() throws {
        var careKit = OCKOutcomeValue(10)
        let careKitNote = OCKNote(author: "myId", title: "hello", content: "world")
        //Special
        careKit.index = 0
        //careKit.kind = "whale"
        careKit.units = "m/s"
        
        //Objectable
        careKit.uuid = UUID()
        careKit.createdDate = Date().addingTimeInterval(-200)
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
        
        do {
            //Test CareKit -> Parse
            let parse = try OutcomeValue.copyCareKit(careKit)

            //Special
            XCTAssertEqual(parse.index, careKit.index)
            XCTAssertEqual(parse.kind, careKit.kind)
            XCTAssertEqual(parse.units, careKit.units)
            guard let value = parse.value?.value as? Int,
                  let careKitValue = careKit.value as? Int else {
                XCTFail("Should have casted")
                return
            }
            XCTAssertEqual(value, careKitValue)
            
            //Objectable
            XCTAssertEqual(parse.className, "OutcomeValue")
            XCTAssertEqual(parse.uuid, careKit.uuid)
            XCTAssertEqual(parse.createdDate, careKit.createdDate)
            XCTAssertEqual(parse.updatedDate, careKit.updatedDate)
            XCTAssertEqual(parse.timezone, careKit.timezone)
            XCTAssertEqual(parse.userInfo, careKit.userInfo)
            XCTAssertEqual(parse.remoteID, careKit.remoteID)
            XCTAssertEqual(parse.source, careKit.source)
            XCTAssertEqual(parse.schemaVersion, careKit.schemaVersion)
            XCTAssertEqual(parse.tags, careKit.tags)
            XCTAssertEqual(parse.groupIdentifier, careKit.groupIdentifier)
            
            //This skips the encoding/decoding of below on purpose
            /*
            XCTAssertEqual(parse.asset, careKit.asset)
            XCTAssertEqual(parse.notes?.count, 1)
            XCTAssertEqual(parse.notes?.first?.author, "myId")
            XCTAssertEqual(parse.notes?.first?.title, "hello")
            XCTAssertEqual(parse.notes?.first?.content, "world")*/
            
            //Test Parse -> CareKit
            let parse2 = try parse.convertToCareKit()
            //Special
            XCTAssertEqual(parse2.index, careKit.index)
            XCTAssertEqual(parse2.kind, careKit.kind)
            XCTAssertEqual(parse2.units, careKit.units)
            guard let value2 = parse2.value as? Int,
                  let careKitValue2 = careKit.value as? Int else {
                XCTFail("Should have casted")
                return
            }
            XCTAssertEqual(value2, careKitValue2)
            
            //Objectable
            XCTAssertEqual(parse2.uuid, careKit.uuid)
            XCTAssertEqual(parse2.createdDate, careKit.createdDate)
            XCTAssertEqual(parse2.updatedDate, careKit.updatedDate)
            XCTAssertEqual(parse2.timezone, careKit.timezone)
            XCTAssertEqual(parse2.userInfo, careKit.userInfo)
            XCTAssertEqual(parse2.remoteID, careKit.remoteID)
            XCTAssertEqual(parse2.source, careKit.source)
            XCTAssertEqual(parse2.schemaVersion, careKit.schemaVersion)
            XCTAssertEqual(parse2.tags, careKit.tags)
            XCTAssertEqual(parse.groupIdentifier, careKit.groupIdentifier)
            
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testOutcome() throws {
        var careKit = OCKOutcome(taskUUID: UUID(), taskOccurrenceIndex: 0, values: [.init(10)])
        let careKitNote = OCKNote(author: "myId", title: "hello", content: "world")
        
        //Special
        //let test = careKit.
        
        //Objectable
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
        
        do {
            //Test CareKit -> Parse
            let parse = try Outcome.copyCareKit(careKit)

            //Special
            XCTAssertEqual(parse.taskUUID, careKit.taskUUID)
            XCTAssertEqual(parse.taskOccurrenceIndex, careKit.taskOccurrenceIndex)
            XCTAssertEqual(parse.values?.count, 1)
            XCTAssertEqual(careKit.values.count, 1)
            guard let value = parse.values?.first?.value?.value as? Int,
                  let careKitValue = careKit.values.first?.value as? Int else {
                XCTFail("Should have casted")
                return
            }
            XCTAssertEqual(value, careKitValue)
            
            //Objectable
            XCTAssertEqual(parse.className, "Outcome")
            XCTAssertEqual(parse.uuid, careKit.uuid)
            XCTAssertEqual(parse.entityId, careKit.id)
            XCTAssertEqual(parse.createdDate, careKit.createdDate)
            XCTAssertEqual(parse.updatedDate, careKit.updatedDate)
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
            
            //Test Parse -> CareKit
            let parse2 = try parse.convertToCareKit()
            
            //Special
            XCTAssertEqual(parse2.taskUUID, careKit.taskUUID)
            XCTAssertEqual(parse2.taskOccurrenceIndex, careKit.taskOccurrenceIndex)
            XCTAssertEqual(parse2.values.count, 1)
            XCTAssertEqual(careKit.values.count, 1)
            guard let value2 = parse2.values.first?.value as? Int,
                  let careKitValue2 = careKit.values.first?.value as? Int else {
                XCTFail("Should have casted")
                return
            }
            XCTAssertEqual(value2, careKitValue2)
            
            //Objectable
            XCTAssertEqual(parse2.uuid, careKit.uuid)
            XCTAssertEqual(parse2.createdDate, careKit.createdDate)
            XCTAssertEqual(parse2.updatedDate, careKit.updatedDate)
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
            
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testScheduleElement() throws {
        var careKit = OCKScheduleElement(start: Date(), end: Date().addingTimeInterval(3000), interval: .init(day: 1))

        //Objectable
        careKit.targetValues = .init()
        careKit.text = "we"
        careKit.duration = .allDay
        
        do {
            //Test CareKit -> Parse
            let parse = try ScheduleElement.copyCareKit(careKit)

            //Special
            XCTAssertEqual(parse.text, careKit.text)
            XCTAssertEqual(parse.duration, careKit.duration)
            XCTAssertEqual(parse.start, careKit.start)
            XCTAssertEqual(parse.interval, careKit.interval)
            XCTAssertEqual(parse.end, careKit.end)
            /*XCTAssertEqual(parse.targetValues?.count, 1)
            XCTAssertEqual(parse.targetValues?.count, 1)
            guard let value = parse.targetValues?.first?.value?.value as? Int,
                  let careKitValue = careKit.targetValues.first?.value as? Int else {
                XCTFail("Should have casted")
                return
            }
            XCTAssertEqual(value, careKitValue)*/
            
            //Objectable
            XCTAssertEqual(parse.className, "ScheduleElement")
            
            //Test Parse -> CareKit
            let parse2 = try parse.convertToCareKit()
            
            XCTAssertEqual(parse2.text, careKit.text)
            XCTAssertEqual(parse2.duration, careKit.duration)
            XCTAssertEqual(parse2.start, careKit.start)
            XCTAssertEqual(parse2.interval, careKit.interval)
            XCTAssertEqual(parse2.end, careKit.end)
            /*XCTAssertEqual(parse.targetValues?.count, 1)
            XCTAssertEqual(parse.targetValues?.count, 1)
            guard let value = parse.targetValues?.first?.value?.value as? Int,
                  let careKitValue = careKit.targetValues.first?.value as? Int else {
                XCTFail("Should have casted")
                return
            }
            XCTAssertEqual(value, careKitValue)*/
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testTask() throws {
        var careKit = OCKPatient(id: "myId", givenName: "hello", familyName: "world")
        let careKitNote = OCKNote(author: "myId", title: "hello", content: "world")
        //Special
        careKit.birthday = Date().addingTimeInterval(-300)
        careKit.allergies = ["sneezing"]
        careKit.sex = .female

        //Objectable
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
        
        //Versionable
        careKit.previousVersionUUID = UUID()
        careKit.nextVersionUUID = UUID()
        careKit.effectiveDate = Date().addingTimeInterval(-199)
        
        do {
            //Test CareKit -> Parse
            let parse = try Patient.copyCareKit(careKit)
    /*
            let encoded = try JSONEncoder().encode(careKit)
            let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: encoded)
            print(decoded)
    */
            //Special
            XCTAssertEqual(parse.name, careKit.name)
            XCTAssertEqual(parse.sex, careKit.sex)
            XCTAssertEqual(parse.birthday, careKit.birthday)
            XCTAssertEqual(parse.allergies, careKit.allergies)
            
            //Objectable
            XCTAssertEqual(parse.className, "Patient")
            XCTAssertEqual(parse.entityId, careKit.id)
            XCTAssertEqual(parse.uuid, careKit.uuid)
            XCTAssertEqual(parse.createdDate, careKit.createdDate)
            XCTAssertEqual(parse.updatedDate, careKit.updatedDate)
            XCTAssertEqual(parse.deletedDate, careKit.deletedDate)
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
            
            //Versionable
            XCTAssertEqual(parse.effectiveDate, careKit.effectiveDate)
            XCTAssertEqual(parse.previousVersionUUID, careKit.previousVersionUUID)
            XCTAssertEqual(parse.nextVersionUUID, careKit.nextVersionUUID)
            
            //Test Parse -> CareKit
            let parse2 = try parse.convertToCareKit()

            //Special
            XCTAssertEqual(parse2.name, careKit.name)
            XCTAssertEqual(parse2.sex, careKit.sex)
            XCTAssertEqual(parse2.birthday, careKit.birthday)
            XCTAssertEqual(parse2.allergies, careKit.allergies)
            
            //Objectable
            XCTAssertEqual(parse2.id, careKit.id)
            XCTAssertEqual(parse2.uuid, careKit.uuid)
            XCTAssertEqual(parse2.createdDate, careKit.createdDate)
            XCTAssertEqual(parse2.updatedDate, careKit.updatedDate)
            XCTAssertEqual(parse2.deletedDate, careKit.deletedDate)
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
            
            //Versionable
            XCTAssertEqual(parse2.effectiveDate, careKit.effectiveDate)
            XCTAssertEqual(parse2.previousVersionUUID, careKit.previousVersionUUID)
            XCTAssertEqual(parse2.nextVersionUUID, careKit.nextVersionUUID)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}
