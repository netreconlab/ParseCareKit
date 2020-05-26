//
//  Note.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore

open class Note: PFObject, PFSubclassing {

    //1 to 1 between Parse and CareStore
    @NSManaged public var asset:String?
    @NSManaged public var content:String
    @NSManaged public var groupIdentifier:String?
    @NSManaged public var notes:[Note]?
    @NSManaged public var source:String?
    @NSManaged public var tags:[String]?
    @NSManaged public var timezone:String
    @NSManaged public var title:String
    @NSManaged public var uuid:String
    @NSManaged public var clock:Int
    @NSManaged public var userInfo:[String:String]?
    @NSManaged public var author:String?
    
    //Not 1 to 1
    @NSManaged public var authorOfNote:Patient
    @NSManaged public var locallyCreatedAt:Date?
    @NSManaged public var locallyUpdatedAt:Date?
    
    public static func parseClassName() -> String {
        return kPCKNoteClassKey
    }
    
    public convenience init(careKitEntity: OCKNote) {
        self.init()
        _ = self.copyCareKit(careKitEntity, clone: true)
    }
    
    open func copyCareKit(_ note: OCKNote, clone:Bool) -> Note?{
        
        guard let uuid = Note.getUUIDFromCareKitEntity(note) else {
            return nil
        }
        
        self.uuid = uuid
        self.groupIdentifier = note.groupIdentifier
        self.tags = note.tags
        self.source = note.source
        self.asset = note.asset
        self.timezone = note.timezone.abbreviation()!
        self.author = note.author
        self.userInfo = note.userInfo
        self.locallyUpdatedAt = note.updatedDate
        if clone{
            self.locallyCreatedAt = note.createdDate
            self.notes = note.notes?.compactMap{Note(careKitEntity: $0)}
        }else{
            //Only copy this over if the Local Version is older than the Parse version
            if self.locallyCreatedAt == nil {
                self.locallyCreatedAt = note.createdDate
            } else if self.locallyCreatedAt != nil && note.createdDate != nil{
                if note.createdDate! < self.locallyCreatedAt!{
                    self.locallyCreatedAt = note.createdDate
                }
            }
            self.notes = Note.updateIfNeeded(self.notes, careKit: note.notes)
        }
        
        guard let authorObjectId = note.userInfo?[kPCKNoteUserInfoAuthorObjectIdKey] else{
            return nil
        }
        self.authorOfNote = Patient(withoutDataWithObjectId: authorObjectId)
        return self
    }
    
    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit()->OCKNote?{
        
        guard var note = createDecodedEntity() else{return nil}
        note.asset = self.asset
        note.groupIdentifier = self.groupIdentifier
        note.tags = self.tags
        note.source = self.source
        note.userInfo = self.userInfo
        note.author = self.author
        note.remoteID = self.objectId
        note.groupIdentifier = self.groupIdentifier
        note.asset = self.asset
        if let timeZone = TimeZone(abbreviation: self.timezone){
            note.timezone = timeZone
        }
        
        note.notes = self.notes?.compactMap{$0.convertToCareKit()}
        return note
    }
    
    func stamp(_ clock: Int){
        self.clock = clock
        self.notes?.forEach{
            $0.clock = self.clock
        }
    }
    
    open func createDecodedEntity()->OCKNote?{
        guard let createdDate = self.locallyCreatedAt?.timeIntervalSinceReferenceDate,
            let updatedDate = self.locallyUpdatedAt?.timeIntervalSinceReferenceDate else{
                print("Error in \(parseClassName).createDecodedEntity(). Missing either locallyCreatedAt \(String(describing: locallyCreatedAt)) or locallyUpdatedAt \(String(describing: locallyUpdatedAt))")
            return nil
        }
            
        let tempEntity = OCKNote(author: self.author, title: self.title, content: self.content)
        //Create bare CareKit entity from json
        guard var json = Note.getEntityAsJSONDictionary(tempEntity) else{return nil}
        json["uuid"] = self.uuid
        json["createdDate"] = createdDate
        json["updatedDate"] = updatedDate
        let entity:OCKNote!
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            entity = try JSONDecoder().decode(OCKNote.self, from: data)
        }catch{
            print("Error in \(parseClassName).createDecodedEntity(). \(error)")
            return nil
        }
        return entity
    }
    
    open class func getEntityAsJSONDictionary(_ entity: OCKNote)->[String:Any]?{
        let jsonDictionary:[String:Any]
        do{
            let data = try JSONEncoder().encode(entity)
            jsonDictionary = try JSONSerialization.jsonObject(with: data, options: []) as! [String:Any]
        }catch{
            print("Error in Note.getEntityAsJSONDictionary(). \(error)")
            return nil
        }
        
        return jsonDictionary
    }
    
    open class func getUUIDFromCareKitEntity(_ entity: OCKNote)->String?{
        guard let json = Note.getEntityAsJSONDictionary(entity) else{return nil}
        return json["uuid"] as? String
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

