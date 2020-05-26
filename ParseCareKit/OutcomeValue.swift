//
//  OutcomeValues.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/15/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore


open class OutcomeValue: PFObject, PFSubclassing {

    //1 to 1 between Parse and CareStore
    @NSManaged public var index:Int
    @NSManaged public var groupIdentifier:String?
    @NSManaged public var kind:String?
    @NSManaged public var locallyCreatedAt:Date?
    @NSManaged public var locallyUpdatedAt:Date?
    @NSManaged public var notes:[Note]?
    @NSManaged public var source:String?
    @NSManaged public var tags:[String]?
    @NSManaged public var type:String
    @NSManaged public var units:String?
    @NSManaged public var value:[String: Any]
    @NSManaged public var uuid:String
    @NSManaged public var clock:Int
    @NSManaged public var userInfo:[String:String]?
    
    public static func parseClassName() -> String {
        return kPCKOutcomeValueClassKey
    }
    
    public convenience init(careKitEntity:OCKOutcomeValue) {
        self.init()
        _ = self.copyCareKit(careKitEntity, clone: true)
    }
    
    open func copyCareKit(_ outcomeValue: OCKOutcomeValue, clone: Bool) -> OutcomeValue? {
        
        
        guard let uuid = OutcomeValue.getUUIDFromCareKitEntity(outcomeValue) else{
            print("Error in \(parseClassName).copyCareKit(). doesn't contain a uuid")
            return nil
        }
        self.uuid = uuid
        self.userInfo = outcomeValue.userInfo
        
        self.kind = outcomeValue.kind
        if let index = outcomeValue.index{
            self.index = index
        }else{
            //Can't set nil because of ObjC, make sure to guard against negative index when retreiving
            self.index = -1
        }
        
        self.type = outcomeValue.type.rawValue
        switch outcomeValue.type {
        case .binary:
            self.value = [outcomeValue.type.rawValue: outcomeValue.dataValue!]
        case .boolean:
            self.value = [outcomeValue.type.rawValue: outcomeValue.booleanValue!]
        case .integer:
            self.value = [outcomeValue.type.rawValue: outcomeValue.integerValue!]
        case .double:
            self.value = [outcomeValue.type.rawValue: outcomeValue.doubleValue!]
        case .text:
            self.value = [outcomeValue.type.rawValue: outcomeValue.stringValue!]
        case .date:
            self.value = [outcomeValue.type.rawValue: outcomeValue.dateValue!]
        }
        
        self.units = outcomeValue.units
        
        self.groupIdentifier = outcomeValue.groupIdentifier
        self.tags = outcomeValue.tags
        self.source = outcomeValue.source
        self.locallyUpdatedAt = outcomeValue.updatedDate
        
        if clone{
            self.locallyCreatedAt = outcomeValue.createdDate
            self.notes = outcomeValue.notes?.compactMap{Note(careKitEntity: $0)}
        }else{
            //Only copy this over if the Local Version is older than the Parse version
            if self.locallyCreatedAt == nil {
                self.locallyCreatedAt = outcomeValue.createdDate
            } else if self.locallyCreatedAt != nil && outcomeValue.createdDate != nil{
                if outcomeValue.createdDate! < self.locallyCreatedAt!{
                    self.locallyCreatedAt = outcomeValue.createdDate
                }
            }
            self.notes = Note.updateIfNeeded(self.notes, careKit: outcomeValue.notes)
        }
        
        return self
    }
    
    open func convertToCareKit()->OCKOutcomeValue?{
        
        guard var outcomeValue = createDecodedEntity()else{return nil}
        //Can't set nil because of ObjC, make sure to guard against negative index when retreiving
        if self.index == -1 {
            outcomeValue.index = nil
        }else{
            outcomeValue.index = self.index
        }
        outcomeValue.kind = self.kind
        outcomeValue.groupIdentifier = self.groupIdentifier
        outcomeValue.tags = self.tags
        outcomeValue.source = self.source
        outcomeValue.notes = self.notes?.compactMap{$0.convertToCareKit()}
        outcomeValue.remoteID = self.objectId
        outcomeValue.userInfo = self.userInfo
        return outcomeValue
    }
    
    func stamp(_ clock: Int){
        self.clock = clock
        self.notes?.forEach{
            $0.clock = self.clock
        }
    }
    
    open func createDecodedEntity()->OCKOutcomeValue?{
        guard let underlyingType = OCKOutcomeValueType(rawValue: self.type), let createdDate = self.locallyCreatedAt?.timeIntervalSinceReferenceDate,
            let updatedDate = self.locallyUpdatedAt?.timeIntervalSinceReferenceDate else{
                print("Error in \(parseClassName).createDecodedEntity(). Missing either locallyCreatedAt \(String(describing: locallyCreatedAt)) or locallyUpdatedAt \(String(describing: locallyUpdatedAt))")
            return nil
        }
            
        var tempEntity:OCKOutcomeValue = OCKOutcomeValue("")
        
        switch underlyingType {
        
        case .integer:
            if let value = self.value[self.type] as? Int{
                tempEntity = OCKOutcomeValue(value, units: self.units)
            }
        case .double:
            if let value = self.value[self.type] as? Double{
                tempEntity = OCKOutcomeValue(value, units: self.units)
            }
        case .boolean:
            if let value = self.value[self.type] as? Bool{
                tempEntity = OCKOutcomeValue(value, units: self.units)
            }
        case .text:
            if let value = self.value[self.type] as? String{
                tempEntity = OCKOutcomeValue(value, units: self.units)
            }
        case .binary:
            if let value = self.value[self.type] as? Data{
                tempEntity = OCKOutcomeValue(value, units: self.units)
            }
        case .date:
            if let value = self.value[self.type] as? Date{
                tempEntity = OCKOutcomeValue(value, units: self.units)
            }
        }
        //Create bare CareKit entity from json
        guard var json = OutcomeValue.getEntityAsJSONDictionary(tempEntity) else{return nil}
        json["uuid"] = self.uuid
        json["createdDate"] = createdDate
        json["updatedDate"] = updatedDate
        let entity:OCKOutcomeValue!
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            entity = try JSONDecoder().decode(OCKOutcomeValue.self, from: data)
        }catch{
            print("Error in \(parseClassName).createDecodedEntity(). \(error)")
            return nil
        }
        return entity
    }
    
    open class func getEntityAsJSONDictionary(_ entity: OCKOutcomeValue)->[String:Any]?{
        let jsonDictionary:[String:Any]
        do{
            let data = try JSONEncoder().encode(entity)
            jsonDictionary = try JSONSerialization.jsonObject(with: data, options: []) as! [String:Any]
        }catch{
            print("Error in OutcomeValue.getEntityAsJSONDictionary(). \(error)")
            return nil
        }
        
        return jsonDictionary
    }
    
    open class func getUUIDFromCareKitEntity(_ entity: OCKOutcomeValue)->String?{
        guard let json = OutcomeValue.getEntityAsJSONDictionary(entity) else{return nil}
        return json["uuid"] as? String
    }
    
    open class func updateIfNeeded(_ parse:[OutcomeValue], careKit: [OCKOutcomeValue])->[OutcomeValue]{
        let indexesToDelete = parse.count - careKit.count
        if indexesToDelete > 0{
            let stopIndex = parse.count - 1 - indexesToDelete
            for index in stride(from: parse.count-1, to: stopIndex, by: -1) {
                parse[index].deleteInBackground()
            }
        }
        var updatedValues = [OutcomeValue]()
        for (index,value) in careKit.enumerated(){
            let updated:OutcomeValue?
            //Replace if currently in cloud or create a new one
            if index <= parse.count-1{
                updated = parse[index].copyCareKit(value, clone: true)
            }else{
                updated = OutcomeValue(careKitEntity: value)
            }
            if updated != nil{
                updatedValues.append(updated!)
            }
        }
        return updatedValues
    }
    
    func compareUpdate(_ careKit: OCKOutcomeValue, parse: OutcomeValue, usingKnowledgeVector: Bool, overwriteRemote: Bool, newClockValue:Int, store: OCKAnyStoreProtocol)->OCKOutcomeValue?{
        
        if !usingKnowledgeVector{
            guard let careKitLastUpdated = careKit.updatedDate,
                let cloudUpdatedAt = parse.locallyUpdatedAt else{
                return nil
            }
            if cloudUpdatedAt > careKitLastUpdated{
                //Item from cloud is newer, no change needed in the cloud
                return parse.convertToCareKit()
            }
            
            return nil //Items are the same, no need to do anything
        }else{
            if ((self.clock <= parse.clock) && !overwriteRemote){
                //This should throw a conflict as pullRevisions should have made sure it doesn't happen. Ignoring should allow the newer one to be pulled from the cloud, so we do nothing here
                print("Warning in \(self.parseClassName).compareUpdate(). KnowledgeVector in Cloud \(parse.clock) >= \(self.clock). This should never occur. It should get fixed in next pullRevision. Local: \(self)... Cloud: \(parse)")
            }
            return nil
        }
    }
}

