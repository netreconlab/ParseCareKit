//
//  ParseCareKitUtility.swift
//  ParseCareKit
//
//  Created by Corey Baker on 4/26/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift

// swiftlint:disable line_length

/// Utility functions designed to make things easier.
public struct ParseCareKitUtility {

    /** Can setup a connection to Parse Server based on a ParseCareKit.plist file.
    
   The key/values supported in the file are a dictionary named `ParseClientConfiguration`:
    - Server - (String) The server URL to connect to Parse Server.
    - ApplicationID - (String) The application id of your Parse application.
    - ClientKey - (String) The client key of your Parse application.
    - LiveQueryServer - (String) The live query server URL to connect to Parse Server.
    - UseTransactionsInternally - (Boolean) Use transactions inside the Client SDK.
    - parameter authentication: A callback block that will be used to receive/accept/decline network challenges.
     Defaults to `nil` in which the SDK will use the default OS authentication methods for challenges.
     It should have the following argument signature: `(challenge: URLAuthenticationChallenge,
     completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void`.
     See Apple's [documentation](https://developer.apple.com/documentation/foundation/urlsessiontaskdelegate/1411595-urlsession) for more for details.
     */
    public static func setupServer(authentication: ((URLAuthenticationChallenge,
                                                     (URLSession.AuthChallengeDisposition,
                                                      URLCredential?) -> Void) -> Void)? = nil) {
        var propertyListFormat =  PropertyListSerialization.PropertyListFormat.xml
        var plistConfiguration: [String: AnyObject]
        var clientKey: String?
        var liveQueryURL: URL?
        var useTransactionsInternally = false
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
            let serverURL = URL(string: server) else {
                fatalError("Error in ParseCareKit.setupServer(). Missing keys in \(plistConfiguration)")
        }

        if let client = parseDictionary["ClientKey"] as? String {
            clientKey = client
        }

        if let liveQuery = parseDictionary["LiveQueryServer"] as? String {
            liveQueryURL = URL(string: liveQuery)
        }

        if let internalTransactions = parseDictionary["UseTransactionsInternally"] as? Bool {
            useTransactionsInternally = internalTransactions
        }

        ParseSwift.initialize(applicationId: appID,
                              clientKey: clientKey,
                              serverURL: serverURL,
                              liveQueryServerURL: liveQueryURL,
                              useTransactionsInternally: useTransactionsInternally,
                              authentication: authentication)
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
        Outcome().getEncoder()
    }

    /// Get the current JSON Encoder with custom date strategy.
    public static func jsonEncoder() -> JSONEncoder {
        Outcome().getJSONEncoder()
    }

    /// Get the current JSON Decoder with custom date strategy.
    public static func decoder() -> JSONDecoder {
        Outcome().getDecoder()
    }
}
