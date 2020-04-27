//
//  Note.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 NetReconLab. All rights reserved.
//

import Parse
import CareKit

public class Note : PFObject, PFSubclassing {

    //Parse only
    @NSManaged public var userUploadedToCloud:PFUser?
    @NSManaged public var userDeliveredToDestination:PFUser?
    
    //1 to 1 between Parse and CareStore
    @NSManaged public var asset:String?
    @NSManaged public var content:String
    @NSManaged public var groupIdentifier:String?
    @NSManaged public var notes:[Note]?
    @NSManaged public var source:String?
    @NSManaged public var tags:[String]?
    @NSManaged public var timezone:String
    @NSManaged public var title:String
    
    //Not 1 to 1 UserInfo fields on CareStore
    @NSManaged public var uuid:String //Maps to userInfo?[kPCKNoteUserInfoIDKey]
    
    //Not 1 to 1
    @NSManaged public var author:PFUser
    @NSManaged public var locallyCreatedAt:Date?
    @NSManaged public var locallyUpdatedAt:Date?
    
    //SOSDatabase info
    @NSManaged public var sosDeliveredToDestinationAt:Date? //When was the outcome posted D2D
    
    public static func parseClassName() -> String {
        return kPCKNoteClassKey
    }
}

extension Note {
    
    public convenience init(careKitEntity: OCKNote, storeManager: OCKSynchronizedStoreManager, completion: @escaping(PFObject?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, storeManager: storeManager, completion: completion)
    }
    
    func copyCareKit(_ note: OCKNote, storeManager: OCKSynchronizedStoreManager, completion: @escaping(Note?) -> Void){
        
        //Every note should be created with an ID
        guard let authorUUID = note.author else{
            completion(nil)
            return
        }
        storeManager.store.fetchAnyPatient(withID: authorUUID){
            result in
            
            switch result{
                
            case .success(let result):
                
                guard let patient = result as? OCKPatient,
                    let id = note.userInfo?[kPCKNoteUserInfoIDKey] else{
                    completion(nil)
                    return
                }
                self.author = PFUser()
                self.author.copyCareKit(patient, storeManager: storeManager){
                    _ in
                    
                    self.uuid = id
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
                        
                    Note.convertCareKitArrayToParse(note.notes, storeManager: storeManager){
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
    open func convertToCareKit()->OCKNote{
        
        var note = OCKNote(author: self.author.uuid, title: self.title, content: self.content)
        note.asset = self.asset
        note.groupIdentifier = self.groupIdentifier
        note.tags = self.tags
        note.source = self.source
        note.userInfo?[kPCKNoteUserInfoIDKey] = self.uuid
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
    
    class func convertCareKitArrayToParse(_ notes: [OCKNote]?, storeManager: OCKSynchronizedStoreManager, completion: @escaping([Note]?) -> Void){
        
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
            newNote.copyCareKit(note, storeManager: storeManager){
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

