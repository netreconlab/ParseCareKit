//
//  Task.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore


open class Task: PCKVersionedObject, PCKRemoteSynchronized {

    @NSManaged public var impactsAdherence:Bool
    @NSManaged public var instructions:String?
    @NSManaged public var title:String?
    @NSManaged public var elements:[ScheduleElement] //Use elements to generate a schedule. Each task will point to an array of schedule elements
    @NSManaged var carePlan:CarePlan?
    @NSManaged var carePlanUUIDString:String?
    
    public var carePlanUUID:UUID? {
        get {
            if carePlan != nil{
                return UUID(uuidString: carePlan!.uuid)
            }else if carePlanUUIDString != nil {
                return UUID(uuidString: carePlanUUIDString!)
            }else{
                return nil
            }
        }
        set{
            carePlanUUIDString = newValue?.uuidString
            if newValue?.uuidString != carePlan?.uuid{
                carePlan = nil
            }
        }
    }
    
    public var currentCarePlan: CarePlan?{
        get{
            return carePlan
        }
        set{
            carePlan = newValue
            carePlanUUIDString = newValue?.uuid
        }
    }
   
    public static func parseClassName() -> String {
        return kPCKTaskClassKey
    }
    
    public convenience init(careKitEntity: OCKAnyTask) {
        self.init()
        _ = self.copyCareKit(careKitEntity)
    }
    
    open func new() -> PCKSynchronized {
        return Task()
    }
    
    open func new(with careKitEntity: OCKEntity)->PCKSynchronized?{
        
        switch careKitEntity {
        case .task(let entity):
            return Task(careKitEntity: entity)
        default:
            print("Error in \(parseClassName).new(with:). The wrong type of entity was passed \(careKitEntity)")
            return nil
        }
    }
    
    public func addToCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current() else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if already in the cloud
        let query = Task.query()!
        query.whereKey(kPCKObjectUUIDKey, equalTo: self.uuid)
        query.getFirstObjectInBackground(){
            (object, error) in
            
            guard let _ = object as? Task else{
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
            
            completion(false,ParseCareKitError.uuidAlreadyExists)
        }
    }
    
    public func updateCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PFUser.current(),
            let previousPatientUUIDString = self.previousVersionUUID?.uuidString else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if this entity is already in the Cloud, but not matched locally
        let query = Task.query()!
        query.whereKey(kPCKObjectUUIDKey, containedIn: [self.uuid,previousPatientUUIDString])
        query.includeKeys([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.findObjectsInBackground(){
            (objects, error) in
            
            guard let foundObjects = objects as? [Task] else{
                print("Error in \(self.parseClassName).updateCloud(). \(String(describing: error?.localizedDescription))")
                completion(false,error)
                return
            }
            
            switch foundObjects.count{
            case 0:
                print("Warning in \(self.parseClassName).updateCloud(). A previous version is suppose to exist in the Cloud, but isn't present, saving as new")
                self.addToCloud(completion: completion)
            case 1:
                //This is the typical case
                guard let previousVersion = foundObjects.filter({$0.uuid == previousPatientUUIDString}).first else {
                    print("Error in \(self.parseClassName).updateCloud(). Didn't find previousVersion and this UUID already exists in Cloud")
                    completion(false,ParseCareKitError.uuidAlreadyExists)
                    return
                }
                self.copyRelationalEntities(previousVersion)
                self.addToCloud(completion: completion)

            default:
                print("Error in \(self.parseClassName).updateCloud(). UUID already exists in Cloud")
                completion(false,ParseCareKitError.uuidAlreadyExists)
            }
        }
    }
    
    public func deleteFromCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        //Handled with update, marked for deletion
        completion(true,nil)
    }
    
    public func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        let query = Task.query()!
        query.whereKey(kPCKObjectClockKey, greaterThanOrEqualTo: localClock)
        query.addAscendingOrder(kPCKObjectClockKey)
        query.addAscendingOrder(kPCKParseCreatedAtKey)
        query.includeKeys([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectNotesKey,kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.findObjectsInBackground{ (objects,error) in
            guard let tasks = objects as? [Task] else{
                let revision = OCKRevisionRecord(entities: [], knowledgeVector: cloudVector)
                guard let error = error as NSError?,
                    let errorDictionary = error.userInfo["error"] as? [String:Any],
                    let reason = errorDictionary["routine"] as? String else {
                        mergeRevision(revision)
                        return
                }
                //If the query was looking in a column that wasn't a default column, it will return nil if the table doesn't contain the custom column
                if reason == "errorMissingColumn"{
                    //Saving the new item with the custom column should resolve the issue
                    print("Warning, table Task either doesn't exist or is missing the column \(kPCKObjectClockKey). It should be fixed during the first sync of a Task...")
                }
                mergeRevision(revision)
                return
            }
            let pulled = tasks.compactMap{$0.convertToCareKit()}
            let entities = pulled.compactMap{OCKEntity.task($0)}
            let revision = OCKRevisionRecord(entities: entities, knowledgeVector: cloudVector)
            mergeRevision(revision)
        }
    }
    
    public func pushRevision(_ overwriteRemote: Bool, cloudClock: Int, completion: @escaping (Error?) -> Void){
        
        self.logicalClock = cloudClock //Stamp Entity
        
        guard let _ = self.previousVersionUUID else{
            self.addToCloud(true, overwriteRemote: overwriteRemote){
                (success,error) in
                if success{
                    completion(nil)
                }else{
                    completion(error)
                }
            }
            return
        }
        
        self.updateCloud(true, overwriteRemote: overwriteRemote){
            (success,error) in
            if success{
                completion(nil)
            }else{
                completion(error)
            }
        }
    }
    
    open override func copyCommonValues(from other: PCKObject){
        super.copyCommonValues(from: other)
        guard let other = other as? Task else{return}
        self.impactsAdherence = other.impactsAdherence
        self.instructions = other.instructions
        self.title = other.title
        self.elements = other.elements
        self.currentCarePlan = other.currentCarePlan
        self.carePlanUUID = other.carePlanUUID
    }
    
    
    open func copyCareKit(_ taskAny: OCKAnyTask)->Task?{
        
        guard let _ = PFUser.current(),
            let task = taskAny as? OCKTask else{
            return nil
        }
        
        if let uuid = task.uuid?.uuidString{
            self.uuid = uuid
        }else{
            print("Warning in \(parseClassName). Entity missing uuid: \(task)")
        }
        
        if let schemaVersion = Task.getSchemaVersionFromCareKitEntity(task){
            self.schemaVersion = schemaVersion
        }else{
            print("Warning in \(parseClassName).copyCareKit(). Entity missing schemaVersion: \(task)")
        }
        
        self.entityId = task.id
        self.deletedDate = task.deletedDate
        self.groupIdentifier = task.groupIdentifier
        self.title = task.title
        self.impactsAdherence = task.impactsAdherence
        self.tags = task.tags
        self.source = task.source
        self.asset = task.asset
        self.timezone = task.timezone.abbreviation()!
        self.effectiveDate = task.effectiveDate
        self.updatedDate = task.updatedDate
        self.userInfo = task.userInfo
        self.remoteID = task.remoteID
        self.createdDate = task.createdDate
        self.notes = task.notes?.compactMap{Note(careKitEntity: $0)}
        self.elements = task.schedule.elements.compactMap{ScheduleElement(careKitEntity: $0)}
        self.previousVersionUUID = task.previousVersionUUID
        self.nextVersionUUID = task.nextVersionUUID
        self.carePlanUUID = task.carePlanUUID
        return self
    }
    
    open override func copyRelationalEntities(_ parse: PCKObject) {
        guard let parse = parse as? Task else{return}
        super.copyRelationalEntities(parse)
        ScheduleElement.replaceWithCloudVersion(&self.elements, cloud: parse.elements)
    }
    
    
    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit(fromCloud:Bool=true)->OCKTask?{
        
        //Create bare Entity and replace contents with Parse contents
        let careKitScheduleElements = self.elements.compactMap{$0.convertToCareKit()}
        let schedule = OCKSchedule(composing: careKitScheduleElements)
        var task = OCKTask(id: self.entityId, title: self.title, carePlanUUID: self.carePlanUUID, schedule: schedule)
        
        if fromCloud{
            guard let decodedTask = decodedCareKitObject(task) else{
                print("Error in \(parseClassName). Couldn't decode entity \(self)")
                return nil
            }
            task = decodedTask
        }
        task.remoteID = self.remoteID
        task.groupIdentifier = self.groupIdentifier
        task.tags = self.tags
        if let effectiveDate = self.effectiveDate{
            task.effectiveDate = effectiveDate
        }
        task.source = self.source
        task.instructions = self.instructions
        task.impactsAdherence = self.impactsAdherence
        task.groupIdentifier = self.groupIdentifier
        task.asset = self.asset
        task.userInfo = self.userInfo
        if let timeZone = TimeZone(abbreviation: self.timezone){
            task.timezone = timeZone
        }
        task.notes = self.notes?.compactMap{$0.convertToCareKit()}
        
        return task
    }
    
    ///Link versions and related classes
    public override func linkRelated(completion: @escaping(Bool,Task)->Void){
        
        super.linkRelated(){
            (isNew, _) in
            var linkedNew = isNew
        
            guard let carePlanUUID = self.carePlanUUID else{
                //Finished if there's no CarePlan, otherwise see if it's in the cloud
                completion(linkedNew,self)
                return
            }
            
            self.getFirstPCKObject(carePlanUUID, classType: CarePlan(), relatedObject: self.carePlan, includeKeys: true){
                (isNew,carePlan) in
                
                guard let carePlan = carePlan as? CarePlan else{
                    completion(linkedNew,self)
                    return
                }
                
                self.carePlan = carePlan
                if isNew{
                    linkedNew = true
                }
                completion(linkedNew,self)
            }
        }
    }
    
    func makeSchedule() -> OCKSchedule {
        return OCKSchedule(composing: self.elements.compactMap{$0.convertToCareKit()})
    }
    
    open override func stampRelationalEntities(){
        super.stampRelationalEntities()
        self.elements.forEach{$0.stamp(self.logicalClock)}
    }
}

