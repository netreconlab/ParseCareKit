//
//  PCKRevisionRecord.swift
//  ParseCareKit
//
//  Created by Corey Baker on 4/16/23.
//  Copyright © 2023 Network Reconnaissance Lab. All rights reserved.
//

import CareKitStore
import Foundation
import os.log
import ParseSwift

/// Revision records are exchanged by the CareKit and a ParseCareKit remote during synchronization.
/// Each revision record contains an array of entities as well as a knowledge vector.
struct PCKRevisionRecord: ParseObject {

    public static var className: String {
        "RevisionRecord"
    }

    var originalData: Data?

    var objectId: String?

    var createdAt: Date?

    var updatedAt: Date?

    var ACL: ParseACL?

    var clockUUID: UUID?

    /// The clock value when this record was added to the Parse remote.
    var logicalClock: Int?

    /// The clock associated with this record when it was added to the Parse remote.
    var clock: PCKClock?

    /// The entities that were modified, in the order the were inserted into the database.
    /// The first entity is the oldest and the last entity is the newest.
    var entities: [PCKEntity]?

    /// A knowledge vector indicating the last known state of each other device
    /// by the device that authored this revision record.
    var knowledgeVector: OCKRevisionRecord.KnowledgeVector? {
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

    var knowledgeVectorString: String?

    var storeClassesToSynchronize: [PCKStoreClass: any PCKVersionable.Type]? = try? PCKStoreClass.getConcrete()

    var customClassesToSynchronize: [String: any PCKVersionable.Type]?

    var objects: [any PCKVersionable] {
        guard let entities = entities else {
            return []
        }
        return entities.map { $0.value }
    }

    var patients: [PCKPatient] {
        guard let entities = entities else {
            return []
        }
        return entities.compactMap { $0.value as? PCKPatient }
    }

    var carePlans: [PCKCarePlan] {
        guard let entities = entities else {
            return []
        }
        return entities.compactMap { $0.value as? PCKCarePlan }
    }

    var contacts: [PCKContact] {
        guard let entities = entities else {
            return []
        }
        return entities.compactMap { $0.value as? PCKContact }
    }

    var tasks: [PCKTask] {
        guard let entities = entities else {
            return []
        }
        return entities.compactMap { $0.value as? PCKTask }
    }

    var healthKitTasks: [PCKHealthKitTask] {
        guard let entities = entities else {
            return []
        }
        return entities.compactMap { $0.value as? PCKHealthKitTask }
    }

    var outcomes: [PCKOutcome] {
        guard let entities = entities else {
            return []
        }
        return entities.compactMap { $0.value as? PCKOutcome }
    }

    enum CodingKeys: String, CodingKey {
        case objectId, createdAt, updatedAt, className,
             ACL, knowledgeVectorString, entities,
             logicalClock, clock, clockUUID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(createdAt)
        hasher.combine(updatedAt)
        hasher.combine(ACL)
        hasher.combine(originalData)
        hasher.combine(clockUUID)
        hasher.combine(knowledgeVectorString)
        hasher.combine(logicalClock)
        hasher.combine(clock)
        hasher.combine(entities)
    }

    static func == (lhs: PCKRevisionRecord, rhs: PCKRevisionRecord) -> Bool {
        lhs.id == rhs.id &&
        lhs.createdAt == rhs.createdAt &&
        lhs.updatedAt == rhs.updatedAt &&
        lhs.ACL == rhs.ACL &&
        lhs.originalData == rhs.originalData &&
        lhs.clockUUID == rhs.clockUUID &&
        lhs.clock == rhs.clock &&
        lhs.knowledgeVectorString == rhs.knowledgeVectorString &&
        lhs.logicalClock == rhs.logicalClock &&
        lhs.entities == rhs.entities
    }

    func convertToCareKit() throws -> OCKRevisionRecord {
        guard let entities = entities,
            let knowledgeVector = knowledgeVector else {
            throw ParseCareKitError.couldntUnwrapSelf
        }
        let careKitEntities = try entities.compactMap { try $0.careKit() }
        return OCKRevisionRecord(entities: careKitEntities,
                                 knowledgeVector: knowledgeVector)
    }

	func save(
		options: API.Options = [],
		batchLimit: Int
	) async throws {
		let duplicateErrorString = "Attempted to add an object that is already on the server, skipping the save"
		let patientObjectIDs: [String] = patients.compactMap(\.objectId)
		do {
			let numberOfPatients = patients.count
			if numberOfPatients > batchLimit {
				Logger.revisionRecord.warning(
					"Attempting to save a large amount of \(numberOfPatients) Patients to the server, please ensure your server supports transactions of this size"
				)
			}
			let results = try await patients.createAll(
				batchLimit: numberOfPatients,
				options: options
			)
			results.forEach { result in
				switch result {
				case .success:
					return
				case .failure(let error):
					if error.equalsTo(.duplicateValue) {
						Logger.revisionRecord.warning(
							"\(duplicateErrorString)"
						)
					} else {
						Logger.revisionRecord.error("Failed to save revision record: \(error)")
					}
				}
			}
		} catch let parseError as ParseError {
			if parseError.equalsTo(.duplicateValue) {
				Logger.revisionRecord.warning(
					"\(duplicateErrorString). Verify the following Patients are already on the server: \(patientObjectIDs)"
				)
			} else {
				Logger.revisionRecord.error("Failed to save revision record: \(parseError)")
			}
		}

		let carePlanObjectIDs: [String] = carePlans.compactMap(\.objectId)
		do {
			let numberOfCarePlans = carePlans.count
			if numberOfCarePlans > batchLimit {
				Logger.revisionRecord.warning(
					"Attempting to save a large amount of \(numberOfCarePlans) CarePlans to the server, please ensure your server supports transactions of this size"
				)
			}
			let results = try await carePlans.createAll(
				batchLimit: numberOfCarePlans,
				options: options
			)
			results.forEach { result in
				switch result {
				case .success:
					return
				case .failure(let error):
					if error.equalsTo(.duplicateValue) {
						Logger.revisionRecord.warning(
							"\(duplicateErrorString)"
						)
					} else {
						Logger.revisionRecord.error("Failed to save revision record: \(error)")
					}
				}
			}
		} catch let parseError as ParseError {
			if parseError.equalsTo(.duplicateValue) {
				Logger.revisionRecord.warning(
					"\(duplicateErrorString). Verify the following CarePlans are already on the server: \(carePlanObjectIDs)"
				)
			} else {
				Logger.revisionRecord.error("Failed to save revision record: \(parseError)")
			}
		}

		let contactObjectIDs: [String] = contacts.compactMap(\.objectId)
		do {
			let numberOfContacts = contacts.count
			if numberOfContacts > batchLimit {
				Logger.revisionRecord.warning(
					"Attempting to save a large amount of \(numberOfContacts) Contacts to the server, please ensure your server supports transactions of this size"
				)
			}
			let results = try await contacts.createAll(
				batchLimit: numberOfContacts,
				options: options
			)
			results.forEach { result in
				switch result {
				case .success:
					return
				case .failure(let error):
					if error.equalsTo(.duplicateValue) {
						Logger.revisionRecord.warning(
							"\(duplicateErrorString)"
						)
					} else {
						Logger.revisionRecord.error("Failed to save revision record: \(error)")
					}
				}
			}
		} catch let parseError as ParseError {
			if parseError.equalsTo(.duplicateValue) {
				Logger.revisionRecord.warning(
					"\(duplicateErrorString). Verify the following Contacts are already on the server: \(contactObjectIDs)"
				)
			} else {
				Logger.revisionRecord.error("Failed to save revision record: \(parseError)")
			}
		}

		let taskObjectIDs: [String] = tasks.compactMap(\.objectId)
		do {
			let numberOfTasks = tasks.count
			if numberOfTasks > batchLimit {
				Logger.revisionRecord.warning(
					"Attempting to save a large amount of \(numberOfTasks) Tasks to the server, please ensure your server supports transactions of this size"
				)
			}
			let results = try await tasks.createAll(
				batchLimit: numberOfTasks,
				options: options
			)
			results.forEach { result in
				switch result {
				case .success:
					return
				case .failure(let error):
					if error.equalsTo(.duplicateValue) {
						Logger.revisionRecord.warning(
							"\(duplicateErrorString)"
						)
					} else {
						Logger.revisionRecord.error("Failed to save revision record: \(error)")
					}
				}
			}
		} catch let parseError as ParseError {
			if parseError.equalsTo(.duplicateValue) {
				Logger.revisionRecord.warning(
					"\(duplicateErrorString). Verify the following Tasks are already on the server: \(taskObjectIDs)"
				)
			} else {
				Logger.revisionRecord.error("Failed to save revision record: \(parseError)")
			}
		}

		let healthKitTaskObjectIDs: [String] = healthKitTasks.compactMap(\.objectId)
		do {
			let numberOfHealthKitTasks = healthKitTasks.count
			if numberOfHealthKitTasks > batchLimit {
				Logger.revisionRecord.warning(
					"Attempting to save a large amount of \(numberOfHealthKitTasks) HealthKitTasks to the server, please ensure your server supports transactions of this size"
				)
			}
			let results = try await healthKitTasks.createAll(
				batchLimit: numberOfHealthKitTasks,
				options: options
			)
			results.forEach { result in
				switch result {
				case .success:
					return
				case .failure(let error):
					if error.equalsTo(.duplicateValue) {
						Logger.revisionRecord.warning(
							"\(duplicateErrorString)"
						)
					} else {
						Logger.revisionRecord.error("Failed to save revision record: \(error)")
					}
				}
			}
		} catch let parseError as ParseError {
			if parseError.equalsTo(.duplicateValue) {
				Logger.revisionRecord.warning(
					"\(duplicateErrorString). Verify the following HealthKitTasks are already on the server: \(healthKitTaskObjectIDs)"
				)
			} else {
				Logger.revisionRecord.error("Failed to save revision record: \(parseError)")
			}
		}

		let outcomeObjectIDs: [String] = outcomes.compactMap(\.objectId)
		do {
			let numberOfOutcomes = outcomes.count
			if numberOfOutcomes > batchLimit {
				Logger.revisionRecord.warning(
					"Attempting to save a large amount of \(numberOfOutcomes) Outcomes to the server, please ensure your server supports transactions of this size"
				)
			}
			let results = try await outcomes.createAll(
				batchLimit: numberOfOutcomes,
				options: options
			)
			results.forEach { result in
				switch result {
				case .success:
					return
				case .failure(let error):
					if error.equalsTo(.duplicateValue) {
						Logger.revisionRecord.warning(
							"\(duplicateErrorString)"
						)
					} else {
						Logger.revisionRecord.error("Failed to save revision record: \(error)")
					}
				}
			}
		} catch let parseError as ParseError {
			if parseError.equalsTo(.duplicateValue) {
				Logger.revisionRecord.warning(
					"\(duplicateErrorString). Verify the following Outcomes are already on the server: \(outcomeObjectIDs)"
				)
			} else {
				Logger.revisionRecord.error("Failed to save revision record: \(parseError)")
			}
		}
        try await self.create(
			options: options
		)
    }

    func fetchEntities(options: API.Options = []) async throws -> Self {
        guard let entities = entities else {
            throw ParseCareKitError.couldntUnwrapSelf
        }
        var mutableRecord = self
        let patients = try await PCKPatient.query(
			containedIn(
				key: ParseKey.objectId,
				array: self.patients.compactMap { $0.objectId }
			)
		)
		.limit(queryLimit)
		.find(options: options)

        let carePlans = try await PCKCarePlan.query(
			containedIn(
				key: ParseKey.objectId,
				array: self.carePlans.compactMap { $0.objectId }
			)
		)
		.limit(queryLimit)
		.find(options: options)

        let contacts = try await PCKContact.query(
			containedIn(
				key: ParseKey.objectId,
				array: self.contacts.compactMap { $0.objectId }
			)
		)
		.limit(queryLimit)
		.find(options: options)

        let tasks = try await PCKTask.query(
			containedIn(
				key: ParseKey.objectId,
				array: self.tasks.compactMap { $0.objectId }
			)
		)
		.limit(queryLimit)
		.find(options: options)

        let healthKitTasks = try await PCKHealthKitTask.query(
			containedIn(
				key: ParseKey.objectId,
				array: self.healthKitTasks.compactMap { $0.objectId }
			)
		)
		.limit(queryLimit)
		.find(options: options)

        let outcomes = try await PCKOutcome.query(
			containedIn(
				key: ParseKey.objectId,
				array: self.outcomes.compactMap { $0.objectId }
			)
		)
		.limit(queryLimit)
		.find(options: options)

        mutableRecord.entities?.removeAll()
        try entities.forEach { entity in
            switch entity {
            case .patient(let patient):
                guard let fetched = patients.first(where: { $0.objectId == patient.objectId }) else {
                    throw ParseCareKitError.errorString("""
                        Patient with objectId, \"\(String(describing: patient.objectId))\" is not on remote
                    """)
                }
                mutableRecord.entities?.append(PCKEntity.patient(fetched))
            case .carePlan(let plan):
                guard let fetched = carePlans.first(where: { $0.objectId == plan.objectId }) else {
                    throw ParseCareKitError.errorString("""
                        CarePlan with objectId, \"\(String(describing: plan.objectId))\" is not on remote
                    """)
                }
                mutableRecord.entities?.append(PCKEntity.carePlan(fetched))
            case .contact(let contact):
                guard let fetched = contacts.first(where: { $0.objectId == contact.objectId }) else {
                    throw ParseCareKitError.errorString("""
                        Contact with objectId, \"\(String(describing: contact.objectId))\" is not on remote
                    """)
                }
                mutableRecord.entities?.append(PCKEntity.contact(fetched))
            case .task(let task):
                guard let fetched = tasks.first(where: { $0.objectId == task.objectId }) else {
                    throw ParseCareKitError.errorString("""
                        Task with objectId, \"\(String(describing: task.objectId))\" is not on remote
                    """)
                }
                mutableRecord.entities?.append(PCKEntity.task(fetched))
            case .healthKitTask(let healthKitTask):
                guard let fetched = healthKitTasks.first(where: { $0.objectId == healthKitTask.objectId }) else {
                    throw ParseCareKitError.errorString("""
                        HealthKitTask with objectId, \"\(String(describing: healthKitTask.objectId))\" is not on remote
                    """)
                }
                mutableRecord.entities?.append(PCKEntity.healthKitTask(fetched))
            case .outcome(let outcome):
                guard let fetched = outcomes.first(where: { $0.objectId == outcome.objectId }) else {
                    throw ParseCareKitError.errorString("""
                        Outcome with objectId, \"\(String(describing: outcome.objectId))\" is not on remote
                    """)
                }
                mutableRecord.entities?.append(PCKEntity.outcome(fetched))
            }
        }
        return mutableRecord
    }
}

extension PCKRevisionRecord {

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.objectId = try container.decodeIfPresent(String.self, forKey: .objectId)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        self.ACL = try container.decodeIfPresent(ParseACL.self, forKey: .ACL)
        self.knowledgeVectorString = try container.decodeIfPresent(String.self, forKey: .knowledgeVectorString)
        self.entities = try container.decodeIfPresent([PCKEntity].self, forKey: .entities)
        self.clock = try container.decodeIfPresent(PCKClock.self, forKey: .clock)
        self.logicalClock = try container.decodeIfPresent(Int.self, forKey: .logicalClock)
        self.clockUUID = try container.decodeIfPresent(UUID.self, forKey: .clockUUID)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(objectId, forKey: .objectId)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(ACL, forKey: .ACL)
        try container.encodeIfPresent(knowledgeVectorString, forKey: .knowledgeVectorString)
        try container.encodeIfPresent(entities, forKey: .entities)
        try container.encodeIfPresent(clock, forKey: .clock)
        try container.encodeIfPresent(logicalClock, forKey: .logicalClock)
        try container.encodeIfPresent(clockUUID, forKey: .clockUUID)
    }

    /// Create a new instance of `PCKRevisionRecord`.
    ///
    /// - Parameters:
    ///   - record: The CareKit revision record.
    ///   - remoteClockUUID: The remote clock uuid this record is designed for.
    ///   - remoteClock: The remote clock uuid this record is designed for.
    ///   - remoteClockValue: The remote clock uuid this record is designed for.
    init(record: OCKRevisionRecord,
         remoteClockUUID: UUID,
         remoteClock: PCKClock,
         remoteClockValue: Int,
         storeClassesToSynchronize: [PCKStoreClass: any PCKVersionable.Type]? = nil,
         customClassesToSynchronize: [String: any PCKVersionable.Type]? = nil) throws {
        self.objectId = UUID().uuidString
        self.ACL = PCKUtility.getDefaultACL()
        self.clockUUID = remoteClockUUID
        self.logicalClock = remoteClockValue
        self.clock = remoteClock
        self.knowledgeVector = record.knowledgeVector
        self.storeClassesToSynchronize = storeClassesToSynchronize
        self.customClassesToSynchronize = customClassesToSynchronize
        self.entities = try record.entities.compactMap { entity in
            var parseEntity = try entity.parseEntity().value
            parseEntity.logicalClock = remoteClockValue // Stamp Entity
            parseEntity.clock = remoteClock
            parseEntity.remoteID = remoteClockUUID.uuidString
            switch entity {
            case .patient:
                guard let parseEntity = parseEntity as? PCKPatient else {
                    return nil
                }
                return PCKEntity.patient(parseEntity)
            case .carePlan:
                guard let parseEntity = parseEntity as? PCKCarePlan else {
                    return nil
                }
                return PCKEntity.carePlan(parseEntity)
            case .contact:
                guard let parseEntity = parseEntity as? PCKContact else {
                    return nil
                }
                return PCKEntity.contact(parseEntity)
            case .task:
                guard let parseEntity = parseEntity as? PCKTask else {
                    return nil
                }
                return PCKEntity.task(parseEntity)
            case .healthKitTask:
                guard let parseEntity = parseEntity as? PCKHealthKitTask else {
                    return nil
                }
                return PCKEntity.healthKitTask(parseEntity)
            case .outcome:
                guard let parseEntity = parseEntity as? PCKOutcome else {
                    return nil
                }
                return PCKEntity.outcome(parseEntity)
            }
        }
    }
}
