//
//  Note.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKit

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
    @NSManaged public var authorOfNote:User
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
        
        guard let uuid = getUUIDFromCareKitEntity(note) else {
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
        self.authorOfNote = User(withoutDataWithObjectId: authorObjectId)
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
        let jsonString:String!
        do{
            let jsonData = try JSONEncoder().encode(tempEntity)
            jsonString = String(data: jsonData, encoding: .utf8)!
        }catch{
            print("Error \(error)")
            return nil
        }
        
        //Create bare CareKit entity from json
        let insertValue = "\"uuid\":\"\(self.uuid)\",\"createdDate\":\(createdDate),\"updatedDate\":\(updatedDate)"
        guard let modifiedJson = ParseCareKitUtility.insertReadOnlyKeys(insertValue, json: jsonString),
            let data = modifiedJson.data(using: .utf8) else{return nil}
        let entity:OCKNote!
        do {
            entity = try JSONDecoder().decode(OCKNote.self, from: data)
        }catch{
            print("Error in \(parseClassName).createDecodedEntity(). \(error)")
            return nil
        }
        return entity
    }
    
    open func getUUIDFromCareKitEntity(_ entity: OCKNote)->String?{
        let jsonString:String!
        do{
            let jsonData = try JSONEncoder().encode(entity)
            jsonString = String(data: jsonData, encoding: .utf8)!
        }catch{
            print("Error \(error)")
            return nil
        }
        let initialSplit = jsonString.split(separator: ",")
        let uuids = initialSplit.compactMap{ splitString -> String? in
            if splitString.contains("uuid"){
                let secondSplit = splitString.split(separator: ":")
                return String(secondSplit[1]).replacingOccurrences(of: "\"", with: "")
            }else{
                return nil
            }
        }
        
        if uuids.count == 0 {
            print("Error in \(parseClassName).getUUIDFromCareKitEntity(). The UUID is missing in \(jsonString!) for entity \(entity)")
            return nil
        }else if uuids.count > 1 {
            print("Warning in \(parseClassName).getUUIDFromCareKitEntity(). Found multiple UUID's, using first one in \(jsonString!) for entity \(entity)")
        }
        return uuids.first
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
            let updatedNote = parse[index].copyCareKit(value, clone: false)
            if updatedNote != nil{
                updatedNotes.append(updatedNote!)
            }
        }
        return updatedNotes
    }
}

