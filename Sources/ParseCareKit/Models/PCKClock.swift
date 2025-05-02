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

public struct PCKClock: ParseObject {

    public static var className: String {
        "Clock"
    }

    public var objectId: String?

    public var createdAt: Date?

    public var updatedAt: Date?

    public var ACL: ParseACL?

    public var originalData: Data?

    public var uuid: UUID?

    var knowledgeVectorString: String?

    /// A knowledge vector indicating the last known state of each other device
    /// by the device that authored this revision record.
    public var knowledgeVector: OCKRevisionRecord.KnowledgeVector? {
        get {
            try? PCKClock.decodeVector(knowledgeVectorString)
        }
        set {
            guard let newValue = newValue else {
                knowledgeVectorString = nil
                return
            }
            knowledgeVectorString = PCKClock.encodeVector(newValue)
        }
    }

    public init() { }

    public func merge(with object: PCKClock) throws -> PCKClock {
        var updated = try mergeParse(with: object)
        if updated.shouldRestoreKey(\.uuid,
                                     original: object) {
            updated.uuid = object.uuid
        }
        if updated.shouldRestoreKey(\.knowledgeVectorString,
                                     original: object) {
            updated.knowledgeVectorString = object.knowledgeVectorString
        }
        return updated
    }

    static func decodeVector(_ clock: Self) throws -> OCKRevisionRecord.KnowledgeVector {
        try decodeVector(clock.knowledgeVectorString)
    }

    static func decodeVector(_ vector: String?) throws -> OCKRevisionRecord.KnowledgeVector {
        guard let data = vector?.data(using: .utf8) else {
            let errorString = "Could not get data as utf8"
            Logger.clock.error("\(errorString)")
            throw ParseCareKitError.errorString(errorString)
        }

        do {
            return try JSONDecoder().decode(OCKRevisionRecord.KnowledgeVector.self,
                                            from: data)
        } catch {
            Logger.clock.error("Clock.decodeVector(): \(error, privacy: .private). Vector \(data, privacy: .private).")
            throw ParseCareKitError.errorString("Clock.decodeVector(): \(error)")
        }
    }

    static func encodeVector(_ vector: OCKRevisionRecord.KnowledgeVector, for clock: Self) -> Self? {
        guard let remoteVectorString = encodeVector(vector) else {
            return nil
        }
        var mutableClock = clock
        mutableClock.knowledgeVectorString = remoteVectorString
        return mutableClock
    }

    static func encodeVector(_ vector: OCKRevisionRecord.KnowledgeVector) -> String? {
        do {
            let json = try JSONEncoder().encode(vector)
            guard let remoteVectorString = String(data: json, encoding: .utf8) else {
                return nil
            }
            return remoteVectorString
        } catch {
            Logger.clock.error("Clock.encodeVector(): \(error, privacy: .private).")
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

    static func new(uuid: UUID) async throws -> Self {
        var newClock = PCKClock(uuid: uuid)
        newClock = try await newClock.setupACLWithRoles()
        return try await newClock.create()
    }

    static func fetchFromRemote(
		_ uuid: UUID,
		createNewIfNeeded: Bool = false
	) async throws -> Self {
		do {
			let fetchedClock = try await Self(uuid: uuid).fetch()
			return fetchedClock
		} catch let originalError {
			do {
				// Check if using an old version of ParseCareKit
				// which didn't have the uuid as the objectID.
				let query = Self.query(ClockKey.uuid == uuid)
				let queriedClock = try await query.first()
				return queriedClock
			} catch {
				guard createNewIfNeeded else {
					throw originalError
				}
				do {
					let newClock = try await new(uuid: uuid)
					let savedClock = try await newClock.create()
					return savedClock
				} catch {
					guard let parseError = error as? ParseError else {
						let errorString = "Could not cast error to ParseError"
						Logger.clock.error("\(errorString): \(error)")
						let parseError = ParseError(
							message: errorString,
							swift: error
						)
						throw parseError
					}
					Logger.clock.error("\(parseError)")
					throw parseError
				}
			}
		}
    }
}

extension PCKClock {
    init(uuid: UUID) {
        self.uuid = uuid
		self.objectId = uuid.uuidString
        knowledgeVectorString = "{\"processes\":[{\"id\":\"\(uuid)\",\"clock\":0}]}"
        ACL = PCKUtility.getDefaultACL()
    }
}
