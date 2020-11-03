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


final public class OutcomeValue: PCKObjectable {
    
    public internal(set) var uuid: UUID?
    
    var entityId: String?
    
    public internal(set) var logicalClock: Int?
    
    public internal(set) var schemaVersion: OCKSemanticVersion?
    
    public internal(set) var createdDate: Date?
    
    public internal(set) var updatedDate: Date?
    
    public var timezone: TimeZone
    
    public var userInfo: [String : String]?
    
    public var groupIdentifier: String?
    
    public var tags: [String]?
    
    public var source: String?
    
    public var asset: String?
    
    public var notes: [Note]?
    
    public var remoteID: String?
    
    var encodingForParse: Bool = true {
        willSet {
            prepareEncodingRelational(newValue)
        }
    }
    
    public var objectId: String?
    
    public var createdAt: Date?
    
    public var updatedAt: Date?
    
    public var ACL: ParseACL? = try? ParseACL.defaultACL()
    
    public var index:Int?
    public var kind:String?
    public var units:String?
    public var value: OCKOutcomeValueUnderlyingType?
    /// The underlying value as an integer.
    var integerValue: Int? { return value as? Int }

    /// The underlying value as a floating point number.
    var doubleValue: Double? { return value as? Double }

    /// The underlying value as a boolean.
    var booleanValue: Bool? { return value as? Bool }

    /// The underlying value as text.
    var stringValue: String? { return value as? String }

    /// The underlying value as binary data.
    var dataValue: Data? { return value as? Data }

    /// The underlying value as a date.
    var dateValue: Date? { return value as? Date }
    
    /// Holds information about the type of this value.
    public var type: OCKOutcomeValueType {
        if value is Int { return .integer }
        if value is Double { return .double }
        if value is Bool { return .boolean }
        if value is String { return .text }
        if value is Data { return .binary }
        if value is Date { return .date }
        fatalError("Unknown type!")
    }
    
    enum CodingKeys: String, CodingKey {
        case objectId, createdAt, updatedAt
        case uuid, schemaVersion, createdDate, updatedDate, timezone, userInfo, groupIdentifier, tags, source, asset, remoteID, notes, logicalClock
        case index, kind, units, value, type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let valueType = try container.decode(OCKOutcomeValueType.self, forKey: .type)

        if let valueDictionary = try? container.decodeIfPresent([String: AnyCodable].self, forKey: .value) {
            if let tempValue = valueDictionary[valueType.rawValue]?.value as? Int {
                value = tempValue
            } else if let tempValue = valueDictionary[valueType.rawValue]?.value as? Int {
                value = tempValue
            } else if let tempValue = valueDictionary[valueType.rawValue]?.value as? Double {
                value = tempValue
            } else if let tempValue = valueDictionary[valueType.rawValue]?.value as? String {
                value = tempValue
            } else if let tempValue = valueDictionary[valueType.rawValue]?.value as? Bool {
                value = tempValue
            } else if let tempValue = valueDictionary[valueType.rawValue]?.value as? Data {
                value = tempValue
            } else if let tempValue = valueDictionary[valueType.rawValue]?.value as? Date {
                value = tempValue
            }
        } else {
            switch valueType {
            case .integer:
                value = try container.decode(Int.self, forKey: .value)
            case .double:
                value = try container.decode(Double.self, forKey: .value)
            case .boolean:
                value = try container.decode(Bool.self, forKey: .value)
            case .text:
                value = try container.decode(String.self, forKey: .value)
            case .binary:
                value = try container.decode(Data.self, forKey: .value)
            case .date:
                value = try container.decode(Date.self, forKey: .value)
            }
        }
        ACL = try container.decodeIfPresent(ParseACL.self, forKey: .ACL)
        objectId = try container.decodeIfPresent(String.self, forKey: .objectId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        units = try container.decodeIfPresent(String.self, forKey: .units)
        index = try container.decodeIfPresent(Int.self, forKey: .index)
        uuid = try container.decodeIfPresent(UUID.self, forKey: .uuid)
        createdDate = try container.decodeIfPresent(Date.self, forKey: .createdDate)
        updatedDate = try container.decodeIfPresent(Date.self, forKey: .updatedDate)
        schemaVersion = try container.decodeIfPresent(OCKSemanticVersion.self, forKey: .schemaVersion)
        groupIdentifier = try container.decodeIfPresent(String.self, forKey: .groupIdentifier)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        remoteID = try container.decodeIfPresent(String.self, forKey: .remoteID)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        userInfo = try container.decodeIfPresent([String: String].self, forKey: .userInfo)
        timezone = try container.decode(TimeZone.self, forKey: .timezone)
        asset = try container.decodeIfPresent(String.self, forKey: .asset)
        notes = try container.decodeIfPresent([Note].self, forKey: .notes)
        ACL = try container.decodeIfPresent(ParseACL.self, forKey: .ACL)
    }

    public static func copyValues(from other: OutcomeValue, to here: OutcomeValue) throws -> Self {
        var here = here
        here.copyCommonValues(from: other)
        here.index = other.index
        here.kind = other.kind
        here.units = other.units
        here.value = other.value
       
        guard let copied = here as? Self else {
            throw ParseCareKitError.cantCastToNeededClassType
        }
        return copied
    }
    
    public class func copyCareKit(_ outcomeValue: OCKOutcomeValue) throws -> OutcomeValue {
        let encoded = try ParseCareKitUtility.encoder().encode(outcomeValue)
        let decoded = try ParseCareKitUtility.decoder().decode(Self.self, from: encoded)
        return decoded
    }
    
    public func convertToCareKit(fromCloud:Bool=true) throws -> OCKOutcomeValue {
        encodingForParse = false
        let encoded = try ParseCareKitUtility.encoder().encode(self)
        return try ParseCareKitUtility.decoder().decode(OCKOutcomeValue.self, from: encoded)
    }
    
    public func prepareEncodingRelational(_ encodingForParse: Bool) {
        notes?.forEach {
            $0.encodingForParse = encodingForParse
        }
    }

    func stamp(_ clock: Int){
        self.logicalClock = clock
        self.notes?.forEach{
            $0.logicalClock = self.logicalClock
        }
    }
    
    public class func replaceWithCloudVersion(_ local:inout [OutcomeValue], cloud:[OutcomeValue]){
        for (index,value) in local.enumerated(){
            guard let cloudNote = cloud.first(where: {$0.uuid == value.uuid}) else{
                continue
            }
            local[index] = cloudNote
        }
    }
}

extension OutcomeValue {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(units, forKey: .units)
        try container.encodeIfPresent(index, forKey: .index)
        if encodingForParse {
            var encodedValue = false
            if let value = integerValue { try container.encode([type.rawValue: value], forKey: .value); encodedValue = true } else
            if let value = doubleValue { try container.encode([type.rawValue: value], forKey: .value); encodedValue = true } else
            if let value = stringValue { try container.encode([type.rawValue: value], forKey: .value); encodedValue = true } else
            if let value = booleanValue { try container.encode([type.rawValue: value], forKey: .value); encodedValue = true } else
            if let value = dataValue { try container.encode([type.rawValue: value], forKey: .value); encodedValue = true } else
            if let value = dateValue { try container.encode([type.rawValue: value], forKey: .value); encodedValue = true }

            guard encodedValue else {
                let message = "Value could not be converted to a concrete type."
                throw EncodingError.invalidValue(value ?? "", EncodingError.Context(codingPath: [CodingKeys.value], debugDescription: message))
            }
        } else {
            var encodedValue = false
            if let value = integerValue { try container.encode(value, forKey: .value); encodedValue = true } else
            if let value = doubleValue { try container.encode(value, forKey: .value); encodedValue = true } else
            if let value = stringValue { try container.encode(value, forKey: .value); encodedValue = true } else
            if let value = booleanValue { try container.encode(value, forKey: .value); encodedValue = true } else
            if let value = dataValue { try container.encode(value, forKey: .value); encodedValue = true } else
            if let value = dateValue { try container.encode(value, forKey: .value); encodedValue = true }

            guard encodedValue else {
                let message = "Value could not be converted to a concrete type."
                throw EncodingError.invalidValue(value ?? "", EncodingError.Context(codingPath: [CodingKeys.value], debugDescription: message))
            }
        }
        try self.encodeObjectable(to: encoder)
        encodingForParse = true
    }
}
