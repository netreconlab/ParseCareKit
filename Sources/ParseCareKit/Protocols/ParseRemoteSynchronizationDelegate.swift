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
    func chooseConflictResolutionPolicy(_ conflict: OCKMergeConflictDescription,
                                        completion: @escaping (OCKMergeConflictResolutionPolicy) -> Void)
    /// Be notified when data has succesfully been pushed to the Cloud.
    func successfullyPushedDataToCloud()
}

extension ParseRemoteSynchronizationDelegate {
    func successfullyPushedDataToCloud() { }
}
