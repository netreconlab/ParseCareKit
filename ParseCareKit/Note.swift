//
//  Note.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 NetReconLab. All rights reserved.
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
    
    //Not 1 to 1 UserInfo fields on CareStore
    @NSManaged public var entityId:String //Maps to userInfo?[kPCKNoteUserInfoEntityIdKey]
    
    //Not 1 to 1
    @NSManaged public var author:User
    @NSManaged public var locallyCreatedAt:Date?
    @NSManaged public var locallyUpdatedAt:Date?
    
    public static func parseClassName() -> String {
        return kPCKNoteClassKey
    }
    
    public convenience init(careKitEntity: OCKNote, store: OCKAnyStoreProtocol, completion: @escaping(Note?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, store: store, completion: completion)
    }
    
    open func copyCareKit(_ note: OCKNote, store: OCKAnyStoreProtocol, completion: @escaping(Note?) -> Void){
        
        guard let uuid = getUUIDFromCareKit(note) else {
            completion(nil)
            return
        }
        
        //Every note should be created with an ID
        guard let authorUUID = note.author else{
            completion(nil)
            return
        }
        store.fetchAnyPatient(withID: authorUUID){
            result in
            
            switch result{
                
            case .success(let result):
                
                guard let patient = result as? OCKPatient,
                    let id = note.userInfo?[kPCKNoteUserInfoEntityIdKey] else{
                    completion(nil)
                    return
                }
                self.author = User()
                self.author.copyCareKit(patient, store: store){
                    _ in
                    self.uuid = uuid
                    self.entityId = id
                    self.groupIdentifier = note.groupIdentifier
                    self.tags = note.tags
                    self.source = note.source
                    self.asset = note.asset
                    self.timezone = note.timezone.abbreviation()!
                    self.locallyUpdatedAt = note.updatedDate
                    
                    //Only copy this over if the Local Version is older than the Parse version
                    if self.locallyCreatedAt == nil {
                        self.locallyCreatedAt = note.createdDate
                    } else if self.locallyCreatedAt != nil && note.createdDate != nil{
                        if note.createdDate! < self.locallyCreatedAt!{
                            self.locallyCreatedAt = note.createdDate
                        }
                    }
                        
                    Note.convertCareKitArrayToParse(note.notes, store: store){
                        copiedNotes in
                        self.notes = copiedNotes
                        completion(self)
                    }
                }
                
            case .failure(_):
                completion(nil)
            }
        }
        
        
            /*
            if let notes = note.notes {
                self.notes = [String]()
               
                for (index,note) in notes.enumerated(){
            
                    let newNote = Note()
                    newNote.copyCareKit(note){
                        (noteFound) in
                        
                        guard let noteToAppend = noteFound else{
                            return
                        }
                        
                        self.notes!.append(noteToAppend.id)
                        
                        //Finished when all notes are iterated through
                        if index == (notes.count-1){
                            completion(self)
                        }
                    }
                }
            }else{
                completion(self)
            }
            
            completion(self)
 */
        
    }
    
    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit()->OCKNote?{
        
        guard var note = createDeserializedEntity() else{return nil}
        note.asset = self.asset
        note.groupIdentifier = self.groupIdentifier
        note.tags = self.tags
        note.source = self.source
        note.userInfo?[kPCKNoteUserInfoEntityIdKey] = self.entityId
        note.remoteID = self.objectId
        note.groupIdentifier = self.groupIdentifier
        note.asset = self.asset
        if let timeZone = TimeZone(abbreviation: self.timezone){
            note.timezone = timeZone
        }
        
        note.notes = self.notes?.compactMap{$0.convertToCareKit()}
        
        return note
        /*
        guard let noteIDs = self.notes,
            let query = Note.query() else{
            completion(note)
            return
        }
    
        query.whereKey(kPCKNoteNotesKey, containedIn: noteIDs)
        query.findObjectsInBackground{
        
            (objects,error) in
            
            guard let parseNotes = objects as? [Note] else{
                completion(note)
                return
            }
            
            note.notes = [OCKNote]()
            
            for (index,parseNote) in parseNotes.enumerated(){
                
                parseNote.convertToCareKit{
                    (potentialCareKitNote) in
                    
                    guard let careKitNote = potentialCareKitNote else{
                        if index == (parseNotes.count-1){
                            completion(note)
                        }
                        
                        return
                    }
                    
                    note.notes!.append(careKitNote)
                    
                    if index == (parseNotes.count-1){
                        completion(note)
                    }
                }
            }
        }*/
    }
    
    open func createDeserializedEntity()->OCKNote?{
        guard let createdDate = self.locallyCreatedAt?.timeIntervalSinceReferenceDate,
            let updatedDate = self.locallyUpdatedAt?.timeIntervalSinceReferenceDate else{
                print("Error in \(parseClassName).createDeserializedEntity(). Missing either locallyCreatedAt \(String(describing: locallyCreatedAt)) or locallyUpdatedAt \(String(describing: locallyUpdatedAt))")
            return nil
        }
            
        let tempEntity = OCKNote(author: self.author.entityId, title: self.title, content: self.content)
        let jsonString:String!
        do{
            let jsonData = try JSONEncoder().encode(tempEntity)
            jsonString = String(data: jsonData, encoding: .utf8)!
        }catch{
            print("Error \(error)")
            return nil
        }
        
        //Create bare CareKit entity from json
        let insertValue = "\"uuid\":\"\(self.entityId)\",\"createdDate\":\(createdDate),\"updatedDate\":\(updatedDate)"
        guard let modifiedJson = ParseCareKitUtility.insertReadOnlyKeys(insertValue, json: jsonString),
            let data = modifiedJson.data(using: .utf8) else{return nil}
        let entity:OCKNote!
        do {
            entity = try JSONDecoder().decode(OCKNote.self, from: data)
        }catch{
            print("Error in \(parseClassName).createDeserializedEntity(). \(error)")
            return nil
        }
        return entity
    }
    
    open func getUUIDFromCareKit(_ entity: OCKNote)->String?{
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
            print("Error in \(parseClassName).getUUIDFromCareKit(). The UUID is missing in \(jsonString!) for entity \(entity)")
            return nil
        }else if uuids.count > 1 {
            print("Warning in \(parseClassName).getUUIDFromCareKit(). Found multiple UUID's, using first one in \(jsonString!) for entity \(entity)")
        }
        return uuids.first
    }
    
    open class func convertCareKitArrayToParse(_ notes: [OCKNote]?, store: OCKAnyStoreProtocol, completion: @escaping([Note]?) -> Void){
        
        guard let careKitNotes = notes else{
            completion(nil)
            return
        }
        
        if careKitNotes.isEmpty{
            completion(nil)
            return
        }
        
        var returnNotes = [Note]()
        
        for (index,note) in careKitNotes.enumerated(){
    
            let newNote = Note()
            newNote.copyCareKit(note, store: store){
                (noteFound) in
                
                guard let noteToAppend = noteFound else{
                    print("Error in User.copyCareKit. This should never! Set breakpoint here and see what's going on. Note with issue \(note)")
                    completion(returnNotes)
                    return
                }
                
                returnNotes.append(noteToAppend)
                
                //copyCareKit is async, so we need it to tell us when it's finished
                if index == (careKitNotes.count-1){
                    completion(returnNotes)
                }
            }
        }
    }
}

