//
//  ParseRemoteSynchronizationDelegate.swift
//  ParseCareKit
//
//  Created by Corey Baker on 12/13/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import CareKitStore

/**
 Objects that conform to the `ParseRemoteSynchronizationDelegate` protocol are
 able to respond to updates and resolve conflicts when needed.
*/
public protocol ParseRemoteSynchronizationDelegate: OCKRemoteSynchronizationDelegate {
    /// When a conflict occurs, decide if the device or cloud record should be kept.
    func chooseConflictResolutionPolicy(_ conflict: OCKMergeConflictDescription,
                                        completion: @escaping (OCKMergeConflictResolutionPolicy) -> Void)
}
