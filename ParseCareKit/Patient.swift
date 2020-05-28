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
    
    public convenience init(careKitEntity: OCKAnyPatient, store: OCKAnyStoreProtocol, completion: @escaping(PCKObject?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, clone: true, store: store, completion: completion)
    }
    
    public func new() -> PCKRemoteSynchronized {
        return CarePlan()
    }
    
    public func new(with careKitEntity: OCKEntity, store: OCKStore, completion: @escaping(PCKRemoteSynchronized?)-> Void){
        switch careKitEntity {
        case .patient(let entity):
            self.copyCareKit(entity, clone: true, store: store, completion: completion)
        default:
            print("Error in \(parseClassName).new(with:). The wrong type of entity was passed \(careKitEntity)")
        }
    }
    
    open func addToCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current(),
            let patientUUID = UUID(uuidString: self.uuid) else{
            return
        }

        //Check to see if already in the cloud
        let query = Patient.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: patientUUID.uuidString)
        query.includeKeys([kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.findObjectsInBackground(){
            (objects, parseError) in
            guard let foundObjects = objects else{
                guard let error = parseError as NSError?,
                    let errorDictionary = error.userInfo["error"] as? [String:Any],
                    let reason = errorDictionary["routine"] as? String else {
                        completion(false,parseError)
                        return
                }
                //If the query was looking in a column that wasn't a default column, it will return nil if the table doesn't contain the custom column
                if reason == "errorMissingColumn"{
                    //Saving the new item with the custom column should resolve the issue
                    print("This table '\(self.parseClassName)' either doesn't exist or is missing a column. Attempting to create the table and add new data to it...")
                    //Make wallclock entities compatible with KnowledgeVector by setting it's initial clock to 0
                    if !usingKnowledgeVector{
                        self.logicalClock = 0
                    }
                    Patient.saveAndCheckRemoteID(self, store: store, completion: completion)
                }else{
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.parseClassName).addToCloud(). \(error.localizedDescription)")
                    completion(false,error)
                }
                return
            }
            //If object already in the Cloud, exit
            if foundObjects.count > 0{
                //Maybe this needs to be updated instead
                self.updateCloud(store, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
            }else{
                //Make wallclock level entities compatible with KnowledgeVector by setting it's initial clock to 0
                if !usingKnowledgeVector{
                    self.logicalClock = 0
                }
                Patient.saveAndCheckRemoteID(self, store: store, completion: completion)
            }
        }
    }
    
    open func updateCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current(),
            let store = store as? OCKStore,
            let patientUUID = UUID(uuidString: self.uuid) else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        var careKitQuery = OCKPatientQuery()
        careKitQuery.uuids = [patientUUID]
        
        store.fetchPatients(query: careKitQuery, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let patients):
                guard let patient = patients.first else{
                    completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
                    return
                }
                guard let remoteID = patient.remoteID else{
                    
                    //Check to see if this entity is already in the Cloud, but not paired locally
                    let query = Patient.query()!
                    query.whereKey(kPCKObjectUUIDKey, equalTo: patientUUID.uuidString)
                    query.includeKeys([kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
                    query.getFirstObjectInBackground(){
                        (object, error) in
                        
                        guard let foundObject = object as? Patient else{
                            completion(false,error)
                            return
                        }
                        self.compareUpdate(patient, parse: foundObject, store: store, usingKnowledgeVector:usingKnowledgeVector, overwriteRemote:overwriteRemote, completion: completion)
                    }
                    return
                }
                
                //Get latest item from the Cloud to compare against
                let query = Patient.query()!
                query.whereKey(kPCKParseObjectIdKey, equalTo: remoteID)
                query.includeKeys([kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
                query.getFirstObjectInBackground(){
                    (object, error) in
                    
                    guard let foundObject = object as? Patient else{
                        completion(false,error)
                        return
                    }
                    self.compareUpdate(patient, parse: foundObject, store: store, usingKnowledgeVector:usingKnowledgeVector, overwriteRemote:overwriteRemote, completion: completion)
                }
            case .failure(let error):
                print("Error in Contact.addToCloud(). \(error)")
                completion(false,error)
            }
        }
    }
    
    
    
    open func deleteFromCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current(),
            let store = store as? OCKStore,
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
            self.compareDelete(foundObject, store: store, completion: completion)
        }
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
    
    public func pushRevision(_ store: OCKStore, overwriteRemote: Bool, cloudClock: Int, completion: @escaping (Error?) -> Void){
        
        self.logicalClock = cloudClock //Stamp Entity
        if self.deletedDate == nil{
            self.addToCloud(store, usingKnowledgeVector: true, overwriteRemote: overwriteRemote){
                (success,error) in
                if success{
                    completion(nil)
                }else{
                    completion(error)
                }
            }
        }else{
            self.deleteFromCloud(store, usingKnowledgeVector: true){
                (success,error) in
                if success{
                    completion(nil)
                }else{
                    completion(error)
                }
            }
        }
    }
    
    open func copyCareKit(_ patientAny: OCKAnyPatient, clone:Bool, store: OCKAnyStoreProtocol, completion: @escaping(Patient?) -> Void){
        
        guard let _ = PFUser.current(),
            let patient = patientAny as? OCKPatient,
            let store = store as? OCKStore else{
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
        
        //Setting up CarePlan query
        var uuidsToQuery = [UUID]()
        if let previousUUID = patient.previousVersionUUID{
            uuidsToQuery.append(previousUUID)
        }
        if let nextUUID = patient.nextVersionUUID{
            uuidsToQuery.append(nextUUID)
        }
        
        if uuidsToQuery.isEmpty{
            self.previous = nil
            self.next = nil
            completion(self)
        }else{
            var query = OCKPatientQuery()
            query.uuids = uuidsToQuery
            store.fetchPatients(query: query, callbackQueue: .global(qos: .background)){
                results in
                switch results{
                    
                case .success(let entities):
                    let previousRemoteId = entities.filter{$0.uuid == patient.previousVersionUUID}.first?.remoteID
                    if previousRemoteId != nil && patient.previousVersionUUID != nil{
                        self.previous = Patient(withoutDataWithObjectId: previousRemoteId!)
                    }else if previousRemoteId == nil && patient.previousVersionUUID == nil{
                        self.previous = nil
                    }else{
                        completion(nil)
                        return
                    }
                    
                    let nextRemoteId = entities.filter{$0.uuid == patient.nextVersionUUID}.first?.remoteID
                    if nextRemoteId != nil{
                        self.next = Patient(withoutDataWithObjectId: nextRemoteId!)
                    }
                case .failure(let error):
                    print("Error in \(self.parseClassName).copyCareKit(). Error \(error)")
                    self.previous = nil
                    self.next = nil
                }
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
        patient.remoteID = self.objectId
        patient.allergies = self.alergies
        patient.groupIdentifier = self.groupIdentifier
        patient.tags = self.tags
        patient.source = self.source
        patient.asset = self.asset
        patient.userInfo = self.userInfo
        patient.notes = self.notes?.compactMap{$0.convertToCareKit()}
        if let timeZone = TimeZone(abbreviation: self.timezoneIdentifier){
            patient.timezone = timeZone
        }
        if let sex = self.sex{
            patient.sex = OCKBiologicalSex(rawValue: sex)
        }
        return patient
    }
}
