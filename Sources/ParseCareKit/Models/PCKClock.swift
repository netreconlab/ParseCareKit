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

struct PCKClock: ParseObject {

    static var className: String {
        "Clock"
    }

    var objectId: String?

    var createdAt: Date?

    var updatedAt: Date?

    var ACL: ParseACL?

    var originalData: Data?

    var uuid: UUID?

    var vector: String?

    func merge(with object: PCKClock) throws -> PCKClock {
        var updated = try mergeParse(with: object)
        if updated.shouldRestoreKey(\.uuid,
                                     original: object) {
            updated.uuid = object.uuid
        }
        if updated.shouldRestoreKey(\.vector,
                                     original: object) {
            updated.vector = object.vector
        }
        return updated
    }

    func decodeClock(completion: @escaping(OCKRevisionRecord.KnowledgeVector?) -> Void) {
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

    func setupWriteRole(_ owner: PCKUser) async throws -> PCKWriteRole {
        var role: PCKWriteRole
        let roleName = try PCKWriteRole.roleName(owner: owner)
        do {
            role = try await PCKWriteRole.query(ParseKey.name == roleName).first()
        } catch {
            role = try PCKWriteRole.create(with: owner)
            role = try await role.create()
        }
        return role
    }

    func setupReadRole(_ owner: PCKUser) async throws -> PCKReadRole {
        var role: PCKReadRole
        let roleName = try PCKReadRole.roleName(owner: owner)
        do {
            role = try await PCKReadRole.query(ParseKey.name == roleName).first()
        } catch {
            role = try PCKReadRole.create(with: owner)
            role = try await role.create()
        }
        return role
    }

    func setupACLWithRoles() async throws -> Self {
        let currentUser = try await PCKUser.current()
        let writeRole = try await setupWriteRole(currentUser)
        let readRole = try await setupReadRole(currentUser)
        let writeRoleName = try PCKWriteRole.roleName(owner: currentUser)
        let readRoleName = try PCKReadRole.roleName(owner: currentUser)
        do {
            _ = try await readRole
                .queryRoles()
                .where(ParseKey.name == writeRoleName)
                .first()
        } catch {
            // Need to give write role read access.
            guard let roles = try readRole.roles?.add([writeRole]) else {
                throw ParseCareKitError.errorString("Should have roles for readRole")
            }
            _ = try await roles.save()
        }
        var mutatingClock = self
        mutatingClock.ACL = ACL ?? ParseACL()
        mutatingClock.ACL?.setWriteAccess(roleName: writeRoleName, value: true)
        mutatingClock.ACL?.setReadAccess(roleName: readRoleName, value: true)
        mutatingClock.ACL?.setWriteAccess(roleName: ParseCareKitConstants.administratorRole, value: true)
        mutatingClock.ACL?.setReadAccess(roleName: ParseCareKitConstants.administratorRole, value: true)
        return mutatingClock
    }

    static func fetchFromCloud(uuid: UUID, createNewIfNeeded: Bool,
                               completion: @escaping(PCKClock?,
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
                    Task {
                        do {
                            let updatedVector = try await newVector.setupACLWithRoles()
                            updatedVector.decodeClock { possiblyDecoded in
                                updatedVector.create(callbackQueue: ParseRemote.queue) { result in
                                    switch result {
                                    case .success(let savedVector):
                                        completion(savedVector, possiblyDecoded, nil)
                                    case .failure(let error):
                                        completion(nil, nil, error)
                                    }
                                }
                            }
                        } catch {
                            guard let parseError = error as? ParseError else {
                                if #available(iOS 14.0, watchOS 7.0, *) {
                                    Logger.clock.error("""
                                        Couldn't cast error to
                                        ParseError: \(error.localizedDescription)
                                    """)
                                } else {
                                    os_log("Couldn't cast error to ParseError: %{private}@",
                                           log: .clock,
                                           type: .error,
                                           error.localizedDescription)
                                }
                                completion(nil, nil, nil)
                                return
                            }
                            completion(nil, nil, parseError)
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
        vector = "{\"processes\":[{\"id\":\"\(uuid)\",\"clock\":0}]}"
        ACL = PCKUtility.getDefaultACL()
    }
}
