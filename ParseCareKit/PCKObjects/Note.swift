//
//  Note.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore

open class Note: PCKObject, PFSubclassing {

    @NSManaged public var content:String
    @NSManaged public var title:String
    @NSManaged public var author:String?
    
    public static func parseClassName() -> String {
        return kPCKNoteClassKey
    }
    
    public convenience init(careKitEntity: OCKNote) {
        self.init()
        _ = self.copyCareKit(careKitEntity, clone: true)
    }
    
    open override func copy(_ parse: PCKObject){
        super.copy(parse)
        guard let parse = parse as? Note else{return}
        self.content = parse.content
        self.author = parse.author
        self.title = parse.title
    }
    
    open func copyCareKit(_ note: OCKNote, clone:Bool) -> Note?{
        
        if let uuid = Note.getUUIDFromCareKitEntity(note){
            self.uuid = uuid
        }else{
            print("Warning in \(parseClassName).copyCareKit(). Entity missing uuid: \(note)")
        }
        
        self.groupIdentifier = note.groupIdentifier
        self.tags = note.tags
        self.source = note.source
        self.asset = note.asset
        self.timezoneIdentifier = note.timezone.abbreviation()!
        self.author = note.author
        self.userInfo = note.userInfo
        self.updatedDate = note.updatedDate
        self.remoteID = note.remoteID
        self.createdDate = note.createdDate
        self.notes = note.notes?.compactMap{Note(careKitEntity: $0)}
        return self
    }
    
    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit(fromCloud:Bool=true)->OCKNote?{
        
        var note: OCKNote!
        if fromCloud{
            guard let decodedNote = decodedCareKitObject(self.author, title: self.title, content: self.content) else{
                print("Error in \(parseClassName). Couldn't decode entity \(self)")
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
        if let timeZone = TimeZone(abbreviation: self.timezoneIdentifier){
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
            let query = Note.query() else {
            completion(nil)
            return
        }
        
        query.whereKey(kPCKObjectUUIDKey, containedIn: uuids)
        query.findObjectsInBackground(){
            (objects,error) in
            
            guard let fetchedNotes = objects as? [Note],
                let localNotes = notes else{
                completion(nil)
                return
            }
            var returnNotes = notes!
            for (index, note) in localNotes.enumerated(){
                guard let replaceNote = fetchedNotes.filter({$0.uuid == note.uuid}).first else {
                    continue
                }
                replaceNote.copy(note) //Copy any changes
                returnNotes[index] = replaceNote
            }
            
            completion(returnNotes)
        }
    }
}

