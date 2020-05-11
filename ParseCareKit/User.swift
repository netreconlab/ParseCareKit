//
//  Users.swift
//  ParseCareKit
//
//  Created by Corey Baker on 10/5/19.
//  Copyright © 2019 NetReconLab. All rights reserved.
//

import Parse
import CareKitStore


open class User: PFUser, PCKSynchronizedEntity, PCKRemoteSynchronizedEntity {
    //1 to 1 between Parse and CareStore
    @NSManaged public var alergies:[String]?
    @NSManaged public var asset:String?
    @NSManaged public var birthday:Date?
    @NSManaged public var entityId:String
    @NSManaged public var groupIdentifier:String?
    @NSManaged public var locallyCreatedAt:Date?
    @NSManaged public var locallyUpdatedAt:Date?
    @NSManaged public var name:[String:String]
    @NSManaged public var notes:[Note]?
    @NSManaged public var sex:String?
    @NSManaged public var source:String?
    @NSManaged public var tags:[String]?
    @NSManaged public var timezone:String
    
    //Not 1 to 1
    @NSManaged public var uuid:String
    @NSManaged public var clock:Int

    public convenience init(careKitEntity: OCKAnyPatient, store: OCKAnyStoreProtocol, completion: @escaping(PCKSynchronizedEntity?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, store: store, completion: completion)
    }
    
    open func updateCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = User.current(),
            let store = store as? OCKStore else{
            completion(false,nil)
            return
        }
        
        store.fetchPatient(withID: self.uuid, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let patient):
                guard let remoteID = patient.remoteID else{
                    
                    //Check to see if this entity is already in the Cloud, but not paired locally
                    let query = User.query()!
                    query.whereKey(kPCKUserIdKey, equalTo: patient.id)
                    query.findObjectsInBackground{
                        (objects, error) in
                        
                        guard let foundObject = objects?.first as? User else{
                            completion(false,error)
                            return
                        }
                        self.compareUpdate(patient, parse: foundObject, store: store, completion: completion)
                    }
                    return
                }
                
                //Get latest item from the Cloud to compare against
                let query = User.query()!
                query.whereKey(kPCKUserObjectIdKey, equalTo: remoteID)
                query.findObjectsInBackground{
                    (objects, error) in
                    
                    guard let foundObject = objects?.first as? User else{
                        completion(false,error)
                        return
                    }
                    self.compareUpdate(patient, parse: foundObject, store: store, completion: completion)
                }
            case .failure(let error):
                print("Error in Contact.addToCloud(). \(error)")
                completion(false,error)
            }
        }
    }
    
    func compareUpdate(_ careKit: OCKPatient, parse: User, store: OCKAnyStoreProtocol, completion: @escaping(Bool,Error?) -> Void){
        guard let careKitLastUpdated = careKit.updatedDate,
            let cloudUpdatedAt = parse.locallyUpdatedAt else{
            parse.copyCareKit(careKit, store: store){
                _ in
                
                //An update may occur when Internet isn't available, try to update at some point
                parse.saveAndCheckRemoteID(store){
                    (success,error) in
                    
                    if !success{
                        print("Error in \(self.parseClassName).updateCloud(). Error updating \(careKit)")
                    }else{
                        print("Successfully updated Patient \(self) in the Cloud")
                    }
                    completion(success,error)
                }
            }
            return
        }
        if cloudUpdatedAt < careKitLastUpdated{
            parse.copyCareKit(careKit, store: store){
                _ in
                //An update may occur when Internet isn't available, try to update at some point
                parse.saveInBackground{
                    (success,error) in
                    
                    if !success{
                        guard let error = error else{return}
                        print("Error in User.updateCloud(). \(error)")
                    }else{
                        print("Successfully updated Patient \(self) in the Cloud")
                    }
                }
                
            }
            
        }else if cloudUpdatedAt > careKitLastUpdated{
            //The cloud version is newer than local, update the local version instead
            guard let updatedPatientFromCloud = parse.convertToCareKit() else{
                return
            }
            store.updateAnyPatient(updatedPatientFromCloud, callbackQueue: .global(qos: .background)){
                result in
                
                switch result{
                    
                case .success(_):
                    print("Successfully updated Patient \(updatedPatientFromCloud) from the Cloud to CareStore")
                case .failure(_):
                    print("Error updating Patient \(updatedPatientFromCloud) from the Cloud to CareStore")
                }
            }
        }
    }
    
    open func deleteFromCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = User.current() else{
            return
        }
        
        //Get latest item from the Cloud to compare against
        let query = User.query()!
        query.whereKey(kPCKUserIdKey, equalTo: self.uuid)
        query.getFirstObjectInBackground(){
            (objects, error) in
            
            guard let foundObject = objects as? User else{
                completion(false,error)
                return
            }
            self.compareDelete(foundObject, store: store, completion: completion)
        }
    }
    
    func compareDelete(_ parse: User, store: OCKAnyStoreProtocol, completion: @escaping(Bool,Error?) -> Void){
        guard let careKitLastUpdated = self.locallyUpdatedAt,
            let cloudUpdatedAt = parse.locallyUpdatedAt else{
            return
        }
        
        if cloudUpdatedAt <= careKitLastUpdated{
            parse.deleteInBackground{
                (success, error) in
                if !success{
                    print("Error in User.deleteFromCloud(). \(String(describing: error))")
                }else{
                    print("Successfully deleted User \(self) in the Cloud")
                }
                completion(success,error)
            }
        }else {
            guard let updatedCarePlanFromCloud = parse.convertToCareKit() else {return}
            store.updateAnyPatient(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                result in
                switch result{
                case .success(_):
                    print("Successfully deleting User \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    completion(true,nil)
                case .failure(let error):
                    print("Error deleting User \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    completion(false,error)
                }
            }
        }
    }
    
    open func addToCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = User.current() else{
            return
        }

        //Check to see if already in the cloud
        let query = User.query()!
        query.whereKey(kPCKUserIdKey, equalTo: self.uuid)
        query.findObjectsInBackground(){
            (objects, error) in
            guard let foundObjects = objects else{
                guard let error = error as NSError?,
                    let errorDictionary = error.userInfo["error"] as? [String:Any],
                    let reason = errorDictionary["routine"] as? String else {return}
                //If the query was looking in a column that wasn't a default column, it will return nil if the table doesn't contain the custom column
                if reason == "errorMissingColumn"{
                    //Saving the new item with the custom column should resolve the issue
                    print("This table '\(self.parseClassName)' either doesn't exist or is missing a column. Attempting to create the table and add new data to it...")
                    self.saveAndCheckRemoteID(store, completion: completion)
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
                self.updateCloud(store, completion: completion)
            }else{
                self.saveAndCheckRemoteID(store, completion: completion)
            }
        }
    }
    
    func saveAndCheckRemoteID(_ store: OCKAnyStoreProtocol, completion: @escaping(Bool,Error?) -> Void){
        guard let store = store as? OCKStore else{return}
        self.saveInBackground{
            (success, error) in
            if success{
                print("Successfully saved \(self) in Cloud.")
                //Only save data back to CarePlanStore if it's never been saved before
                store.fetchPatient(withID: self.uuid, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(var mutableEntity):
                        if mutableEntity.remoteID == nil{
                            mutableEntity.remoteID = self.objectId
                            store.updateAnyPatient(mutableEntity, callbackQueue: .global(qos: .background)){
                                result in
                                switch result{
                                case .success(_):
                                    print("Successfully added Patient \(mutableEntity) to Cloud")
                                    completion(true, nil)
                                case .failure(let error):
                                    print("Error in \(self.parseClassName).addToCloud() adding Patient \(mutableEntity) to Cloud. \(error)")
                                    completion(false,error)
                                }
                            }
                        }else{
                            if mutableEntity.remoteID! != self.objectId{
                                print("Error in \(self.parseClassName).saveAndCheckRemoteID(). remoteId \(mutableEntity.remoteID!) should equal (self.objectId)")
                                completion(false,nil)
                            }else{
                                completion(true,nil)
                            }
                        }
                    case .failure(let error):
                        print("Error in Contact.addToCloud(). \(error)")
                        completion(false,error)
                    }
                }
            }else{
                print("Error in User.addToCloud(). \(String(describing: error))")
                completion(false,error)
            }
        }
    }
    
    open func copyCareKit(_ patientAny: OCKAnyPatient, store: OCKAnyStoreProtocol, completion: @escaping(User?)->Void){
        
        guard let _ = User.current(),
            let patient = patientAny as? OCKPatient else{
            completion(nil)
            return
        }
        guard let uuid = patient.uuid?.uuidString else{
            print("Error in \(parseClassName). Entity missing uuid: \(patient)")
            completion(nil)
            return
        }
        self.uuid = uuid
        self.entityId = patient.id
        self.name = CareKitParsonNameComponents.familyName.convertToDictionary(patient.name)
        self.birthday = patient.birthday
        self.sex = patient.sex?.rawValue
        self.locallyUpdatedAt = patient.updatedDate
        //Only copy this over if the Local Version is older than the Parse version
        if self.locallyCreatedAt == nil {
            self.locallyCreatedAt = patient.createdDate
        } else if self.locallyCreatedAt != nil && patient.createdDate != nil{
            if patient.createdDate! < self.locallyCreatedAt!{
                self.locallyCreatedAt = patient.createdDate
            }
        }
        
        self.timezone = patient.timezone.abbreviation()!
        
        Note.convertCareKitArrayToParse(patient.notes, store: store){
            copiedNotes in
            self.notes = copiedNotes
            completion(self)
        }
    }
    
    open func convertToCareKit(firstTimeLoggingIn: Bool=false)->OCKPatient?{
        
        if firstTimeLoggingIn{
            let nameComponents = CareKitParsonNameComponents.familyName.convertToPersonNameComponents(self.name)
            return OCKPatient(id: self.entityId, name: nameComponents)
        }
        
        guard var patient = createDeserializedEntity() else{return nil}
        patient.birthday = self.birthday
        patient.remoteID = self.objectId
        patient.allergies = self.alergies
        patient.groupIdentifier = self.groupIdentifier
        patient.tags = self.tags
        patient.source = self.source
        patient.asset = self.asset
        patient.notes = self.notes?.compactMap{$0.convertToCareKit()}
        if let timeZone = TimeZone(abbreviation: self.timezone){
            patient.timezone = timeZone
        }
        if let sex = self.sex{
            patient.sex = OCKBiologicalSex(rawValue: sex)
        }
        return patient
    }
    
    open func createDeserializedEntity()->OCKPatient?{
        guard let createdDate = self.locallyCreatedAt?.timeIntervalSinceReferenceDate,
            let updatedDate = self.locallyUpdatedAt?.timeIntervalSinceReferenceDate else{
                print("Error in \(parseClassName).createDeserializedEntity(). Missing either locallyCreatedAt \(String(describing: locallyCreatedAt)) or locallyUpdatedAt \(String(describing: locallyUpdatedAt))")
            return nil
        }
        
        let nameComponents = CareKitParsonNameComponents.familyName.convertToPersonNameComponents(self.name)
        let tempEntity = OCKPatient(id: self.entityId, name: nameComponents)
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
        let entity:OCKPatient!
        do {
            entity = try JSONDecoder().decode(OCKPatient.self, from: data)
        }catch{
            print("Error in \(parseClassName).createDeserializedEntity(). \(error)")
            return nil
        }
        return entity
    }
    
    open class func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        let query = User.query()!
        query.whereKey(kPCKUserClockKey, greaterThanOrEqualTo: localClock)
        query.findObjectsInBackground{ (objects,error) in
            guard let carePlans = objects as? [User] else{
                guard let error = error as NSError?,
                    let errorDictionary = error.userInfo["error"] as? [String:Any],
                    let reason = errorDictionary["routine"] as? String else {return}
                //If the query was looking in a column that wasn't a default column, it will return nil if the table doesn't contain the custom column
                if reason == "errorMissingColumn"{
                    //Saving the new item with the custom column should resolve the issue
                    print("Warning, table User either doesn't exist or is missing the column \(kPCKOutcomeClockKey). It should be fixed during the first sync of an Outcome...")
                }
                let revision = OCKRevisionRecord(entities: [], knowledgeVector: .init())
                mergeRevision(revision)
                return
            }
            let pulled = carePlans.compactMap{$0.convertToCareKit()}
            let entities = pulled.compactMap{OCKEntity.patient($0)}
            let revision = OCKRevisionRecord(entities: entities, knowledgeVector: cloudVector)
            mergeRevision(revision)
        }
    }
    
    open class func pushRevision(_ store: OCKStore, overwriteRemote: Bool, cloudClock: Int, careKitEntity:OCKEntity, completion: @escaping (Error?) -> Void){
        switch careKitEntity {
        case .patient(let careKit):
            let _ = User(careKitEntity: careKit, store: store){
                copied in
                guard let parse = copied as? User else{return}
                parse.clock = cloudClock //Stamp Entity
                if careKit.deletedDate == nil{
                    parse.addToCloud(store, usingKnowledgeVector: true){
                        (success,error) in
                        if success{
                            completion(nil)
                        }else{
                            completion(error)
                        }
                    }
                }else{
                    parse.deleteFromCloud(store, usingKnowledgeVector: true){
                        (success,error) in
                        if success{
                            completion(nil)
                        }else{
                            completion(error)
                        }
                    }
                }
            }
        default:
            print("Error in Contact.pushRevision(). Received wrong type \(careKitEntity)")
            completion(nil)
        }
    }
}
