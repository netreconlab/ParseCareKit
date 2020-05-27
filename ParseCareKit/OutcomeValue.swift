//
//  OutcomeValues.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/15/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore


open class OutcomeValue: PCKEntity, PFSubclassing {

    //1 to 1 between Parse and CareStore
    @NSManaged public var index:NSNumber?
    @NSManaged public var kind:String?
    @NSManaged public var units:String?
    
    @NSManaged private var typeString: String
    var type: OCKOutcomeValueType {
        get { return OCKOutcomeValueType(rawValue: typeString)! }
        set { typeString = newValue.rawValue }
    }

    @NSManaged var textValue: String?
    @NSManaged var binaryValue: Data?
    @NSManaged var booleanValue: Bool
    @NSManaged var integerValue: Int64
    @NSManaged var doubleValue: Double
    @NSManaged var dateValue: Date?

    var value: OCKOutcomeValueUnderlyingType {
        get {
            switch type {
            case .integer: return Int(integerValue)
            case .double: return doubleValue
            case .boolean: return booleanValue
            case .text: return textValue!
            case .binary: return binaryValue!
            case .date: return dateValue!
            }
        }

        set {
            switch newValue {
            case let int as Int:
                reset()
                integerValue = Int64(int)
                type = .integer

            case let double as Double:
                reset()
                doubleValue = double
                type = .double

            case let bool as Bool:
                reset()
                booleanValue = bool
                type = .boolean

            case let text as String:
                reset()
                textValue = text
                type = .text

            case let binary as Data:
                reset()
                binaryValue = binary
                type = .binary

            case let date as Date:
                reset()
                dateValue = date
                type = .date

            default: fatalError("Unexpected type!")
            }
        }
    }

    private func reset() {
        textValue = nil
        binaryValue = nil
        booleanValue = false
        integerValue = 0
        doubleValue = 0
        dateValue = nil
        index = nil
    }
    
    public static func parseClassName() -> String {
        return kPCKOutcomeValueClassKey
    }
    
    public convenience init(careKitEntity:OCKOutcomeValue) {
        self.init()
        _ = self.copyCareKit(careKitEntity, clone: true)
    }
    
    open func copyCareKit(_ outcomeValue: OCKOutcomeValue, clone: Bool) -> OutcomeValue? {
        
        if let uuid = OutcomeValue.getUUIDFromCareKitEntity(outcomeValue) {
            self.uuid = uuid
        }else{
            print("Warning in \(parseClassName).copyCareKit(). Entity missing uuid: \(outcomeValue)")
        }
        self.userInfo = outcomeValue.userInfo
        self.kind = outcomeValue.kind
        
        if let index = outcomeValue.index{
            self.index = NSNumber(value: index)
        }else{
            //Can't set nil because of ObjC, make sure to guard against negative index when retreiving
            self.index = nil
        }
        
        self.typeString = outcomeValue.type.rawValue
        self.value = outcomeValue.value
        self.units = outcomeValue.units
        
        self.groupIdentifier = outcomeValue.groupIdentifier
        self.tags = outcomeValue.tags
        self.source = outcomeValue.source
        self.updatedDate = outcomeValue.updatedDate
        
        if clone{
            self.createdDate = outcomeValue.createdDate
            self.notes = outcomeValue.notes?.compactMap{Note(careKitEntity: $0)}
        }else{
            //Only copy this over if the Local Version is older than the Parse version
            if self.createdDate == nil {
                self.createdDate = outcomeValue.createdDate
            } else if self.createdDate != nil && outcomeValue.createdDate != nil{
                if outcomeValue.createdDate! < self.createdDate!{
                    self.createdDate = outcomeValue.createdDate
                }
            }
            self.notes = Note.updateIfNeeded(self.notes, careKit: outcomeValue.notes)
        }
        
        return self
    }
    
    open func convertToCareKit(fromCloud:Bool=true)->OCKOutcomeValue?{
        
        var outcomeValue:OCKOutcomeValue!
        if fromCloud{
            guard let decodedOutcomeValue = createDecodedEntity()else{
                print("Error in \(parseClassName). Couldn't decode entity \(self)")
                return nil
            }
            outcomeValue = decodedOutcomeValue
        }else{
            //Create bare Entity and replace contents with Parse contents
            outcomeValue = OCKOutcomeValue(self.value, units: self.units)
        }
        
        outcomeValue.index = self.index as? Int
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
        self.logicalClock = clock
        self.notes?.forEach{
            $0.logicalClock = self.logicalClock
        }
    }
    
    open func createDecodedEntity()->OCKOutcomeValue?{
        guard let createdDate = self.createdDate?.timeIntervalSinceReferenceDate,
            let updatedDate = self.updatedDate?.timeIntervalSinceReferenceDate else{
                print("Error in \(parseClassName).createDecodedEntity(). Missing either createdDate \(String(describing: self.createdDate)) or updatedDate \(String(describing: self.updatedDate))")
            return nil
        }
            
        let tempEntity = OCKOutcomeValue(self.value, units: self.units)
        
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
                let cloudUpdatedAt = parse.updatedDate else{
                return nil
            }
            if cloudUpdatedAt > careKitLastUpdated{
                //Item from cloud is newer, no change needed in the cloud
                return parse.convertToCareKit()
            }
            
            return nil //Items are the same, no need to do anything
        }else{
            if ((self.logicalClock <= parse.logicalClock) && !overwriteRemote){
                //This should throw a conflict as pullRevisions should have made sure it doesn't happen. Ignoring should allow the newer one to be pulled from the cloud, so we do nothing here
                print("Warning in \(self.parseClassName).compareUpdate(). KnowledgeVector in Cloud \(parse.logicalClock) >= \(self.logicalClock). This should never occur. It should get fixed in next pullRevision. Local: \(self)... Cloud: \(parse)")
            }
            return nil
        }
    }
}

