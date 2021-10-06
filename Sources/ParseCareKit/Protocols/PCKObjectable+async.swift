//
//  PCKObjectable+async.swift
//  ParseCareKit
//
//  Created by Corey Baker on 10/6/21.
//  Copyright © 2021 Network Reconnaissance Lab. All rights reserved.
//

#if swift(>=5.5) && canImport(_Concurrency)
import Foundation
import ParseSwift

@available(macOS 12.0, iOS 15.0, macCatalyst 15.0, watchOS 9.0, tvOS 15.0, *)
public extension PCKObjectable {

    /**
     Finds the first object on the server that has the same `uuid`.
     - Parameters:
        - uuid: The UUID to search for.
        - options: A set of header options sent to the server. Defaults to an empty set.
        - relatedObject: An object that has the same `uuid` as the one being searched for.
        - returns: The first object found with the matching `uuid`.
        - throws: `ParseError`.
    */
    static func first(_ uuid: UUID?,
                      options: API.Options = []) async throws -> Self {
        try await withCheckedThrowingContinuation { continuation in
            Self.first(uuid,
                       options: options,
                       completion: continuation.resume)
        }
    }
}

#endif
