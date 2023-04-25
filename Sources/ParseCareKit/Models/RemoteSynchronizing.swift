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
    var isSynchronizing = false {
        willSet {
            if newValue {
                resetLiveQueryRetry()
            }
        }
    }
    var liveQueryRetry = 0
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

    func resetLiveQueryRetry() {
        liveQueryRetry = 0
    }

    func retryLiveQueryAfter() throws -> Int {
        liveQueryRetry += 1
        guard liveQueryRetry <= 10 else {
            throw ParseCareKitError.errorString("Max retries reached")
        }
        return Int.random(in: 0...liveQueryRetry)
    }

    func updateClock(_ clock: PCKClock?) {
        self.clock = clock
    }

    func updateClockIfNeeded(_ clock: PCKClock) {
        guard self.clock == nil else {
            return
        }
        self.clock = clock
    }

    func hasNewerClock(_ vector: OCKRevisionRecord.KnowledgeVector, for uuid: UUID) -> Bool {
        guard let currentClock = knowledgeVector?.clock(for: uuid) else {
            return true
        }
        return vector.clock(for: uuid) > currentClock
    }

    func hasNewerVector(_ vector: OCKRevisionRecord.KnowledgeVector) -> Bool {
        guard let currentVector = knowledgeVector else {
            return true
        }
        return vector > currentVector
    }
}
