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


public final class Task: PCKVersionable, PCKSynchronizable {

    public internal(set) var nextVersion: Task? {
        didSet {
            nextVersionUUID = nextVersion?.uuid
        }
    }
    
    public internal(set) var nextVersionUUID:UUID? {
        didSet {
            if nextVersionUUID != nextVersion?.uuid {
                nextVersion = nil
            }
        }
    }

    public internal(set) var previousVersion: Task? {
        didSet {
            previousVersionUUID = previousVersion?.uuid
        }
    }
    
    public internal(set) var previousVersionUUID: UUID? {
        didSet {
            if previousVersionUUID != previousVersion?.uuid {
                previousVersion = nil
            }
        }
    }
    var effectiveDate: Date?
    
    var uuid: UUID?
    
    var entityId: String?
    
    var logicalClock: Int?
    
    var schemaVersion: OCKSemanticVersion?
    
    var createdDate: Date?
    
    var updatedDate: Date?
    
    var deletedDate: Date?
    
    var timezone: TimeZone?
    
    var userInfo: [String : String]?
    
    var groupIdentifier: String?
    
    var tags: [String]?
    
    var source: String?
    
    var asset: String?
    
    var notes: [Note]?
    
    var remoteID: String?
    
    var encodingForParse: Bool = true
    
    public var objectId: String?
    
    public var createdAt: Date?
    
    public var updatedAt: Date?
    
    public var ACL: ParseACL?
    

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

    init () {
        //super.init()
    }

    public convenience init?(careKitEntity: OCKAnyTask) {
        self.init()
        do {
            _ = try Self.copyCareKit(careKitEntity)
        } catch {
            return nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case title, carePlan, carePlanUUID, impactsAdherence, instructions, elements
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if encodingForParse {
            try container.encode(carePlan, forKey: .carePlan)
        }
        try container.encode(title, forKey: .title)
        try container.encode(carePlanUUID, forKey: .carePlanUUID)
        try container.encode(impactsAdherence, forKey: .impactsAdherence)
        try container.encode(instructions, forKey: .instructions)
        try container.encode(elements, forKey: .elements)
        try encodeVersionable(to: encoder)
        encodingForParse = true
    }

    public func new() -> PCKSynchronizable {
        return Task()
    }
    
    public func new(with careKitEntity: OCKEntity) throws ->PCKSynchronizable {
        
        switch careKitEntity {
        case .task(let entity):
            return try Self.copyCareKit(entity)
        default:
            print("Error in \(className).new(with:). The wrong type of entity was passed \(careKitEntity)")
            throw ParseCareKitError.classTypeNotAnEligibleType
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
                    guard let previousVersion = foundObjects.first(where: {$0.uuid == previousPatientUUID}) else {
                        print("Error in \(self.className).updateCloud(). Didn't find previousVersion and this UUID already exists in Cloud")
                        completion(false,ParseCareKitError.uuidAlreadyExists)
                        return
                    }
                    var updated = self
                    updated = updated.copyRelational(previousVersion)
                    updated.addToCloud(completion: completion)

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
    
    public class func copyValues(from other: Task, to here: Task) throws -> Self {
        var here = here
        here.copyVersionedValues(from: other)
        
        here.impactsAdherence = other.impactsAdherence
        here.instructions = other.instructions
        here.title = other.title
        here.elements = other.elements
        here.currentCarePlan = other.currentCarePlan
        here.carePlanUUID = other.carePlanUUID
        
        guard let copied = here as? Self else {
            throw ParseCareKitError.cantCastToNeededClassType
        }
        return copied
    }
    
    
    public class func copyCareKit(_ taskAny: OCKAnyTask) throws -> Task {
        
        guard let _ = PCKUser.current,
            let task = taskAny as? OCKTask else{
            throw ParseCareKitError.cantCastToNeededClassType
        }
        
        let encoded = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(Self.self, from: encoded)
        decoded.entityId = task.id
        return decoded
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
    
    public func copyRelational(_ parse: Task) -> Task {
        var copy = self
        copy = copy.copyRelationalEntities(parse)
        if copy.elements == nil {
            copy.elements = .init()
        }
        
        if parse.elements != nil {
            ScheduleElement.replaceWithCloudVersion(&copy.elements!, cloud: parse.elements!)
        }
        return copy
    }
    
    
    //Note that Tasks have to be saved to CareKit first in order to properly convert Outcome to CareKit
    public func convertToCareKit(fromCloud:Bool=true) throws -> OCKTask {
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
    public func linkRelated(completion: @escaping(Bool,Task)->Void){
        
        self.linkVersions(){
            (isNew, linkedObject) in
            var linkedNew = isNew
        
            guard let carePlanUUID = self.carePlanUUID else {
                //Finished if there's no CarePlan, otherwise see if it's in the cloud
                completion(linkedNew,self)
                return
            }
            
            linkedObject.carePlan?.first(carePlanUUID, relatedObject: linkedObject.carePlan, include: true){
                (isNew,carePlan) in
                
                guard let carePlan = carePlan else{
                    completion(linkedNew,self)
                    return
                }
                
                linkedObject.carePlan = carePlan
                if isNew{
                    linkedNew = true
                }
                completion(linkedNew,linkedObject)
            }
        }
    }
    
    func makeSchedule() -> OCKSchedule? {
        guard let elements = self.elements else {
            return nil
        }
        return OCKSchedule(composing: elements.compactMap{ try? $0.convertToCareKit() })
    }
    
    public func stampRelational() throws -> Task {
        var stamped = self
        stamped = try stamped.stampRelationalEntities()
        stamped.elements?.forEach{$0.stamp(self.logicalClock!)}
        
        return stamped
    }
}

