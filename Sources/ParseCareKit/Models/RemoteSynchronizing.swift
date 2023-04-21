//
//  RemoteSynchronizing.swift
//  ParseCareKit
//
//  Created by Corey Baker on 4/10/23.
//  Copyright © 2023 Network Reconnaissance Lab. All rights reserved.
//

import CareKitStore
import Foundation

actor RemoteSynchronizing {
    var isSynchronizing = false
    var knowledgeVector: OCKRevisionRecord.KnowledgeVector?

    func synchronizing() {
        isSynchronizing = true
    }

    func notSynchronzing() {
        isSynchronizing = false
    }

    func updateKnowledgeVector(_ vector: OCKRevisionRecord.KnowledgeVector?) {
        knowledgeVector = vector
    }

    func hasNewerRevision(_ vector: OCKRevisionRecord.KnowledgeVector, for uuid: UUID) -> Bool {
        guard !isSynchronizing else {
            return false
        }
        guard let currentClock = knowledgeVector?.clock(for: uuid) else {
            return true
        }
        return vector.clock(for: uuid) > currentClock
    }
}
