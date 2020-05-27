//
//  Patients.swift
//  ParseCareKit
//
//  Created by Corey Baker on 10/5/19.
//  Copyright © 2019 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore


open class Patient: PCKVersionedEntity, PCKRemoteSynchronized {
    
    //1 to 1 between Parse and CareStore
    @NSManaged public var alergies:[String]?
    @NSManaged public var birthday:Date?
    @NSManaged public var name:[String:String]
    @NSManaged public var sex:String?
    
    public static func parseClassName() -> String {
        return kPCKPatientClassKey
    }
    
    public convenience init(careKitEntity: OCKAnyPatient, store: OCKAnyStoreProtocol, completion: @escaping(PCKEntity?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, clone: true, store: store, completion: completion)
    }
    
    public func createNewClass() -> PCKSynchronized {
        return CarePlan()
    }
    
    public func createNewClass(with careKitEntity: OCKEntity, store: OCKStore, completion: @escaping(PCKRemoteSynchronized?)-> Void){
        switch careKitEntity {
        case .patient(let entity):
            self.copyCareKit(entity, clone: true, store: store, completion: completion)
        default:
            print("Error in \(parseClassName).createNewClass(with:). The wrong type of entity was passed \(careKitEntity)")
        }
    }
    
    open func updateCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current(),
            let store = store as? OCKStore,
            let patientUUID = UUID(uuidString: self.uuid) else{
            completion(false,nil)
            return
        }
        
        var careKitQuery = OCKPatientQuery()
        careKitQuery.uuids = [patientUUID]
        
        store.fetchPatients(query: careKitQuery, callbackQueue: .global(qos: .background)){
            result in
            switch result{
            case .success(let patients):
                guard let patient = patients.first else{
                    completion(false,nil)
                    return
                }
                guard let remoteID = patient.remoteID else{
                    
                    //Check to see if this entity is already in the Cloud, but not paired locally
                    let query = Patient.query()!
                    query.whereKey(kPCKEntityUUIDKey, equalTo: patientUUID.uuidString)
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
    
    func compareUpdate(_ careKit: OCKPatient, parse: Patient, store: OCKStore, usingKnowledgeVector:Bool, overwriteRemote: Bool, completion: @escaping(Bool,Error?) -> Void){
        if !usingKnowledgeVector{
            guard let careKitLastUpdated = careKit.updatedDate,
                let cloudUpdatedAt = parse.updatedDate else{
                    //This occurs only on a Patient when they have logged in for the first time
                    //and CareKit and Parse isn't properly synced. Basically this is the first
                    //time the local dates are pushed to the cloud
                    parse.copyCareKit(careKit, clone: overwriteRemote, store: store){
                        _ in
                        self.saveAndCheckRemoteID(store){
                            (success,error) in
                            if !success{
                                print("Error in \(self.parseClassName).compareUpdate(). Error updating \(careKit)")
                            }else{
                                print("Successfully updated Patient \(self) in the Cloud")
                            }
                            completion(success,error)
                        }
                        
                    }
                    return
            }
            if ((cloudUpdatedAt < careKitLastUpdated) || overwriteRemote){
                parse.copyCareKit(careKit, clone: overwriteRemote, store: store){ _ in
                    //An update may occur when Internet isn't available, try to update at some point
                    self.saveAndCheckRemoteID(store){
                        (success,error) in
                        if !success{
                            print("Error in \(self.parseClassName).updateCloud(). Error updating \(careKit)")
                        }else{
                            print("Successfully updated Patient \(self) in the Cloud")
                        }
                        completion(success,error)
                    }
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
            if ((self.logicalClock > parse.logicalClock) || overwriteRemote){
                parse.copyCareKit(careKit, clone: overwriteRemote, store: store){ _ in
                    self.logicalClock = self.logicalClock //Place stamp on this entity since it's correctly linked to Parse
                    //An update may occur when Internet isn't available, try to update at some point
                    self.saveAndCheckRemoteID(store){
                        (success,error) in
                        if !success{
                            print("Error in \(self.parseClassName).updateCloud(). Error updating \(careKit)")
                        }else{
                            print("Successfully updated Patient \(self) in the Cloud")
                        }
                        completion(success,error)
                    }
                }
            }else{
                //This should throw a conflict as pullRevisions should have made sure it doesn't happen. Ignoring should allow the newer one to be pulled from the cloud, so we do nothing here
                print("Warning in \(self.parseClassName).compareUpdate(). KnowledgeVector in Cloud \(parse.logicalClock) >= \(self.logicalClock). This should never occur. It should get fixed in next pullRevision. Local: \(self)... Cloud: \(parse)")
                completion(false,nil)
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
        query.whereKey(kPCKEntityUUIDKey, equalTo: patientUUID)
        query.getFirstObjectInBackground(){
            (objects, error) in
            
            guard let foundObject = objects as? Patient else{
                completion(false,error)
                return
            }
            self.compareDelete(foundObject, store: store, completion: completion)
        }
    }
    
    func compareDelete(_ parse: Patient, store: OCKStore, completion: @escaping(Bool,Error?) -> Void){
        guard let careKitLastUpdated = self.updatedDate,
            let cloudUpdatedAt = parse.updatedDate else{
            return
        }
        
        if cloudUpdatedAt <= careKitLastUpdated{
            parse.deleteInBackground{
                (success, error) in
                if !success{
                    print("Error in Patient.deleteFromCloud(). \(String(describing: error))")
                }else{
                    print("Successfully deleted Patient \(self) in the Cloud")
                }
                completion(success,error)
            }
        }else {
            guard let updatedCarePlanFromCloud = parse.convertToCareKit() else {return}
            store.updateAnyPatient(updatedCarePlanFromCloud, callbackQueue: .global(qos: .background)){
                result in
                switch result{
                case .success(_):
                    print("Successfully deleting Patient \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    completion(true,nil)
                case .failure(let error):
                    print("Error deleting Patient \(updatedCarePlanFromCloud) from the Cloud to CareStore")
                    completion(false,error)
                }
            }
        }
    }
    
    open func addToCloud(_ store: OCKAnyStoreProtocol, usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current(),
            let patientUUID = UUID(uuidString: self.uuid) else{
            return
        }

        //Check to see if already in the cloud
        let query = Patient.query()!
        query.whereKey(kPCKEntityUUIDKey, equalTo: patientUUID.uuidString)
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
                    self.logicalClock = 0
                }
                self.saveAndCheckRemoteID(store, completion: completion)
            }
        }
    }
    
    func saveAndCheckRemoteID(_ store: OCKAnyStoreProtocol, completion: @escaping(Bool,Error?) -> Void){
        guard let store = store as? OCKStore,
            let patientUUID = UUID(uuidString: self.uuid) else{
            completion(false,nil)
            return
        }
        stampRelationalEntities()
        self.saveInBackground{
            (success, error) in
            if success{
                print("Successfully saved \(self) in Cloud.")
                //Only save data back to CarePlanStore if it's never been saved before
                var careKitQuery = OCKPatientQuery()
                careKitQuery.uuids = [patientUUID]
                store.fetchPatients(query: careKitQuery, callbackQueue: .global(qos: .background)){
                    result in
                    switch result{
                    case .success(let entities):
                        guard var mutableEntity = entities.first else{
                            completion(false,nil)
                            return
                        }
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
                print("Error in Patient.addToCloud(). \(String(describing: error))")
                completion(false,error)
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
        guard let uuid = patient.uuid?.uuidString else{
            print("Error in \(parseClassName). Entity missing uuid: \(patient)")
            completion(nil)
            return
        }
        self.uuid = uuid
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
            var query = OCKContactQuery()
            query.uuids = uuidsToQuery
            store.fetchContacts(query: query, callbackQueue: .global(qos: .background)){
                results in
                switch results{
                    
                case .success(let entities):
                    let previousRemoteId = entities.filter{$0.uuid == patient.previousVersionUUID}.first?.remoteID
                    let nextRemoteId = entities.filter{$0.uuid == patient.nextVersionUUID}.first?.remoteID
                    self.previous = CarePlan(withoutDataWithObjectId: previousRemoteId)
                    self.next = CarePlan(withoutDataWithObjectId: nextRemoteId)
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
        
        var patient:OCKPatient!
        if fromCloud{
            guard let decodedPatient = createDecodedEntity() else{
                print("Error in \(parseClassName). Couldn't decode entity \(self)")
                return nil
            }
            patient = decodedPatient
        }else{
            //Create bare Entity and replace contents with Parse contents
            let nameComponents = CareKitPersonNameComponents.familyName.convertToPersonNameComponents(self.name)
            patient = OCKPatient(id: self.entityId, name: nameComponents)
        }
        
        patient.effectiveDate = self.effectiveDate
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
    
    open class func getEntityAsJSONDictionary(_ entity: OCKPatient)->[String:Any]?{
        let jsonDictionary:[String:Any]
        do{
            let data = try JSONEncoder().encode(entity)
            jsonDictionary = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers,.mutableLeaves]) as! [String:Any]
        }catch{
            print("Error in Patient.getEntityAsJSONDictionary(). \(error)")
            return nil
        }
        
        return jsonDictionary
    }
    
    open func createDecodedEntity()->OCKPatient?{
        guard let createdDate = self.createdDate?.timeIntervalSinceReferenceDate,
            let updatedDate = self.updatedDate?.timeIntervalSinceReferenceDate else{
                print("Error in \(parseClassName).createDecodedEntity(). Missing either createdDate \(String(describing: self.createdDate)) or updatedDate \(String(describing: self.updatedDate))")
            return nil
        }
        
        let nameComponents = CareKitPersonNameComponents.familyName.convertToPersonNameComponents(self.name)
        let tempEntity = OCKPatient(id: self.entityId, name: nameComponents)
        //Create bare CareKit entity from json
        guard var json = Patient.getEntityAsJSONDictionary(tempEntity) else{return nil}
        json["uuid"] = self.uuid
        json["createdDate"] = createdDate
        json["updatedDate"] = updatedDate
        if let deletedDate = self.deletedDate?.timeIntervalSinceReferenceDate{
            json["deletedDate"] = deletedDate
        }
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
        self.notes?.forEach{$0.stamp(self.logicalClock)}
    }
    
    public func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        let query = Patient.query()!
        query.whereKey(kPCKEntityClockKey, greaterThanOrEqualTo: localClock)
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
                    print("Warning, table Patient either doesn't exist or is missing the column \(kPCKEntityClockKey). It should be fixed during the first sync of an Outcome...")
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
}
