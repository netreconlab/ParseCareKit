//
//  PCKSynchronizable.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/29/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore

/**
 Objects that conform to the `PCKSynchronizable` protocol are synchronized between the OCKStore and the Parse Cloud.
*/
public protocol PCKSynchronizable {

    /**
     Adds an object that conforms to PCKSynchronizable to the Parse Server and keeps
     it synchronized with the CareKitStore.

     - parameter overwriteRemote: Whether data should be overwritten if it's already present on the Parse Server.
     - parameter completion: The block to execute.
     It should have the following argument signature: `(Result<PCKSynchronizable,Error>)`.
    */
    func addToCloud(overwriteRemote: Bool, completion: @escaping(Result<PCKSynchronizable, Error>) -> Void)

    /**
     Updates an object that conforms to PCKSynchronizable that is already on the Parse
     Server and keeps it synchronized with the CareKitStore.

     - parameter overwriteRemote: Whether data should be overwritten if it's already present on the Parse Server.
     - parameter completion: The block to execute.
     It should have the following argument signature: `(Result<PCKSynchronizable,Error>)`.
    */
    func updateCloud(completion: @escaping(Result<PCKSynchronizable, Error>) -> Void)

    /**
     Creates a new ParseCareKit object from a specified CareKit entity.

     - parameter with: The CareKit entity used to create the new ParseCareKit object.
     
     - returns: Returns a new version of `Self`
    */
    func new(with careKitEntity: OCKEntity) throws -> Self

    /**
     Fetch all objects from the server that have been made on since the last time synchronization was performed.

     - Parameters:
        - since: The last time a synchronization was performed locally
        - cloudClock: The server clock represented as a vector.
        - mergeRevision: A closure that can be called multiple times to merge revisions.

     - Warning: The `mergeRevision` closure should never be called in parallel.
       Wait until one merge has completed before starting another.
     
    */
    func pullRevisions(since localClock: Int, cloudClock: OCKRevisionRecord.KnowledgeVector,
                       mergeRevision: @escaping (OCKRevisionRecord) -> Void)

    /**
     Push a revision from a device up to the server.
    
     - Parameters:
       - cloudClock: The current clock value of the revision.
       - overwriteRemote: If true, the contents of the remote should be completely overwritten.
       - completion: A closure that should be called once the push completes.
    */
    func pushRevision(cloudClock: Int, overwriteRemote: Bool, completion: @escaping (Error?) -> Void)
}
