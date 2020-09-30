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

open class Note: PCKObjectable {
    
    public internal(set) var uuid: UUID?
    
    public internal(set) var entityId: String?
    
    public internal(set) var logicalClock: Int?
    
    public internal(set) var schemaVersion: OCKSemanticVersion?
    
    public internal(set) var createdDate: Date?
    
    public internal(set) var updatedDate: Date?
    
    public internal(set) var deletedDate: Date?
    
    public var timezone: TimeZone?
    
    public var userInfo: [String : String]?
    
    public var groupIdentifier: String?
    
    public var tags: [String]?
    
    public var source: String?
    
    public var asset: String?
    
    public var notes: [Note]?
    
    public var remoteID: String?
    
    var encodingForParse: Bool = true
    
    public var objectId: String?
    
    public var createdAt: Date?
    
    public var updatedAt: Date?
    
    public var ACL: ParseACL?
    

    public var content:String?
    public var title:String?
    public var author:String?

    init() {
        
    }

    public convenience init?(careKitEntity: OCKNote) {
        do {
            self.init()
            _ = try Self.copyCareKit(careKitEntity)
        } catch {
            return nil
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case uuid, schemaVersion, createdDate, updatedDate, timezone, userInfo, groupIdentifier, tags, source, asset, remoteID, notes, logicalClock
        case content, title, author
    }
    /*
    enum CodingKeys: String, CodingKey {
        case content, title, author
    }
    
    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(content, forKey: .content)
        try container.encode(title, forKey: .title)
        try container.encode(author, forKey: .author)
    }*/

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
        let encoded = try JSONEncoder().encode(note)
        return try JSONDecoder().decode(Self.self, from: encoded)
        /*
        if let uuid = Note.getUUIDFromCareKitEntity(note){
            self.uuid = uuid
        }else{
            print("Warning in \(className).copyCareKit(). Entity missing uuid: \(note)")
        }
        
        if let schemaVersion = Note.getSchemaVersionFromCareKitEntity(note){
            self.schemaVersion = schemaVersion
        }else{
            print("Warning in \(className).copyCareKit(). Entity missing schemaVersion: \(note)")
        }
        self.timezone = note.timezone.abbreviation()!
        self.groupIdentifier = note.groupIdentifier
        self.tags = note.tags
        self.source = note.source
        self.asset = note.asset
        self.timezone = note.timezone.abbreviation()!
        self.author = note.author
        self.userInfo = note.userInfo
        self.updatedDate = note.updatedDate
        self.remoteID = note.remoteID
        self.createdDate = note.createdDate
        self.notes = note.notes?.compactMap{Note(careKitEntity: $0)}*/
        //return self
    }
    
    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit(fromCloud:Bool=true) throws -> OCKNote {
        encodingForParse = false
        let encoded = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(OCKNote.self, from: encoded)
        
        /*
        guard self.canConvertToCareKit() == true,
            let content = self.content,
              let title = self.title else {
            return nil
        }
        
        var note: OCKNote!
        if fromCloud{
            guard let decodedNote = decodedCareKitObject(self.author, title: title, content: content) else{
                print("Error in \(className). Couldn't decode entity \(self)")
                return nil
            }
            note = decodedNote
        }else{
            //Create bare Entity and replace contents with Parse contents
            note = OCKNote(author: self.author, title: self.title, content: self.content)
        }
        note.remoteID = self.remoteID
        note.asset = self.asset
        note.groupIdentifier = self.groupIdentifier
        note.tags = self.tags
        note.source = self.source
        note.userInfo = self.userInfo
        note.author = self.author
        note.remoteID = self.remoteID
        note.groupIdentifier = self.groupIdentifier
        note.asset = self.asset
        if let timeZone = self.timezone {
            note.timezone = timeZone
        }
        note.notes = self.notes?.compactMap{$0.convertToCareKit()}
        return note*/
    }
    
    func stamp(_ clock: Int){
        self.logicalClock = clock
        self.notes?.forEach{
            $0.logicalClock = self.logicalClock
        }
    }
    
    open class func replaceWithCloudVersion(_ local:inout [Note]?, cloud:[Note]?){
        guard let _ = local,
            let _ = cloud else {
            return
        }
        
        for (index,note) in local!.enumerated(){
            guard let cloudNote = cloud!.first(where: {$0.uuid == note.uuid}) else{
                continue
            }
            local![index] = cloudNote
        }
    }
    
    open class func fetchAndReplace(_ notes: [Note]?, completion: @escaping([Note]?)-> Void){
        let entitiesToFetch = notes?.compactMap{ entity -> UUID? in
            if entity.objectId == nil{
                return entity.uuid
            }
            return nil
        }
        
        guard let uuids = entitiesToFetch,
              var originalNotes = notes else {
            completion(nil)
            return
        }
        let query = Self.query(containedIn(key: kPCKObjectableUUIDKey, array: uuids))
        query.find(callbackQueue: .global(qos: .background)){ results in
            
            switch results {
            
            case .success(let localNotes):
                //var returnNotes = notes!
                for (index, note) in localNotes.enumerated(){
                    guard let replaceNote = localNotes.first(where: {$0.uuid == note.uuid}),
                          let updatedNote = try? Self.copyValues(from: note, to: replaceNote) else {
                        continue
                    }
                    
                    originalNotes[index] = updatedNote//Copy any changes
                }
                
                completion(originalNotes)
            case .failure(_):
                completion(nil)
            }
        }
    }
}

