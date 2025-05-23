//
//  PCKObjectable+async.swift
//  ParseCareKit
//
//  Created by Corey Baker on 10/6/21.
//  Copyright © 2021 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift

public extension PCKObjectable {

    /**
     Finds the first object on the remote that has the same `uuid`.
     - Parameters:
        - uuid: The UUID to search for.
        - options: A set of header options sent to the remote. Defaults to an empty set.
        - relatedObject: An object that has the same `uuid` as the one being searched for.
        - returns: The first object found with the matching `uuid`.
        - throws: `ParseError`.
    */
    static func first(_ uuid: UUID?,
                      options: API.Options = []) async throws -> Self {
        try await withCheckedThrowingContinuation { continuation in
            Self.first(
				uuid,
				options: options,
				completion: { continuation.resume(with: $0) }
			)
        }
    }
}
