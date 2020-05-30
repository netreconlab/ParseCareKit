//
//  PCKSynchronized.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/29/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import Parse
import CareKitStore

/**
 Protocol that defines the properties and methods for parse carekit entities that are synchronized using a wall clock.
 */
public protocol PCKSynchronized: PFObject, PFSubclassing {
    func addToCloud(_ usingKnowledgeVector:Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void)
    func updateCloud(_ usingKnowledgeVector:Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void)
    func deleteFromCloud(_ usingKnowledgeVector:Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void)
    func new()->PCKSynchronized
    func new(with careKitEntity: OCKEntity, completion: @escaping(PCKSynchronized?)-> Void)
}

/**
 Protocol that defines the properties and methods for parse carekit entities that are synchronized using a knowledge vector.
 */
public protocol PCKRemoteSynchronized: PCKSynchronized {
    func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void)
    func pushRevision(_ overwriteRemote: Bool, cloudClock: Int, completion: @escaping (Error?) -> Void)
}
