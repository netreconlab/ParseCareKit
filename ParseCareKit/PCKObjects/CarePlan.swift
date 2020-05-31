//
//  CarePlan.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore


open class CarePlan: PCKVersionedObject, PCKRemoteSynchronized {

    @NSManaged private var patient:Patient?
    @NSManaged private var patientUUIDString:String?
    @NSManaged public var title:String
    
    public var patientUUID:UUID? {
        get {
            if patient != nil{
                return UUID(uuidString: patient!.uuid)
            }else if patientUUIDString != nil {
                return UUID(uuidString: patientUUIDString!)
            }else{
                return nil
            }
        }
        set{
            patientUUIDString = newValue?.uuidString
            if newValue?.uuidString != patient?.uuid{
                patient = nil
            }
        }
    }
    
    public var currentPatient: Patient?{
        get{
            return patient
        }
        set{
            patient = newValue
            patientUUIDString = newValue?.uuid
        }
    }
    
    public static func parseClassName() -> String {
        return kPCKCarePlanClassKey
    }
    
    public convenience init(careKitEntity: OCKAnyCarePlan, completion: @escaping(PCKObject?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, clone: true, completion: completion)
    }
    
    open func new() -> PCKSynchronized {
        return CarePlan()
    }
    
    open func new(with careKitEntity: OCKEntity, completion: @escaping(PCKSynchronized?)-> Void){
        
        switch careKitEntity {
        case .carePlan(let entity):
            let newClass = CarePlan()
            newClass.copyCareKit(entity, clone: true){
                _ in
                completion(newClass)
            }
        default:
            print("Error in \(parseClassName).new(with:). The wrong type of entity was passed \(careKitEntity)")
            completion(nil)
        }
    }
    
    public func addToCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current() else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        let query = CarePlan.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: self.uuid)
        query.includeKeys([kPCKCarePlanPatientKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.getFirstObjectInBackground(){
            (object, error) in
            
            guard let foundObject = object as? CarePlan else{
                guard let parseError = error as NSError? else{
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).addToCloud(). \(String(describing: error?.localizedDescription))")
                    completion(false,error)
                    return
                }
                
                switch parseError.code{
                    case 1,101: //1 - this column hasn't been added. 101 - Query returned no results
                        self.save(self, completion: completion)
                default:
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).addToCloud(). \(String(describing: error?.localizedDescription))")
                    completion(false,error)
                }
                return
            }
            
            //Maybe this needs to be updated instead
            self.compareUpdate(foundObject, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
        }
    }
    
    public func updateCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current(),
            let carePlanUUID = UUID(uuidString: self.uuid) else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if this entity is already in the Cloud, but not matched locally
        let query = CarePlan.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: carePlanUUID.uuidString)
        query.includeKeys([kPCKCarePlanPatientKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.getFirstObjectInBackground(){
            (object, error) in
            guard let foundObject = object as? CarePlan else{
                guard let parseError = error as NSError? else{
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).updateCloud(). \(String(describing: error?.localizedDescription))")
                    completion(false,error)
                    return
                }
                
                switch parseError.code{
                    case 1,101: //1 - this column hasn't been added. 101 - Query returned no results
                        self.save(self, completion: completion)
                default:
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).updateCloud(). \(String(describing: error?.localizedDescription))")
                    completion(false,error)
                }
                return
            }
            self.compareUpdate(foundObject, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
            
        }
    }
    
    public func deleteFromCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        //Handled with update, marked for deletion
        completion(true,nil)
        /*
        guard let _ = PFUser.current() else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
       
        //Get latest item from the Cloud to compare against
        let query = CarePlan.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: self.uuid)
        query.getFirstObjectInBackground{
            (object, error) in
            guard let foundObject = object as? CarePlan else{
                completion(false,error)
                return
            }
            
            self.compareUpdate(foundObject, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
        }*/
    }
    
    public func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        let query = CarePlan.query()!
        query.whereKey(kPCKObjectClockKey, greaterThanOrEqualTo: localClock)
        query.includeKeys([kPCKCarePlanPatientKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.findObjectsInBackground{ (objects,error) in
            guard let carePlans = objects as? [CarePlan] else{
                let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
                guard let error = error as NSError?,
                    let errorDictionary = error.userInfo["error"] as? [String:Any],
                    let reason = errorDictionary["routine"] as? String else {
                        mergeRevision(revision)
                        return
                }
                //If the query was looking in a column that wasn't a default column, it will return nil if the table doesn't contain the custom column
                if reason == "errorMissingColumn"{
                    //Saving the new item with the custom column should resolve the issue
                    print("Warning, table CarePlan either doesn't exist or is missing the column \(kPCKObjectClockKey). It should be fixed during the first sync of an Outcome...")
                }
                mergeRevision(revision)
                return
            }
            let pulled = carePlans.compactMap{$0.convertToCareKit()}
            let entities = pulled.compactMap{OCKEntity.carePlan($0)}
            let revision = OCKRevisionRecord(entities: entities, knowledgeVector: cloudVector)
            mergeRevision(revision)
        }
    }
    
    public func pushRevision(_ overwriteRemote: Bool, cloudClock: Int, completion: @escaping (Error?) -> Void){
        self.logicalClock = cloudClock //Stamp Entity
        
        self.addToCloud(true, overwriteRemote: overwriteRemote){
            (success,error) in
            if success{
                completion(nil)
            }else{
                completion(error)
            }
        }
    }
    
    open override func copy(_ parse: PCKObject){
        super.copy(parse)
        guard let parse = parse as? CarePlan else{return}
        self.currentPatient = parse.currentPatient
        self.patientUUID = parse.patientUUID
        self.title = parse.title
    }
    
    open func copyCareKit(_ carePlanAny: OCKAnyCarePlan, clone: Bool, completion: @escaping(CarePlan?) -> Void){
        
        guard let _ = PFUser.current(),
            let carePlan = carePlanAny as? OCKCarePlan else{
            completion(nil)
            return
        }
        
        if let uuid = carePlan.uuid?.uuidString{
            self.uuid = uuid
        }else{
            print("Warning in \(parseClassName). Entity missing uuid: \(carePlan)")
        }
        self.entityId = carePlan.id
        self.deletedDate = carePlan.deletedDate
        self.title = carePlan.title
        self.groupIdentifier = carePlan.groupIdentifier
        self.tags = carePlan.tags
        self.source = carePlan.source
        self.asset = carePlan.asset
        self.timezoneIdentifier = carePlan.timezone.abbreviation()!
        self.effectiveDate = carePlan.effectiveDate
        self.updatedDate = carePlan.updatedDate
        self.userInfo = carePlan.userInfo
        if clone{
            self.createdDate = carePlan.createdDate
            self.notes = carePlan.notes?.compactMap{Note(careKitEntity: $0)}
        }else{
            //Only copy this over if the Local Version is older than the Parse version
            if self.createdDate == nil {
                self.createdDate = carePlan.createdDate
            } else if self.createdDate != nil && carePlan.createdDate != nil{
                if carePlan.createdDate! < self.createdDate!{
                    self.createdDate = carePlan.createdDate
                }
            }
            self.notes = Note.updateIfNeeded(self.notes, careKit: carePlan.notes)
        }
        self.remoteID = carePlan.remoteID
        
        self.patientUUID = carePlan.patientUUID
        self.previousVersionUUID = carePlan.previousVersionUUID
        self.nextVersionUUID = carePlan.nextVersionUUID
        
        //Link versions and related classes
        self.findCarePlan(self.previousVersionUUID){
            previousCarePlan in
            
            self.previous = previousCarePlan
            
            self.findCarePlan(self.nextVersionUUID){
                nextCarePlan in
                
                self.next = nextCarePlan
                
                guard let patientUUID = self.patientUUID else{
                    //Finished if there's no CarePlan, otherwise see if it's in the cloud
                    completion(self)
                    return
                }
                
                self.findPatient(patientUUID){
                    patient in
                    
                    self.patient = patient
                    completion(self)
                }
            }
        }
    }
    
    //Note that CarePlans have to be saved to CareKit first in order to properly convert to CareKit
    open func convertToCareKit(fromCloud:Bool=true)->OCKCarePlan?{
        
        //Create bare Entity and replace contents with Parse contents
        var carePlan = OCKCarePlan(id: self.entityId, title: self.title, patientUUID: self.patientUUID)
        
        if fromCloud{
            guard let decodedCarePlan = decodedCareKitObject(carePlan) else {
                print("Error in \(parseClassName). Couldn't decode entity \(self)")
                return nil
            }
            carePlan = decodedCarePlan
        }
        carePlan.remoteID = self.remoteID
        carePlan.groupIdentifier = self.groupIdentifier
        carePlan.tags = self.tags
        if let effectiveDate = self.effectiveDate{
            carePlan.effectiveDate = effectiveDate
        }
        carePlan.source = self.source
        carePlan.groupIdentifier = self.groupIdentifier
        carePlan.asset = self.asset
        carePlan.notes = self.notes?.compactMap{$0.convertToCareKit()}
        carePlan.userInfo = self.userInfo
        if let timeZone = TimeZone(abbreviation: self.timezoneIdentifier){
            carePlan.timezone = timeZone
        }
        return carePlan
    }
}
