//
//  PCKVersionable+async.swift
//  ParseCareKit
//
//  Created by Corey Baker on 10/6/21.
//  Copyright © 2021 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift

public extension PCKVersionable {

    /**
     Find versioned objects *asynchronously* like `fetch` in CareKit. Finds the newest version
     that has not been deleted.
     - Parameters:
        - for: The date the objects are active.
        - options: A set of header options sent to the remote. Defaults to an empty set.
        - callbackQueue: The queue to return to after completion. Default value of `.main`.
        - returns: An array of objects matching the query.
        - throws: `ParseError`.
    */
    func find(
		for date: Date,
		options: API.Options = []
	) async throws -> [Self] {
        try await withCheckedThrowingContinuation { continuation in
            self.find(
				for: date,
				options: options,
				completion: { continuation.resume(with: $0) }
			)
        }
    }

    /**
     Saves a `PCKVersionable` object.
     - Parameters:
        - uuid: The UUID to search for.
        - options: A set of header options sent to the remote. Defaults to an empty set.
        - relatedObject: An object that has the same `uuid` as the one being searched for.
        - returns: The saved version.
        - throws: `ParseError`.
    */
    func save(options: API.Options = []) async throws -> Self {
        try await withCheckedThrowingContinuation { continuation in
            self.save(
				options: options,
				completion: { continuation.resume(with: $0) }
			)
        }
    }
}
