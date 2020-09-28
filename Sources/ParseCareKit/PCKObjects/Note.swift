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

open class Note: PCKObject {

    public var content:String?
    public var title:String?
    public var author:String?
    
    public static func className() -> String {
        return kPCKNoteClassKey
    }
    
    override init() {
        super.init()
    }

    public convenience init(careKitEntity: OCKNote) {
        self.init()
        _ = self.copyCareKit(careKitEntity)
    }
    
    public required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
    
    open override func copyCommonValues(from other: PCKObject){
        super.copyCommonValues(from: other)
        guard let other = other as? Note else{return}
        self.content = other.content
        self.author = other.author
        self.title = other.title
    }
    
    open func copyCareKit(_ note: OCKNote) -> Note?{
        
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
        self.notes = note.notes?.compactMap{Note(careKitEntity: $0)}
        return self
    }
    
    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit(fromCloud:Bool=true)->OCKNote? {
        
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
        if let timeZone = TimeZone(abbreviation: self.timezone!){
            note.timezone = timeZone
        }
        note.notes = self.notes?.compactMap{$0.convertToCareKit()}
        return note
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
            guard let cloudNote = cloud!.filter({$0.uuid == note.uuid}).first else{
                continue
            }
            local![index] = cloudNote
        }
    }
    
    open class func fetchAndReplace(_ notes: [Note]?, completion: @escaping([Note]?)-> Void){
        let entitiesToFetch = notes?.compactMap{ entity -> String? in
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
        let query = Self.query(containedIn(key: kPCKObjectCompatibleUUIDKey, array: uuids))
        query.find(callbackQueue: .global(qos: .background)){ results in
            
            switch results {
            
            case .success(let localNotes):
                //var returnNotes = notes!
                for (index, note) in localNotes.enumerated(){
                    guard let replaceNote = localNotes.filter({$0.uuid == note.uuid}).first else {
                        continue
                    }
                    replaceNote.copyCommonValues(from: note) //Copy any changes
                    originalNotes[index] = replaceNote
                }
                
                completion(originalNotes)
            case .failure(_):
                completion(nil)
            }
        }
    }
}

