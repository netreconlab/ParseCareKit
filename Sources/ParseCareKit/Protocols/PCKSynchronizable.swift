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
 Objects that conform to the `PCKSynchronizable` protocol are synchronized between the `OCKStore` and the Parse Cloud.
 In order to synchronize objects, they must also conform to either `PCKObjectable` or `PCKVersionable`. For examples,
 see `PCKPatient`, `PCKCarePlan`, `PCKTask`, `PCKContact`, and `PCKOutcome`. 
*/
public protocol PCKSynchronizable {

    /**
     Adds an object that conforms to PCKSynchronizable to the Parse Server and keeps
     it synchronized with the CareKitStore.

     - parameter delegate: The `ParseRemoteDelegate`.
     - parameter completion: The block to execute.
     It should have the following argument signature: `(Result<PCKSynchronizable,Error>)`.
    */
    func addToCloud(_ delegate: ParseRemoteDelegate?,
                    completion: @escaping(Result<PCKSynchronizable, Error>) -> Void)

    /**
     Updates an object that conforms to PCKSynchronizable that is already on the Parse
     Server and keeps it synchronized with the CareKitStore.

     - parameter delegate: The `ParseRemoteDelegate`.
     - parameter overwriteRemote: Whether data should be overwritten if it's already present on the Parse Server.
     - parameter completion: The block to execute.
     It should have the following argument signature: `(Result<PCKSynchronizable,Error>)`.
    */
    func updateCloud(_ delegate: ParseRemoteDelegate?,
                     completion: @escaping(Result<PCKSynchronizable, Error>) -> Void)

    /**
     Creates a new ParseCareKit object from a specified CareKit entity.

     - parameter with: The CareKit entity used to create the new ParseCareKit object.
     - returns: Returns a new version of `Self`
     - throws: `Error`.
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
    func pullRevisions(since localClock: Int,
                       cloudClock: OCKRevisionRecord.KnowledgeVector,
                       remoteID: String,
                       mergeRevision: @escaping (Result<OCKRevisionRecord, ParseError>) -> Void)

    /**
     Push a revision from a device up to the server.
    
     - Parameters:
       - delegate: The `ParseRemoteDelegate`.
       - cloudClock: The current clock value of the revision.
       - completion: A closure that should be called once the push completes.
    */
    func pushRevision(_ delegate: ParseRemoteDelegate?,
                      cloudClock: Int,
                      remoteID: String,
                      completion: @escaping (Error?) -> Void)
}
