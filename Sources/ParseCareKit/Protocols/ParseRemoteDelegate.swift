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
    /// When a conflict occurs, decide if the device or cloud record should be kept.
    func chooseConflictResolution(conflicts: [OCKEntity], completion: @escaping OCKResultClosure<OCKEntity>)

    /// Receive a notification when data has been successfully pushed to the Cloud.
    func successfullyPushedDataToCloud()
}

extension ParseRemoteDelegate {
    func successfullyPushedDataToCloud() { }
}
