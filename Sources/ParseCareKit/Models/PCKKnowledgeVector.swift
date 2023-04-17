//
//  PCKKnowledgeVector.swift
//  ParseCareKit
//
//  Created by Corey Baker on 4/16/23.
//  Copyright © 2023 Network Reconnaissance Lab. All rights reserved.
//

import CareKitStore
import Foundation
import ParseSwift

/// Knowledge vectors, also know as Lamport Timestamps, are used to determine the order
/// of events in distributed systems that do not have a synchronized clock. If one knowledge
/// vector is less than another, it means that the first event happened before the second. If
/// one cannot be shown to be less than the other, it means the events are concurrent and
/// require resolution.
public struct KnowledgeVector: ParseObject {

    public var originalData: Data?

    public var objectId: String?

    public var createdAt: Date?

    public var updatedAt: Date?

    public var ACL: ParseACL?

    /// The CareKit Knowledge vector.
    public let vector: OCKRevisionRecord.KnowledgeVector?

    public func currentVector() throws -> OCKRevisionRecord.KnowledgeVector {
        guard let vector = vector else {
            throw ParseCareKitError.couldntUnwrapSelf
        }
        return vector
    }
}

extension KnowledgeVector {
    public init() {
        vector = nil
    }

    /// Create a new `KnowledgeVector` based on the CareKit knowledge vector.
    public init(_ vector: OCKRevisionRecord.KnowledgeVector) {
        self.vector = vector
        objectId = UUID().uuidString
        ACL = PCKUtility.getDefaultACL()
    }
}
