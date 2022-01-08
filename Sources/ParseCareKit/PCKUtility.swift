//
//  PCKUtility.swift
//  ParseCareKit
//
//  Created by Corey Baker on 4/26/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift

// swiftlint:disable line_length

/// Utility functions designed to make things easier.
public class PCKUtility {

    /** Can setup a connection to Parse Server based on a ParseCareKit.plist file.
    
   The key/values supported in the file are a dictionary named `ParseClientConfiguration`:
    - Server - (String) The server URL to connect to Parse Server.
    - ApplicationID - (String) The application id of your Parse application.
    - ClientKey - (String) The client key of your Parse application.
    - LiveQueryServer - (String) The live query server URL to connect to Parse Server.
    - UseTransactionsInternally - (Boolean) Use transactions inside the Client SDK.
    - DeleteKeychainIfNeeded - (Boolean) Deletes the Parse Keychain when the app is running for the first time.
    - parameter fileName: Name of **.plist** file that contains config. Defaults to "ParseCareKit".
    - parameter authentication: A callback block that will be used to receive/accept/decline network challenges.
     Defaults to `nil` in which the SDK will use the default OS authentication methods for challenges.
     It should have the following argument signature: `(challenge: URLAuthenticationChallenge,
     completionHandler: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void`.
     See Apple's [documentation](https://developer.apple.com/documentation/foundation/urlsessiontaskdelegate/1411595-urlsession) for more for details.
     */
    public class func setupServer(fileName: String = "ParseCareKit",
                                  authentication: ((URLAuthenticationChallenge,
                                                    (URLSession.AuthChallengeDisposition,
                                                      URLCredential?) -> Void) -> Void)? = nil) {
        var propertyListFormat =  PropertyListSerialization.PropertyListFormat.xml
        var plistConfiguration: [String: AnyObject]
        var clientKey: String?
        var liveQueryURL: URL?
        var useTransactions = false
        var deleteKeychainIfNeeded = false
        guard let path = Bundle.main.path(forResource: fileName, ofType: "plist"),
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

        guard let appID = plistConfiguration["ApplicationID"] as? String,
            let server = plistConfiguration["Server"] as? String,
            let serverURL = URL(string: server) else {
                fatalError("Error in ParseCareKit.setupServer(). Missing keys in \(plistConfiguration)")
        }

        if let client = plistConfiguration["ClientKey"] as? String {
            clientKey = client
        }

        if let liveQuery = plistConfiguration["LiveQueryServer"] as? String {
            liveQueryURL = URL(string: liveQuery)
        }

        if let transactions = plistConfiguration["UseTransactions"] as? Bool {
            useTransactions = transactions
        }

        if let deleteKeychain = plistConfiguration["DeleteKeychainIfNeeded"] as? Bool {
            deleteKeychainIfNeeded = deleteKeychain
        }

        ParseSwift.initialize(applicationId: appID,
                              clientKey: clientKey,
                              serverURL: serverURL,
                              liveQueryServerURL: liveQueryURL,
                              isAllowingCustomObjectIds: true,
                              isUsingTransactions: useTransactions,
                              isDeletingKeychainIfNeeded: deleteKeychainIfNeeded,
                              authentication: authentication)
    }

    /// Get the current Parse Encoder with custom date strategy.
    public class func encoder() -> ParseEncoder {
        PCKOutcome.getEncoder()
    }

    /// Get the current JSON Encoder with custom date strategy.
    public class func jsonEncoder() -> JSONEncoder {
        PCKOutcome.getJSONEncoder()
    }

    /// Get the current JSON Decoder with custom date strategy.
    public class func decoder() -> JSONDecoder {
        PCKOutcome.getDecoder()
    }

    class func getDefaultACL() -> ParseACL? {
        guard let aclString = UserDefaults.standard.value(forKey: ParseCareKitConstants.defaultACL) as? String,
              let aclData = aclString.data(using: .utf8),
              let acl = try? decoder().decode(ParseACL.self, from: aclData) else {
                  return nil
              }
        return acl
    }
}
