//
//  OutcomeValues.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/15/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore


open class OutcomeValue: PCKObject, PFSubclassing {

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
        _ = self.copyCareKit(careKitEntity)
    }
    
    open override func copyCommonValues(from other: PCKObject){
        super.copyCommonValues(from: other)
        guard let other = other as? OutcomeValue else{return}
        self.index = other.index
        self.kind = other.kind
        self.units = other.units
        self.typeString = other.typeString
        self.textValue = other.textValue
        self.binaryValue = other.binaryValue
        self.booleanValue = other.booleanValue
        self.integerValue = other.integerValue
        self.doubleValue = other.doubleValue
        self.dateValue = other.dateValue
    }
    
    open func copyCareKit(_ outcomeValue: OCKOutcomeValue) -> OutcomeValue? {
        
        if let uuid = OutcomeValue.getUUIDFromCareKitEntity(outcomeValue) {
            self.uuid = uuid
        }else{
            print("Warning in \(parseClassName).copyCareKit(). Entity missing uuid: \(outcomeValue)")
        }
        
        if let schemaVersion = OutcomeValue.getSchemaVersionFromCareKitEntity(outcomeValue){
            self.schemaVersion = schemaVersion
        }else{
            print("Warning in \(parseClassName).copyCareKit(). Entity missing schemaVersion: \(outcomeValue)")
        }
        self.timezone = outcomeValue.timezone.abbreviation()!
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
        self.remoteID = outcomeValue.remoteID
        self.createdDate = outcomeValue.createdDate
        self.notes = outcomeValue.notes?.compactMap{Note(careKitEntity: $0)}
        
        
        return self
    }
    
    open func convertToCareKit(fromCloud:Bool=true)->OCKOutcomeValue?{
        
        var outcomeValue:OCKOutcomeValue!
        if fromCloud{
            guard let decodedOutcomeValue = decodedCareKitObject(self.value, units: units)else{
                print("Error in \(parseClassName). Couldn't decode entity \(self)")
                return nil
            }
            outcomeValue = decodedOutcomeValue
        }else{
            //Create bare Entity and replace contents with Parse contents
            outcomeValue = OCKOutcomeValue(self.value, units: self.units)
        }
        outcomeValue.remoteID = self.remoteID
        outcomeValue.index = self.index as? Int
        outcomeValue.kind = self.kind
        outcomeValue.groupIdentifier = self.groupIdentifier
        outcomeValue.tags = self.tags
        outcomeValue.source = self.source
        outcomeValue.notes = self.notes?.compactMap{$0.convertToCareKit()}
        outcomeValue.remoteID = self.remoteID
        outcomeValue.userInfo = self.userInfo
        if let timeZone = TimeZone(abbreviation: self.timezone){
            outcomeValue.timezone = timeZone
        }
        return outcomeValue
    }
    
    func stamp(_ clock: Int){
        self.logicalClock = clock
        self.notes?.forEach{
            $0.logicalClock = self.logicalClock
        }
    }
    
    open class func replaceWithCloudVersion(_ local:inout [OutcomeValue], cloud:[OutcomeValue]){
        for (index,value) in local.enumerated(){
            guard let cloudNote = cloud.filter({$0.uuid == value.uuid}).first else{
                continue
            }
            local[index] = cloudNote
        }
    }
}

