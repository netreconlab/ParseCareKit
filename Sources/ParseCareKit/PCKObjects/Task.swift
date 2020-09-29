//
//  Task.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/17/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore


public class Task: PCKVersionedObject, PCKRemoteSynchronized {

    public var impactsAdherence:Bool?
    public var instructions:String?
    public var title:String?
    public var elements:[ScheduleElement]? //Use elements to generate a schedule. Each task will point to an array of schedule elements
    var carePlan:CarePlan? {
        didSet {
            carePlanUUID = carePlan?.uuid
        }
    }
    var carePlanUUID:UUID? {
        didSet {
            if carePlanUUID != carePlan?.uuid {
                carePlan = nil
            }
        }
    }
    /*
    public var carePlanUUID:UUID? {
        get {
            if carePlan?.uuid != nil{
                return UUID(uuidString: carePlan!.uuid!)
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
    }*/
    
    public var currentCarePlan: CarePlan?{
        get{
            return carePlan
        }
        set{
            carePlan = newValue
            carePlanUUID = newValue?.uuid
        }
    }

    public static var className: String {
        kPCKTaskClassKey
    }

    override init () {
        super.init()
    }

    public convenience init?(careKitEntity: OCKAnyTask) {
        self.init()
        do {
            _ = try self.copyCareKit(careKitEntity)
        } catch {
            return nil
        }
    }
    
    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
    
    enum CodingKeys: String, CodingKey {
        case title, carePlan, carePlanUUID, impactsAdherence, instructions, elements
    }
    
    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        if encodingForParse {
            try container.encode(carePlan, forKey: .carePlan)
        }
        try container.encode(title, forKey: .title)
        try container.encode(carePlanUUID, forKey: .carePlanUUID)
        try container.encode(impactsAdherence, forKey: .impactsAdherence)
        try container.encode(instructions, forKey: .instructions)
        try container.encode(elements, forKey: .elements)
    }

    open func new() -> PCKSynchronized {
        return Task()
    }
    
    open func new(with careKitEntity: OCKEntity)->PCKSynchronized?{
        
        switch careKitEntity {
        case .task(let entity):
            return Task(careKitEntity: entity)
        default:
            print("Error in \(className).new(with:). The wrong type of entity was passed \(careKitEntity)")
            return nil
        }
    }
    
    public func addToCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PCKUser.current,
              let uuid = self.uuid else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if already in the cloud
        let query = Task.query(kPCKObjectableUUIDKey == uuid)
        query.first(callbackQueue: .global(qos: .background)){ result in
            
            switch result {
            
            case .success(_):
                completion(false,ParseCareKitError.uuidAlreadyExists)
            case .failure(let error):
                switch error.code {
                case .internalServer, .objectNotFound: //1 - this column hasn't been added. 101 - Query returned no results
                        self.save(completion: completion)
                default:
                    //There was a different issue that we don't know how to handle
                    print("Error in \(self.className).addToCloud(). \(error.localizedDescription)")
                    completion(false,error)
                }
                return
            }
        }
    }
    
    public func updateCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        guard let _ = PCKUser.current,
              let uuid = self.uuid,
            let previousPatientUUID = self.previousVersionUUID else{
            completion(false,ParseCareKitError.requiredValueCantBeUnwrapped)
            return
        }
        
        //Check to see if this entity is already in the Cloud, but not matched locally
        var query = Task.query(containedIn(key: kPCKObjectableUUIDKey, array: [uuid,previousPatientUUID]))
        query.include([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectableNotesKey,
                           kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.find(callbackQueue: .global(qos: .background)){ results in
            
            switch results {
            
            case .success(let foundObjects):
                switch foundObjects.count{
                case 0:
                    print("Warning in \(self.className).updateCloud(). A previous version is suppose to exist in the Cloud, but isn't present, saving as new")
                    self.addToCloud(completion: completion)
                case 1:
                    //This is the typical case
                    guard let previousVersion = foundObjects.filter({$0.uuid == previousPatientUUID}).first else {
                        print("Error in \(self.className).updateCloud(). Didn't find previousVersion and this UUID already exists in Cloud")
                        completion(false,ParseCareKitError.uuidAlreadyExists)
                        return
                    }
                    self.copyRelationalEntities(previousVersion)
                    self.addToCloud(completion: completion)

                default:
                    print("Error in \(self.className).updateCloud(). UUID already exists in Cloud")
                    completion(false,ParseCareKitError.uuidAlreadyExists)
                }
            case .failure(let error):
                print("Error in \(self.className).updateCloud(). \(String(describing: error.localizedDescription))")
                completion(false,error)
            }
        }
    }
    
    public func deleteFromCloud(_ usingKnowledgeVector:Bool=false, overwriteRemote: Bool=false, completion: @escaping(Bool,Error?) -> Void){
        //Handled with update, marked for deletion
        completion(true,nil)
    }
    
    public func pullRevisions(_ localClock: Int, cloudVector: OCKRevisionRecord.KnowledgeVector, mergeRevision: @escaping (OCKRevisionRecord) -> Void){
        
        var query = Task.query(kPCKObjectableClockKey >= localClock)
        query.order([.ascending(kPCKObjectableClockKey), .ascending(kPCKParseCreatedAtKey)])
        query.include([kPCKTaskCarePlanKey,kPCKTaskElementsKey,kPCKObjectableNotesKey,
                           kPCKVersionedObjectPreviousKey,kPCKVersionedObjectNextKey])
        query.find(callbackQueue: .global(qos: .background)){ results in
            switch results {
            
            case .success(let tasks):
                let pulled = tasks.compactMap{try? $0.convertToCareKit()}
                let entities = pulled.compactMap{OCKEntity.task($0)}
                let revision = OCKRevisionRecord(entities: entities, knowledgeVector: cloudVector)
                mergeRevision(revision)
            case .failure(let error):
                let revision = OCKRevisionRecord(entities: [], knowledgeVector: cloudVector)
                
                switch error.code{
                case .internalServer, .objectNotFound: //1 - this column hasn't been added. 101 - Query returned no results
                    //If the query was looking in a column that wasn't a default column, it will return nil if the table doesn't contain the custom column
                    //Saving the new item with the custom column should resolve the issue
                    print("Warning, table CarePlan either doesn't exist or is missing the column \(kPCKObjectableClockKey). It should be fixed during the first sync of an Outcome... \(error.localizedDescription)")
                default:
                    print("An unexpected error occured \(error.localizedDescription)")
                }
                mergeRevision(revision)
            }
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
    
    
    open func copyCareKit(_ taskAny: OCKAnyTask) throws -> Task {
        
        guard let _ = PCKUser.current,
            let task = taskAny as? OCKTask else{
            throw ParseCareKitError.cantCastToNeededClassType
        }
        
        let encoded = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(Self.self, from: encoded)
        self.copyCommonValues(from: decoded)
        self.entityId = task.id
        return self
        /*
        if let uuid = task.uuid?.uuidString{
            self.uuid = uuid
        }else{
            print("Warning in \(className). Entity missing uuid: \(task)")
        }
        
        if let schemaVersion = Task.getSchemaVersionFromCareKitEntity(task){
            self.schemaVersion = schemaVersion
        }else{
            print("Warning in \(className).copyCareKit(). Entity missing schemaVersion: \(task)")
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
        return self*/
    }
    
    open override func copyRelationalEntities(_ parse: PCKObject) {
        guard let parse = parse as? Task else{return}
        super.copyRelationalEntities(parse)
        if self.elements == nil {
            self.elements = .init()
        }
        
        if parse.elements != nil {
            ScheduleElement.replaceWithCloudVersion(&self.elements!, cloud: parse.elements!)
        }
    }
    
    
    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    open func convertToCareKit(fromCloud:Bool=true) throws -> OCKTask {
        self.encodingForParse = false
        let encoded = try JSONEncoder().encode(self)
        self.encodingForParse = true
        return try JSONDecoder().decode(OCKTask.self, from: encoded)

        /*
        guard self.canConvertToCareKit() == true,
            let impactsAdherence = self.impactsAdherence,
              let elements = self.elements else {
            return nil
        }

        //Create bare Entity and replace contents with Parse contents
        let careKitScheduleElements = elements.compactMap{$0.convertToCareKit()}
        let schedule = OCKSchedule(composing: careKitScheduleElements)
        var task = OCKTask(id: self.entityId!, title: self.title, carePlanUUID: self.carePlanUUID, schedule: schedule)
        
        if fromCloud{
            guard let decodedTask = decodedCareKitObject(task) else{
                print("Error in \(className). Couldn't decode entity \(self)")
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
        task.impactsAdherence = impactsAdherence
        task.groupIdentifier = self.groupIdentifier
        task.asset = self.asset
        task.userInfo = self.userInfo
        if let timeZone = TimeZone(abbreviation: self.timezone!){
            task.timezone = timeZone
        }
        task.notes = self.notes?.compactMap{$0.convertToCareKit()}
        
        return task*/
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
            
            self.first(carePlanUUID, classType: CarePlan(), relatedObject: self.carePlan, include: true){
                (isNew,carePlan) in
                
                guard let carePlan = carePlan else{
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
    
    func makeSchedule() -> OCKSchedule? {
        guard let elements = self.elements else {
            return nil
        }
        return OCKSchedule(composing: elements.compactMap{ try? $0.convertToCareKit() })
    }
    
    open override func stampRelationalEntities() -> Bool {
        let successful = super.stampRelationalEntities()
        if successful {
            self.elements?.forEach{$0.stamp(self.logicalClock!)}
        }
        return successful
    }
}

