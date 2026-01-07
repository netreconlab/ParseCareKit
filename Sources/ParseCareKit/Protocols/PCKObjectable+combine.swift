//
//  PCKObjectable+combine.swift
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
public extension PCKObjectable {

    /**
     Finds the first object on the remote that has the same `uuid`.
     - Parameters:
        - uuid: The UUID to search for.
        - options: A set of header options sent to the remote. Defaults to an empty set.
        - relatedObject: An object that has the same `uuid` as the one being searched for.
        - returns: The first object found with the matching `uuid`.
        - throws: `Error`.
    */
    static func firstPublisher(
		_ uuid: UUID?,
		options: API.Options = []
	) -> Future<Self, Error> {
        Future { promise in
			nonisolated(unsafe) let promise = promise
            Self.first(
				uuid,
				options: options
			) { result in
				switch result {
				case .success(let object):
					promise(.success(object))
				case .failure(let error):
					promise(.failure(error))
				}
			}
        }
    }
}

#endif
