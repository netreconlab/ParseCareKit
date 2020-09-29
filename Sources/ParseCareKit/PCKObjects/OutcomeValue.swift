//
//  OutcomeValues.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/15/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore


public class OutcomeValue: PCKObject {

    public var index:Int?
    public var kind:String?
    public var units:String?
    
    //private var typeString: String?
    var type: OCKOutcomeValueType? /*{
        get {
            guard let type = typeString else {
                return nil
            }
            return OCKOutcomeValueType(rawValue: type)
        }
        set { typeString = newValue?.rawValue }
    }*/

    var textValue: String?
    var binaryValue: Data?
    var booleanValue: Bool?
    var integerValue: Int?
    var doubleValue: Double?
    var dateValue: Date?

    var value: OCKOutcomeValueUnderlyingType? /*{
        get {
            guard let valueType = type else {
                return nil
            }
            switch valueType {
            case .integer:
                guard let integerValue = integerValue else {
                    return nil
                }
                return Int(integerValue)
            case .double: return doubleValue
            case .boolean: return booleanValue
            case .text: return textValue
            case .binary: return binaryValue
            case .date: return dateValue
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
    }*/

    private func reset() {
        textValue = nil
        binaryValue = nil
        booleanValue = nil
        integerValue = nil
        doubleValue = nil
        dateValue = nil
        index = nil
    }

    override init() {
        super.init()
    }
    
    public convenience init?(careKitEntity:OCKOutcomeValue) {
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
        case index, kind, units, textValue, binaryValue
        case booleanValue, integerValue, doubleValue, dateValue
    }
    
    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(kind, forKey: .kind)
        try container.encode(units, forKey: .units)
        try container.encode(textValue, forKey: .textValue)
        try container.encode(binaryValue, forKey: .binaryValue)
        try container.encode(booleanValue, forKey: .booleanValue)
        try container.encode(integerValue, forKey: .integerValue)
        try container.encode(doubleValue, forKey: .doubleValue)
        try container.encode(dateValue, forKey: .dateValue)
    }
    
    open override func copyCommonValues(from other: PCKObject){
        super.copyCommonValues(from: other)
        guard let other = other as? OutcomeValue else{return}
        self.index = other.index
        self.kind = other.kind
        self.units = other.units
        self.type = other.type
        self.textValue = other.textValue
        self.binaryValue = other.binaryValue
        self.booleanValue = other.booleanValue
        self.integerValue = other.integerValue
        self.doubleValue = other.doubleValue
        self.dateValue = other.dateValue
    }
    
    open func copyCareKit(_ outcomeValue: OCKOutcomeValue) throws -> OutcomeValue {
        let encoded = try JSONEncoder().encode(outcomeValue)
        let decoded = try JSONDecoder().decode(Self.self, from: encoded)
        self.copyCommonValues(from: decoded)
        return self
        /*
        if let uuid = OutcomeValue.getUUIDFromCareKitEntity(outcomeValue) {
            self.uuid = uuid
        }else{
            print("Warning in \(className).copyCareKit(). Entity missing uuid: \(outcomeValue)")
        }
        
        if let schemaVersion = OutcomeValue.getSchemaVersionFromCareKitEntity(outcomeValue){
            self.schemaVersion = schemaVersion
        }else{
            print("Warning in \(className).copyCareKit(). Entity missing schemaVersion: \(outcomeValue)")
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
        
        
        return self*/
    }
    
    open func convertToCareKit(fromCloud:Bool=true) throws -> OCKOutcomeValue {
        
        let encoded = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(OCKOutcomeValue.self, from: encoded)
        
        /*
        //If super passes, can safely force unwrap entityId, timeZone
        guard self.canConvertToCareKit() == true,
              let value = self.value else {
            return nil
        }
        
        var outcomeValue:OCKOutcomeValue!
        if fromCloud{
            guard let decodedOutcomeValue = decodedCareKitObject(value, units: units)else{
                print("Error in \(className). Couldn't decode entity \(self)")
                return nil
            }
            outcomeValue = decodedOutcomeValue
        }else{
            //Create bare Entity and replace contents with Parse contents
            outcomeValue = OCKOutcomeValue(value, units: self.units)
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
        if let timeZone = TimeZone(abbreviation: self.timezone!){
            outcomeValue.timezone = timeZone
        }
        return outcomeValue*/
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

