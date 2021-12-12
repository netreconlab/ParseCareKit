//
//  Clock.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/9/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore
import os.log

struct PCKClock: ParseObjectMutable {

    static var className: String {
        "Clock"
    }

    var objectId: String?

    var createdAt: Date?

    var updatedAt: Date?

    var ACL: ParseACL?

    var uuid: UUID?

    var vector: String?

    func decodeClock(completion:@escaping(OCKRevisionRecord.KnowledgeVector?) -> Void) {
        guard let data = self.vector?.data(using: .utf8) else {
            if #available(iOS 14.0, watchOS 7.0, *) {
                Logger.clock.error("Error in Clock. Couldn't get data as utf8")
            } else {
                os_log("Error in Clock. Couldn't get data as utf8", log: .clock, type: .error)
            }
            return
        }

        let cloudVector: OCKRevisionRecord.KnowledgeVector?
        do {
            cloudVector = try JSONDecoder().decode(OCKRevisionRecord.KnowledgeVector.self, from: data)
        } catch {
            if #available(iOS 14.0, watchOS 7.0, *) {
                // swiftlint:disable:next line_length
                Logger.clock.error("Clock.decodeClock(): \(error.localizedDescription, privacy: .private). Vector \(data, privacy: .private).")
            } else {
                os_log("Clock.decodeClock(): %{private}@. Vector %{private}@.",
                       log: .clock, type: .error, error.localizedDescription, data.debugDescription)
            }
            cloudVector = nil
        }
        completion(cloudVector)
    }

    func encodeClock(_ clock: OCKRevisionRecord.KnowledgeVector) -> Self? {
        do {
            let json = try JSONEncoder().encode(clock)
            guard let cloudVectorString = String(data: json, encoding: .utf8) else {
                return nil
            }
            var mutableClock = self
            mutableClock.vector = cloudVectorString
            return mutableClock
        } catch {
            if #available(iOS 14.0, watchOS 7.0, *) {
                Logger.clock.error("Clock.encodeClock(): \(error.localizedDescription, privacy: .private).")
            } else {
                os_log("Clock.decodeClock(): %{private}@.", log: .clock, type: .error, error.localizedDescription)
            }
            return nil
        }
    }

    static func fetchFromCloud(uuid: UUID, createNewIfNeeded: Bool,
                               completion:@escaping(PCKClock?,
                                                    OCKRevisionRecord.KnowledgeVector?,
                                                    ParseError?) -> Void) {

        // Fetch Clock from Cloud
        let query = Self.query(ClockKey.uuid == uuid)
        query.first(callbackQueue: ParseRemote.queue) { result in

            switch result {

            case .success(let foundVector):
                foundVector.decodeClock { possiblyDecoded in
                    completion(foundVector, possiblyDecoded, nil)
                }
            case .failure(let error):
                if !createNewIfNeeded {
                    completion(nil, nil, error)
                } else {
                    // This is the first time the Clock is user setup for this user
                    let newVector = PCKClock(uuid: uuid)
                    newVector.decodeClock { possiblyDecoded in
                        newVector.create(callbackQueue: ParseRemote.queue) { result in
                            switch result {
                            case .success(let savedVector):
                                completion(savedVector, possiblyDecoded, nil)
                            case .failure(let error):
                                completion(nil, nil, error)
                            }
                        }
                    }
                }
            }
        }
    }
}

extension PCKClock {
    init(uuid: UUID) {
        self.uuid = uuid
        self.objectId = UUID().uuidString
        vector = "{\"processes\":[{\"id\":\"\(uuid)\",\"clock\":0}]}"
        ACL = PCKUtility.getDefaultACL()
    }
}
