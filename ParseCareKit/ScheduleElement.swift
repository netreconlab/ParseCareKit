//
//  ScheduleElement.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/18/20.
//  Copyright © 2020 NetReconLab. All rights reserved.
//

import Parse
import CareKit

open class ScheduleElement: PFObject, PFSubclassing {

    //1 to 1 between Parse and CareStore
    /*@NSManaged public var asset:String?
    @NSManaged public var groupIdentifier:String?
    
    
    @NSManaged public var locallyCreatedAt:Date?
    @NSManaged public var locallyUpdatedAt:Date?
    @NSManaged public var notes:[Note]?
    
    @NSManaged public var source:String?
    @NSManaged public var tags:[String]?
    
    @NSManaged public var timezone:String
    
    */
    @NSManaged public var elements:[ScheduleElement]
    @NSManaged public var end:Date?
    @NSManaged public var interval:[String:Any]
    @NSManaged public var start:Date
    @NSManaged public var text:String?
    @NSManaged public var targetValues:[OutcomeValue]
    
    //UserInfo fields on CareStore
    //@NSManaged public var uuid:String //maps to id
    
    public static func parseClassName() -> String {
        return kAScheduleElementClassKey
    }
    
    public convenience init(careKitEntity:OCKScheduleElement, storeManager: OCKSynchronizedStoreManager, completion: @escaping(ScheduleElement?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, storeManager: storeManager, completion: completion)
    }
    
    func copyCareKit(_ scheduleElement: OCKScheduleElement, storeManager: OCKSynchronizedStoreManager, completion: @escaping(ScheduleElement)->Void){
        
        self.text = scheduleElement.text
        self.interval = CareKitInterval.era.convertToDictionary(scheduleElement.interval)
        self.start = scheduleElement.start
        self.end = scheduleElement.end
        
        OutcomeValue.convertCareKitArrayToParse(scheduleElement.targetValues, storeManager: storeManager){
            returnedValues in
            
            self.targetValues = returnedValues
            completion(self)
            /*
            ScheduleElement.convertCareKitArrayToParse(scheduleElement.elements, storeManager: storeManager){ returnedElements in
                self.elements = returnedElements
                completion(self)
            }*/
            
        }
        
        /*
        if let id = scheduleElement.userInfo?[kPCKScheduleElementUserInfoIDKey] {
            self.uuid = id
        }
        self.groupIdentifier = scheduleElement.groupIdentifier
        self.tags = scheduleElement.tags
        self.source = scheduleElement.source
        self.asset = scheduleElement.asset
        self.timezone = scheduleElement.timezone.abbreviation()!
        
        self.locallyUpdatedAt = scheduleElement.updatedDate
        
        //Only copy this over if the Local Version is older than the Parse version
        if self.locallyCreatedAt == nil {
            self.locallyCreatedAt = scheduleElement.createdDate
        } else if self.locallyCreatedAt != nil && scheduleElement.createdDate != nil{
            if scheduleElement.createdDate! < self.locallyCreatedAt!{
                self.locallyCreatedAt = scheduleElement.createdDate
            }
        }
        
        Note.convertCareKitArrayToParse(scheduleElement.notes, storeManager: storeManager){
            copiedNotes in
            self.notes = copiedNotes
            
            OutcomeValue.convertCareKitArrayToParse(scheduleElement.targetValues, storeManager: storeManager){
                returnedValues in
                
                self.targetValues = returnedValues
                completion(self)
            }
        }*/
        
        /*
        if let notes = scheduleElement.notes {
            
            var noteIDs = [String]()
            notes.forEach{
                //Ignore notes who don't have a ID
                guard let noteID = $0.userInfo?[kPCKNoteUserInfoIDKey] else{
                    return
                }
                
                noteIDs.append(noteID)
            }
        }*/
        
    }
    
    //Note that CarePlans have to be saved to CareKit first in order to properly convert to CareKit
    open func convertToCareKit()->OCKScheduleElement{

        let interval = CareKitInterval.era.convertToDateComponents(self.interval)
        
        var scheduleElement = OCKScheduleElement(start: self.start, end: self.end, interval: interval)
        scheduleElement.targetValues = self.targetValues.compactMap{$0.convertToCareKit()}
        scheduleElement.text = self.text
        /*
        scheduleElement.groupIdentifier = self.groupIdentifier
        scheduleElement.tags = self.tags
        scheduleElement.source = self.source
        //scheduleElement.userInfo?[kPCKCarePlanAuthorIDKey] = self.patient.id
        scheduleElement.groupIdentifier = self.groupIdentifier
        scheduleElement.asset = self.asset
        if let timeZone = TimeZone(abbreviation: self.timezone){
            scheduleElement.timezone = timeZone
        }
        
        scheduleElement.remoteID = self.objectId
        scheduleElement.notes = self.notes?.compactMap{$0.convertToCareKit()}
        */
        return scheduleElement
        /*
        guard let queryTarget = OutcomeValue.query()/*,
            let queryElements = ScheduleElement.query()*/ else{
                completion(nil)
                return
        }
        
        queryTarget.whereKey(kPCKOutcomeValueUserInfoIDKey, containedIn: self.targetValues)
        queryTarget.findObjectsInBackground{
            (objects, error) in
            
            guard let values = objects as? [OutcomeValue] else{
                completion(nil)
                return
            }
            
            scheduleElement.targetValues = values.compactMap{$0.convertToCareKit()}
            
            guard let noteIDs = self.notes,
                let query = ScheduleElement.query() else{
                completion(scheduleElement)
                return
            }
            
            query.whereKey(kAScheduleElementsNotesKey, containedIn: noteIDs)
            query.findObjectsInBackground{
            
                (objects,error) in
                
                guard let parseNotes = objects as? [Note] else{
                    completion(scheduleElement)
                    return
                }
                
                scheduleElement.notes = [OCKNote]()
                
                for (index,parseNote) in parseNotes.enumerated(){
                    
                    parseNote.convertToCareKit{
                        (potentialCareKitNote) in
                        
                        guard let careKitNote = potentialCareKitNote else{
                            if index == (parseNotes.count-1){
                                completion(scheduleElement)
                            }
                            
                            return
                        }
                        
                        scheduleElement.notes!.append(careKitNote)
                        
                        if index == (parseNotes.count-1){
                            completion(scheduleElement)
                        }
                    }
                }
            }*/
            /*
            queryTarget.whereKey(kPCKOutcomeValueUserInfoIDKey, containedIn: self.elements)
            queryTarget.findObjectsInBackground{
                (elementObjects, error) in
                
                guard let elements = elementObjects as? [ScheduleElement] else{
                    return
                }
                
                for (index,element) in elements.enumerated(){
                    
                    element.convertToCareKit{
                        (converted) in
                        
                        guard let convertedElement = converted else{
                            return
                        }
                        
                        scheduleElement.elements.append(convertedElement)
                        
                    }
                    
                    
                }
                
            }
            
        }*/
        
    }
    
    class func convertCareKitArrayToParse(_ values: [OCKScheduleElement], storeManager: OCKSynchronizedStoreManager, completion: @escaping([ScheduleElement]) -> Void){
        
        var returnValues = [ScheduleElement]()
        
        if values.isEmpty{
            completion(returnValues)
            return
        }
        
        for (index,value) in values.enumerated(){
    
            let _ = ScheduleElement(careKitEntity: value, storeManager: storeManager){
                newElement in
                
                guard let newScheduleElement = newElement as? ScheduleElement else{
                    return
                }
                newScheduleElement.copyCareKit(value, storeManager: storeManager){
                    (valueCopied) in
                
                    returnValues.append(valueCopied)
                    
                    //copyCareKit is async, so we need it to tell us when it's finished
                    if index == (values.count-1){
                        completion(returnValues)
                    }
                }
            }
            
        }
    }
}
