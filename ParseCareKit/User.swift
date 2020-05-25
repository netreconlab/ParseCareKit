//
//  Users.swift
//  ParseCareKit
//
//  Created by Corey Baker on 10/5/19.
//  Copyright © 2019 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore


open class User: PFUser, PCKSynchronizedEntity, PCKRemoteSynchronizedEntity {
    //1 to 1 between Parse and CareStore
    @NSManaged public var alergies:[String]?
    @NSManaged public var asset:String?
    @NSManaged public var birthday:Date?
    
    @NSManaged public var groupIdentifier:String?
    @NSManaged public var locallyCreatedAt:Date?
    @NSManaged public var locallyUpdatedAt:Date?
    @NSManaged public var name:[String:String]
    @NSManaged public var notes:[Note]?
    @NSManaged public var sex:String?
    @NSManaged public var source:String?
    @NSManaged public var tags:[String]?
    @NSManaged public var timezone:String
    @NSManaged public var userInfo:[String:String]?
    @NSManaged public var nextVersionUUID:String?
    @NSManaged public var previousVersionUUID:String?
    @NSManaged public var uuid:String
    
    //Not 1 to 1
    @NSManaged public var entityId:String //maps to id
    @NSManaged public var clock:Int

    public convenience init(careKitEntity: OCKAnyPatient, store: OCKAnyStoreProtocol, completion: @escaping(PCKSynchronizedEntity?) -> Void) {
        self.init()
        completion(self.copyCareKit(careKitEntity, clone: true))
    }
    
    open func updateCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = User.current(),
            let store = store as? OCKStore else{
            completion(false,nil)
            return
        }
        
        store.fetchPatient(withID: self.entityId, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let patient):
                guard let remoteID = patient.remoteID else{
                    
                    //Check to see if this entity is already in the Cloud, but not paired locally
                    let query = User.query()!
                    query.whereKey(kPCKUserEntityIdKey, equalTo: patient.id)
                    query.findObjectsInBackground{
                        (objects, error) in
                        
                        guard let foundObject = objects?.first as? User else{
                            completion(false,error)
                            return
                        }
                        self.compareUpdate(patient, parse: foundObject, store: store, usingKnowledgeVector:usingKnowledgeVector, overwriteRemote:overwriteRemote, completion: completion)
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
                    self.compareUpdate(patient, parse: foundObject, store: store, usingKnowledgeVector:usingKnowledgeVector, overwriteRemote:overwriteRemote, completion: completion)
                }
            case .failure(let error):
                print("Error in Contact.addToCloud(). \(error)")
                completion(false,error)
            }
        }
    }
    
    func compareUpdate(_ careKit: OCKPatient, parse: User, store: OCKStore, usingKnowledgeVector:Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void){
        if !usingKnowledgeVector{
            guard let careKitLastUpdated = careKit.updatedDate,
                let cloudUpdatedAt = parse.locallyUpdatedAt else{
                    //This occurs only on a User when they have logged in for the first time
                    //and CareKit and Parse isn't properly synced. Basically this is the first
                    //time the local dates are pushed to the cloud
                    guard let updated = parse.copyCareKit(careKit, clone: overwriteRemote) else{
                        completion(false,nil)
                        return
                    }
                    self.clock = 0 //Make wallclock entities compatible with KnowledgeVector by setting it's initial clock to 0
                    updated.saveAndCheckRemoteID(store){
                        (success,error) in
                        if !success{
                            print("Error in \(self.parseClassName).compareUpdate(). Error updating \(careKit)")
                        }else{
                            print("Successfully updated Patient \(self) in the Cloud")
                        }
                        completion(success,error)
                    }
                    return
            }
            if ((cloudUpdatedAt < careKitLastUpdated) || overwriteRemote){
                guard let updated = parse.copyCareKit(careKit, clone: overwriteRemote) else{
                    completion(false,nil)
                    return
                }
                //An update may occur when Internet isn't available, try to update at some point
                updated.saveAndCheckRemoteID(store){
                    (success,error) in
                    if !success{
                        print("Error in \(self.parseClassName).updateCloud(). Error updating \(careKit)")
                    }else{
                        print("Successfully updated Patient \(self) in the Cloud")
                    }
                    completion(success,error)
                }
            }else if cloudUpdatedAt > careKitLastUpdated{
                //The cloud version is newer than local, update the local version instead
                guard let updatedPatientFromCloud = parse.convertToCareKit() else{
                    completion(false,nil)
                    return
                }
                store.updateAnyPatient(updatedPatientFromCloud, callbackQueue: .global(qos: .background)){
                    result in
                    
                    switch result{
                    case .success(_):
                        print("Successfully updated Patient \(updatedPatientFromCloud) from the Cloud to CareStore")
                        completion(true,nil)
                    case .failure(let error):
                        print("Error updating Patient \(updatedPatientFromCloud) from the Cloud to CareStore")
                        completion(false,error)
                    }
                }
            }else{
                completion(true,nil)
            }
        }else{
            if ((self.clock > parse.clock) || overwriteRemote){
                guard let updated = parse.copyCareKit(careKit, clone: overwriteRemote) else{
                    completion(false,nil)
                    return
                }
                updated.clock = self.clock //Place stamp on this entity since it's correctly linked to Parse
                //An update may occur when Internet isn't available, try to update at some point
                updated.saveAndCheckRemoteID(store){
                    (success,error) in
                    if !success{
                        print("Error in \(self.parseClassName).updateCloud(). Error updating \(careKit)")
                    }else{
                        print("Successfully updated Patient \(self) in the Cloud")
                    }
                    completion(success,error)
                }
            }else{
                //This should throw a conflict as pullRevisions should have made sure it doesn't happen. Ignoring should allow the newer one to be pulled from the cloud, so we do nothing here
                print("Warning in \(self.parseClassName).compareUpdate(). KnowledgeVector in Cloud \(parse.clock) >= \(self.clock). This should never occur. It should get fixed in next pullRevision. Local: \(self)... Cloud: \(parse)")
                completion(false,nil)
            }
        }
    }
    
    open func deleteFromCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = User.current(),
            let store = store as? OCKStore else{
            return
        }
        
        //Get latest item from the Cloud to compare against
        let query = User.query()!
        query.whereKey(kPCKUserEntityIdKey, equalTo: self.entityId)
        query.getFirstObjectInBackground(){
            (objects, error) in
            
            guard let foundObject = objects as? User else{
                completion(false,error)
                return
            }
            self.compareDelete(foundObject, store: store, completion: completion)
        }
    }
    
    func compareDelete(_ parse: User, store: OCKStore, completion: @escaping(Bool,Error?) -> Void){
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
    
    open func addToCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = User.current() else{
            return
        }

        //Check to see if already in the cloud
        let query = User.query()!
        query.whereKey(kPCKUserEntityIdKey, equalTo: self.entityId)
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
                        self.clock = 0
                    }
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
                self.updateCloud(store, usingKnowledgeVector: usingKnowledgeVector, overwriteRemote: overwriteRemote, completion: completion)
            }else{
                //Make wallclock level entities compatible with KnowledgeVector by setting it's initial clock to 0
                if !usingKnowledgeVector{
                    self.clock = 0
                }
                self.saveAndCheckRemoteID(store, completion: completion)
            }
        }
    }
    
    func saveAndCheckRemoteID(_ store: OCKAnyStoreProtocol, completion: @escaping(Bool,Error?) -> Void){
        guard let store = store as? OCKStore else{return}
        stampRelationalEntities()
        self.saveInBackground{
            (success, error) in
            if success{
                print("Successfully saved \(self) in Cloud.")
                //Only save data back to CarePlanStore if it's never been saved before
                store.fetchPatient(withID: self.entityId, callbackQueue: .global(qos: .background)){
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
                                print("Error in \(self.parseClassName).saveAndCheckRemoteID(). remoteId \(mutableEntity.remoteID!) should equal \(self.objectId!)")
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
    
    open func copyCareKit(_ patientAny: OCKAnyPatient, clone:Bool)-> User?{
        
        guard let _ = User.current(),
            let patient = patientAny as? OCKPatient else{
            return nil
        }
        guard let uuid = patient.uuid?.uuidString else{
            print("Error in \(parseClassName). Entity missing uuid: \(patient)")
            return nil
        }
        self.uuid = uuid
        self.previousVersionUUID = patient.nextVersionUUID?.uuidString
        self.nextVersionUUID = patient.previousVersionUUID?.uuidString
        self.entityId = patient.id
        self.name = CareKitParsonNameComponents.familyName.convertToDictionary(patient.name)
        self.birthday = patient.birthday
        self.sex = patient.sex?.rawValue
        self.locallyUpdatedAt = patient.updatedDate
        self.timezone = patient.timezone.abbreviation()!
        self.userInfo = patient.userInfo
        if clone{
            self.locallyCreatedAt = patient.createdDate
            self.notes = patient.notes?.compactMap{Note(careKitEntity: $0)}
        }else{
            //Only copy this over if the Local Version is older than the Parse version
            if self.locallyCreatedAt == nil {
                self.locallyCreatedAt = patient.createdDate
            } else if self.locallyCreatedAt != nil && patient.createdDate != nil{
                if patient.createdDate! < self.locallyCreatedAt!{
                    self.locallyCreatedAt = patient.createdDate
                }
            }
            self.notes = Note.updateIfNeeded(self.notes, careKit: patient.notes)
        }
        return self
    }
    
    open func convertToCareKit(firstTimeLoggingIn: Bool=false)->OCKPatient?{
        var patient:OCKPatient!
        if firstTimeLoggingIn{
            let nameComponents = CareKitParsonNameComponents.familyName.convertToPersonNameComponents(self.name)
            patient = OCKPatient(id: self.entityId, name: nameComponents)
        }else{
            guard let decodedPatient = createDecodedEntity() else{return nil}
            patient = decodedPatient
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
        if let timeZone = TimeZone(abbreviation: self.timezone){
            patient.timezone = timeZone
        }
        if let sex = self.sex{
            patient.sex = OCKBiologicalSex(rawValue: sex)
        }
        return patient
    }
    
    open class func getEntityAsJSONDictionary(_ entity: OCKPatient)->[String:Any]?{
        let jsonDictionary:[String:Any]
        do{
            let data = try JSONEncoder().encode(entity)
            jsonDictionary = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers,.mutableLeaves]) as! [String:Any]
        }catch{
            print("Error in User.getEntityAsJSONDictionary(). \(error)")
            return nil
        }
        
        return jsonDictionary
    }
    
    open func createDecodedEntity()->OCKPatient?{
        guard let createdDate = self.locallyCreatedAt?.timeIntervalSinceReferenceDate,
            let updatedDate = self.locallyUpdatedAt?.timeIntervalSinceReferenceDate else{
                print("Error in \(parseClassName).createDecodedEntity(). Missing either locallyCreatedAt \(String(describing: locallyCreatedAt)) or locallyUpdatedAt \(String(describing: locallyUpdatedAt))")
            return nil
        }
        
        let nameComponents = CareKitParsonNameComponents.familyName.convertToPersonNameComponents(self.name)
        let tempEntity = OCKPatient(id: self.entityId, name: nameComponents)
        //Create bare CareKit entity from json
        guard var json = User.getEntityAsJSONDictionary(tempEntity) else{return nil}
        json["uuid"] = self.uuid
        json["createdDate"] = createdDate
        json["updatedDate"] = updatedDate
        if let previous = self.previousVersionUUID{
            json["previousVersionUUID"] = previous
        }
        if let next = self.nextVersionUUID{
            json["nextVersionUUID"] = next
        }
        let entity:OCKPatient!
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            let jsonString = String(data: data, encoding: .utf8)!
            print(jsonString)
            entity = try JSONDecoder().decode(OCKPatient.self, from: data)
        }catch{
            print("Error in \(parseClassName).createDecodedEntity(). \(error)")
            return nil
        }
        return entity
    }
    
    func stampRelationalEntities(){
        self.notes?.forEach{$0.stamp(self.clock)}
    }
    
    class func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        let query = User.query()!
        query.whereKey(kPCKUserClockKey, greaterThanOrEqualTo: localClock)
        query.findObjectsInBackground{ (objects,error) in
            guard let carePlans = objects as? [User] else{
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
                    print("Warning, table User either doesn't exist or is missing the column \(kPCKOutcomeClockKey). It should be fixed during the first sync of an Outcome...")
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
    
    class func pushRevision(_ store: OCKStore, overwriteRemote: Bool, cloudClock: Int, careKitEntity:OCKEntity, completion: @escaping (Error?) -> Void){
        switch careKitEntity {
        case .patient(let careKit):
            let _ = User(careKitEntity: careKit, store: store){
                copied in
                guard let parse = copied as? User else{return}
                parse.clock = cloudClock //Stamp Entity
                if careKit.deletedDate == nil{
                    parse.addToCloud(store, usingKnowledgeVector: true, overwriteRemote: overwriteRemote){
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
