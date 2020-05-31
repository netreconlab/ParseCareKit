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
        if clone{
            self.createdDate = note.createdDate
            self.notes = note.notes?.compactMap{Note(careKitEntity: $0)}
        }else{
            //Only copy this over if the Local Version is older than the Parse version
            if self.createdDate == nil {
                self.createdDate = note.createdDate
            } else if self.createdDate != nil && note.createdDate != nil{
                if note.createdDate! < self.createdDate!{
                    self.createdDate = note.createdDate
                }
            }
            self.notes = Note.updateIfNeeded(self.notes, careKit: note.notes)
        }
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
    
    open class func updateIfNeeded(_ parse:[Note]?, careKit: [OCKNote]?)->[Note]?{
        guard let parse = parse,
            let careKit = careKit else {
            return nil
        }
        let indexesToDelete = parse.count - careKit.count
        if indexesToDelete > 0{
            let stopIndex = parse.count - 1 - indexesToDelete
            for index in stride(from: parse.count-1, to: stopIndex, by: -1) {
                parse[index].deleteInBackground()
            }
        }
        var updatedNotes = [Note]()
        for (index,value) in careKit.enumerated(){
            let updated:Note?
            //Replace if currently in cloud or create a new one
            if index <= parse.count-1{
                updated = parse[index].copyCareKit(value, clone: true)
            }else{
                updated = Note(careKitEntity: value)
            }
            if updated != nil{
                updatedNotes.append(updated!)
            }
        }
        return updatedNotes
    }
}

