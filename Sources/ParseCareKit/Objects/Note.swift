//
//  Note.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore

/// An `Note` is the ParseCareKit equivalent of `OCKNote`.  `OCKNote` can be attached to all other
/// CareKit objects and values. Use cases may include a physician leaving a note on a task when it is modified
/// to explain why a medication dose was changed, or a note left from a patient to a care provider explaining
/// why they weren't able to complete a task on a certain occasion.
open class Note: PCKObjectable {

    public var uuid: UUID?

    public var entityId: String?

    public var logicalClock: Int?

    public var schemaVersion: OCKSemanticVersion?

    public var createdDate: Date?

    public var updatedDate: Date?

    public var timezone: TimeZone?

    public var userInfo: [String: String]?

    public var groupIdentifier: String?

    public var tags: [String]?

    public var source: String?

    public var asset: String?

    public var notes: [Note]?

    public var remoteID: String?

    public var encodingForParse: Bool = true {
        willSet {
            prepareEncodingRelational(newValue)
        }
    }

    public var objectId: String?

    public var createdAt: Date?

    public var updatedAt: Date?

    public var ACL: ParseACL?

    /// The note content.
    public var content: String?

    /// A title for the note.
    public var title: String?

    /// The person who created this note.
    public var author: String?

    /// A textual representation of this instance, suitable for debugging.
    public var localizedDescription: String {
        // swiftlint:disable:next line_length
        "\(debugDescription) title=\(String(describing: title)) content=\(String(describing: content)) author=\(String(describing: author))"
    }

    enum CodingKeys: String, CodingKey {
        case objectId, createdAt, updatedAt
        case uuid, schemaVersion, createdDate, updatedDate, timezone, userInfo,
             groupIdentifier, tags, source, asset, remoteID, notes
        case content, title, author
    }

    //Used to get encoder/decoder for ParseCareKitUtility, don't remove
    init() {
        self.timezone = .current
    }

    open class func copyValues(from other: Note, to here: Note) throws -> Self {
        var here = here
        here.copyCommonValues(from: other)
        here.content = other.content
        here.author = other.author
        here.title = other.title
        guard let copied = here as? Self else {
            throw ParseCareKitError.cantCastToNeededClassType
        }
        return copied
    }

    open class func copyCareKit(_ note: OCKNote) throws -> Note {
        let encoded = try ParseCareKitUtility.encoder().encode(note)
        let decoded = try ParseCareKitUtility.decoder().decode(Self.self, from: encoded)
        decoded.ACL = try? ParseACL.defaultACL()
        return decoded
    }

    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit() throws -> OCKNote {
        encodingForParse = false
        let encoded = try ParseCareKitUtility.jsonEncoder().encode(self)
        return try ParseCareKitUtility.decoder().decode(OCKNote.self, from: encoded)
    }

    public func prepareEncodingRelational(_ encodingForParse: Bool) {
        notes?.forEach {
            $0.encodingForParse = encodingForParse
        }
    }

    func stamp(_ clock: Int) {
        self.logicalClock = clock
        self.notes?.forEach {
            $0.logicalClock = self.logicalClock
        }
    }

    open class func replaceWithCloudVersion(_ local:inout [Note]?, cloud: [Note]?) {
        guard local != nil,
            cloud != nil else {
            return
        }

        for (index, note) in local!.enumerated() {
            guard let cloudNote = cloud!.first(where: {$0.uuid == note.uuid}) else {
                continue
            }
            local![index] = cloudNote
        }
    }

    open class func fetchAndReplace(_ notes: [Note]?, completion: @escaping([Note]?) -> Void) {
        let entitiesToFetch = notes?.compactMap { entity -> UUID? in
            if entity.objectId == nil {
                return entity.uuid
            }
            return nil
        }

        guard let uuids = entitiesToFetch,
              var originalNotes = notes else {
            completion(nil)
            return
        }
        let query = Self.query(containedIn(key: ObjectableKey.uuid, array: uuids))
            .include([ObjectableKey.notes])
        query.find(callbackQueue: .main) { results in

            switch results {

            case .success(let localNotes):
                //var returnNotes = notes!
                for (index, note) in localNotes.enumerated() {
                    guard let replaceNote = localNotes.first(where: {$0.uuid == note.uuid}),
                          let updatedNote = try? Self.copyValues(from: note, to: replaceNote) else {
                        continue
                    }

                    originalNotes[index] = updatedNote//Copy any changes
                }

                completion(originalNotes)
            case .failure:
                completion(nil)
            }
        }
    }
}
