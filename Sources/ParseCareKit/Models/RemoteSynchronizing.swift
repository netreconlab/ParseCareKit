//
//  RemoteSynchronizing.swift
//  ParseCareKit
//
//  Created by Corey Baker on 4/10/23.
//  Copyright © 2023 Network Reconnaissance Lab. All rights reserved.
//

import Foundation

actor RemoteSynchronizing {
    var isSynchronizing = false

    func setSynchronizing() {
        isSynchronizing = true
    }

    func setNotSynchronzing() {
        isSynchronizing = false
    }
}
