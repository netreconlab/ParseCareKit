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
    var clock: PCKClock?
    var knowledgeVector: OCKRevisionRecord.KnowledgeVector? {
        clock?.knowledgeVector
    }

    func synchronizing() {
        isSynchronizing = true
    }

    func notSynchronzing() {
        isSynchronizing = false
    }

    func updateClock(_ clock: PCKClock?) {
        self.clock = clock
    }

    func hasNewerClock(_ vector: OCKRevisionRecord.KnowledgeVector, for uuid: UUID) -> Bool {
        guard !isSynchronizing else {
            return false
        }
        guard let currentClock = knowledgeVector?.clock(for: uuid) else {
            return true
        }
        return vector.clock(for: uuid) > currentClock
    }
}
