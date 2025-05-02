//
//  PCKUtility.swift
//  ParseCareKit
//
//  Created by Corey Baker on 4/26/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import os.log

// swiftlint:disable line_length

/// Utility functions designed to make things easier.
public class PCKUtility {

    class func getPlistConfiguration(fileName: String) throws -> [String: AnyObject] {
        var propertyListFormat = PropertyListSerialization.PropertyListFormat.xml
        guard let path = Bundle.main.path(forResource: fileName, ofType: "plist"),
            let xml = FileManager.default.contents(atPath: path) else {
                fatalError("Error in ParseCareKit.configureParse(). Cannot find ParseCareKit.plist in this project")
        }

        return try PropertyListSerialization.propertyList(from: xml,
                                                          options: .mutableContainersAndLeaves,
                                                          // swiftlint:disable:next force_cast
                                                          format: &propertyListFormat) as! [String: AnyObject]
    }

    /**
     Configure the client to connect to a Parse Server based on a ParseCareKit.plist file.
    
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
    public class func configureParse(fileName: String = "ParseCareKit",
                                     authentication: ((URLAuthenticationChallenge,
                                                       (URLSession.AuthChallengeDisposition,
                                                        URLCredential?) -> Void) -> Void)? = nil) async throws {
        var plistConfiguration: [String: AnyObject]
        var clientKey: String?
        var liveQueryURL: URL?
        var useTransactions = false
        var deleteKeychainIfNeeded = false
        do {
            plistConfiguration = try Self.getPlistConfiguration(fileName: fileName)
        } catch {
            fatalError("Error in ParseCareKit.configureParse(). Could not serialize plist. \(error)")
        }

        guard let appID = plistConfiguration["ApplicationID"] as? String,
            let server = plistConfiguration["Server"] as? String,
            let serverURL = URL(string: server) else {
                fatalError("Error in ParseCareKit.configureParse(). Missing keys in \(plistConfiguration)")
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

        try await ParseSwift.initialize(
			applicationId: appID,
			clientKey: clientKey,
			serverURL: serverURL,
			liveQueryServerURL: liveQueryURL,
			requiringCustomObjectIds: true,
			usingTransactions: useTransactions,
			usingPostForQuery: true,
			deletingKeychainIfNeeded: deleteKeychainIfNeeded,
			authentication: authentication
		)
    }

    /**
     Setup the Keychain access group and synchronization across devices.
    
     The key/values supported in the file are a dictionary named `ParseClientConfiguration`:
     - AccessGroup - (String) The Keychain access group.
     - SynchronizeKeychain - (Boolean) Whether or not to synchronize the Keychain across devices.
     - parameter fileName: Name of **.plist** file that contains config. Defaults to "ParseCareKit".
     */
    public class func setAccessGroup(fileName: String = "ParseCareKit") async throws {
        var plistConfiguration: [String: AnyObject]
        var accessGroup: String?
        var synchronizeKeychain = false

        do {
            plistConfiguration = try Self.getPlistConfiguration(fileName: fileName)
        } catch {
            fatalError("Error in ParseCareKit.configureParse(). Could not serialize plist. \(error)")
        }

        if let keychainAccessGroup = plistConfiguration["AccessGroup"] as? String {
            accessGroup = keychainAccessGroup
        }

        if let synchronizeKeychainAcrossDevices = plistConfiguration["SynchronizeKeychain"] as? Bool {
            synchronizeKeychain = synchronizeKeychainAcrossDevices
        }

        try await ParseSwift.setAccessGroup(accessGroup,
                                            synchronizeAcrossDevices: synchronizeKeychain)
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

    /// Remove ParseCareKit cache from device.
    public class func removeCache() {
        UserDefaults.standard.removeObject(forKey: ParseCareKitConstants.defaultACL)
        UserDefaults.standard.synchronize()
    }

    /// Get the default ACL for `ParseCareKit` objects.
    public class func getDefaultACL() -> ParseACL? {
        guard let aclString = UserDefaults.standard.value(forKey: ParseCareKitConstants.defaultACL) as? String,
              let aclData = aclString.data(using: .utf8),
              let acl = try? decoder().decode(ParseACL.self, from: aclData) else {
                  return nil
              }
        return acl
    }
}
