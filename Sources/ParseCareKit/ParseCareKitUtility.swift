//
//  ParseCareKitUtility.swift
//  ParseCareKit
//
//  Created by Corey Baker on 4/26/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift

/// Utility functions designed to make things easier.
public struct ParseCareKitUtility {

    /// Can setup a connection to Parse Server based on a ParseCareKit.plist
    public static func setupServer() {
        var propertyListFormat =  PropertyListSerialization.PropertyListFormat.xml
        var plistConfiguration: [String: AnyObject]
        guard let path = Bundle.main.path(forResource: "ParseCareKit", ofType: "plist"),
            let xml = FileManager.default.contents(atPath: path) else {
                fatalError("Error in ParseCareKit.setupServer(). Can't find ParseCareKit.plist in this project")
        }

        do {
            plistConfiguration =
                try PropertyListSerialization.propertyList(from: xml,
                                                           options: .mutableContainersAndLeaves,
                                                           // swiftlint:disable:next force_cast
                                                           format: &propertyListFormat) as! [String: AnyObject]
        } catch {
            fatalError("Error in ParseCareKit.setupServer(). Couldn't serialize plist. \(error)")
        }

        guard let parseDictionary = plistConfiguration["ParseClientConfiguration"] as? [String: AnyObject],
            let appID = parseDictionary["ApplicationID"] as? String,
            let server = parseDictionary["Server"] as? String,
            let serverURL = URL(string: server),
            (parseDictionary["EnableLocalDataStore"] as? Bool) != nil else {
                fatalError("Error in ParseCareKit.setupServer(). Missing keys in \(plistConfiguration)")
        }

        ParseSwift.initialize(applicationId: appID, serverURL: serverURL)
    }

    /// Converts a date to a String.
    public static func dateToString(_ date: Date) -> String {
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"

        return dateFormatter.string(from: date)
    }

    /// Converts a String to a Date.
    public static func stringToDate(_ date: String) -> Date? {
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"

        return dateFormatter.date(from: date)
    }

    /// Get the current Parse Encoder with custom date strategy.
    public static func encoder() -> ParseEncoder {
        Note().getEncoder()
    }

    /// Get the current JSON Encoder with custom date strategy.
    public static func jsonEncoder() -> JSONEncoder {
        Note().getJSONEncoder()
    }

    /// Get the current JSON Decoder with custom date strategy.
    public static func decoder() -> JSONDecoder {
        Note().getDecoder()
    }
}
