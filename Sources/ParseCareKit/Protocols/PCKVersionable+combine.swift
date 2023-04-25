//
//  PCKVersionable+combine.swift
//  ParseCareKit
//
//  Created by Corey Baker on 10/6/21.
//  Copyright © 2021 Network Reconnaissance Lab. All rights reserved.
//

#if canImport(Combine)
import Foundation
import ParseSwift
import Combine

@available(macOS 10.15, iOS 13.0, macCatalyst 13.0, watchOS 6.0, tvOS 13.0, *)
public extension PCKVersionable {

    /**
     Find versioned objects *asynchronously* like `fetch` in CareKit. Finds the newest version
     that has not been deleted. Publishes when complete.
     - Parameters:
        - for: The date the objects are active.
        - options: A set of header options sent to the remote. Defaults to an empty set.
        - returns: `Future<[Self],ParseError>`.
    */
    func findPublisher(for date: Date,
                       options: API.Options = []) -> Future<[Self], ParseError> {
        Future { promise in
            self.find(for: date,
                         options: options,
                         completion: promise)
        }
    }

    /**
     Saves a `PCKVersionable` object. *asynchronously*. Publishes when complete.
     - Parameters:
        - options: A set of header options sent to the remote. Defaults to an empty set.
        - returns: `Future<[Self],ParseError>`.
    */
    func savePublisher(for date: Date,
                       options: API.Options = []) -> Future<Self, ParseError> {
        Future { promise in
            self.save(options: options,
                      completion: promise)
        }
    }
}

#endif
