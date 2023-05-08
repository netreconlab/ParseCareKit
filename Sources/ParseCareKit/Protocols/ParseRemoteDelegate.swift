//
//  ParseRemoteDelegate.swift
//  ParseCareKit
//
//  Created by Corey Baker on 12/13/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import CareKitStore

/**
 Objects that conform to the `ParseRemoteDelegate` protocol are
 able to respond to updates and resolve conflicts when needed.
*/
public protocol ParseRemoteDelegate: OCKRemoteSynchronizationDelegate {
    /// When a conflict occurs, decide if the local or remote record should be kept.
    func chooseConflictResolution(conflicts: [OCKEntity], completion: @escaping OCKResultClosure<OCKEntity>)

    /// Receive a notification when data has been successfully pushed to the remote.
    func successfullyPushedToRemote()

    /// Sometimes the remote will need the local data store to fetch additional information
    /// required for proper synchronization.
    /// - note: The remote will never use this method to modify the store.
    func provideStore() -> OCKAnyStoreProtocol
}

extension ParseRemoteDelegate {
    func successfullyPushedToRemote() {}
}
