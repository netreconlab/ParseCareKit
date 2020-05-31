//
//  Patients.swift
//  ParseCareKit
//
//  Created by Corey Baker on 10/5/19.
//  Copyright © 2019 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore


open class Patient: PCKVersionedObject, PCKRemoteSynchronized {
    
    @NSManaged public var alergies:[String]?
    @NSManaged public var birthday:Date?
    @NSManaged public var name:[String:String]
    @NSManaged public var sex:String?
    
    public static func parseClassName() -> String {
        return kPCKPatientClassKey
    }
    
    public convenience init(careKitEntity: OCKAnyPatient, completion: @escaping(PCKObject?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, clone: true, completion: completion)
    }
    
    open func new() -> PCKSynchronized {
        return Patient()
    }
    
    open func new(with careKitEntity: OCKEntity, completion: @escaping(PCKSynchronized?)-> Void){
    
        switch careKitEntity {
        case .patient(let entity):
            let newClass = Patient()
            newClass.copyCareKit(entity, clone: true){
                _ in
                completion(newClass)
            }
        default:
            print("Error in \(parseClassName).new(with:). The wrong type of entity was passed \(careKitEntity)")
            completion(nil)
        }
    }
    
    open func addToCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current(),
            let patientUUID = UUID(uuidString: self.uuid) else{
            return
        }

        //Check to see if already in the cloud
        let query = Patient.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: patientUUID.uuidString)
        query.includeKeys([kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.getFirstObjectInBackground(){
            (object, error) in
           
            guard let foundObject = object as? Patient else{
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
    
    open func updateCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current(),
            let patientUUID = UUID(uuidString: self.uuid) else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if this entity is already in the Cloud, but not paired locally
        let query = Patient.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: patientUUID.uuidString)
        query.includeKeys([kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.getFirstObjectInBackground(){
            (object, error) in
            
            guard let foundObject = object as? Patient else{
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
            
            self.compareUpdate(foundObject, usingKnowledgeVector:usingKnowledgeVector, overwriteRemote:overwriteRemote, completion: completion)
        }
    }
    
    
    
    open func deleteFromCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        //Handled with update, marked for deletion
        completion(true,nil)
        /*
        guard let _ = PFUser.current(),
            let patientUUID = UUID(uuidString: self.uuid) else{
            return
        }
        
        //Get latest item from the Cloud to compare against
        let query = Patient.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: patientUUID)
        query.includeKeys([kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.getFirstObjectInBackground(){
            (objects, error) in
            
            guard let foundObject = objects as? Patient else{
                completion(false,error)
                return
            }
            
            self.compareUpdate(foundObject, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
        }*/
    }
    
    public func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        let query = Patient.query()!
        query.whereKey(kPCKObjectClockKey, greaterThanOrEqualTo: localClock)
        query.includeKeys([kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.findObjectsInBackground{ (objects,error) in
            guard let carePlans = objects as? [Patient] else{
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
                    print("Warning, table Patient either doesn't exist or is missing the column \(kPCKObjectClockKey). It should be fixed during the first sync of an Outcome...")
                }
                mergeRevision(revision)
                return
            }
            let pulled = carePlans.compactMap{$0.convertToCareKit()}
            let entities = pulled.compactMap{OCKEntity.patient($0)}
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
        guard let parse = parse as? Patient else{return}
        self.name = parse.name
        self.birthday = parse.birthday
        self.sex = parse.sex
        self.alergies = parse.alergies
    }
    
    open func copyCareKit(_ patientAny: OCKAnyPatient, clone:Bool, completion: @escaping(Patient?) -> Void){
        
        guard let _ = PFUser.current(),
            let patient = patientAny as? OCKPatient else{
                completion(nil)
            return
        }
        
        if let uuid = patient.uuid?.uuidString {
            self.uuid = uuid
        }else{
            print("Warning in \(parseClassName). Entity missing uuid: \(patient)")
        }
        self.entityId = patient.id
        self.name = CareKitPersonNameComponents.familyName.convertToDictionary(patient.name)
        self.birthday = patient.birthday
        self.sex = patient.sex?.rawValue
        self.effectiveDate = patient.effectiveDate
        self.deletedDate = patient.deletedDate
        self.updatedDate = patient.updatedDate
        self.timezoneIdentifier = patient.timezone.abbreviation()!
        self.userInfo = patient.userInfo
        self.remoteID = patient.remoteID
        self.alergies = patient.allergies
        if clone{
            self.createdDate = patient.createdDate
            self.notes = patient.notes?.compactMap{Note(careKitEntity: $0)}
        }else{
            //Only copy this over if the Local Version is older than the Parse version
            if self.createdDate == nil {
                self.createdDate = patient.createdDate
            } else if self.createdDate != nil && patient.createdDate != nil{
                if patient.createdDate! < self.createdDate!{
                    self.createdDate = patient.createdDate
                }
            }
            self.notes = Note.updateIfNeeded(self.notes, careKit: patient.notes)
        }
        
        self.previousVersionUUID = patient.previousVersionUUID
        self.nextVersionUUID = patient.nextVersionUUID
        
        //Link versions and related classes
        self.findPatient(self.previousVersionUUID){
            previousPatient in
            
            self.previous = previousPatient
            
            self.findPatient(self.nextVersionUUID){
                nextPatient in
               
                self.next = nextPatient
                completion(self)
            }
        }
    }
    
    open func convertToCareKit(fromCloud:Bool=true)->OCKPatient?{
        
        let nameComponents = CareKitPersonNameComponents.familyName.convertToPersonNameComponents(name)
        var patient = OCKPatient(id: self.entityId, name: nameComponents)

        if fromCloud{
            guard let decodedPatient = decodedCareKitObject(patient) else{
                print("Error in \(parseClassName). Couldn't decode entity \(self)")
                return nil
            }
            patient = decodedPatient
        }
        
        if let effectiveDate = self.effectiveDate{
            patient.effectiveDate = effectiveDate
        }
        patient.birthday = self.birthday
        patient.allergies = self.alergies
        patient.groupIdentifier = self.groupIdentifier
        patient.tags = self.tags
        patient.source = self.source
        patient.asset = self.asset
        patient.userInfo = self.userInfo
        patient.notes = self.notes?.compactMap{$0.convertToCareKit()}
        patient.remoteID = self.remoteID
        if let timeZone = TimeZone(abbreviation: self.timezoneIdentifier){
            patient.timezone = timeZone
        }
        if let sex = self.sex{
            patient.sex = OCKBiologicalSex(rawValue: sex)
        }
        return patient
    }
}
