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


public class OutcomeValue: PCKObjectable {
    
    public internal(set) var uuid: UUID?
    
    var entityId: String?
    
    public var id: String {
        guard let returnId = entityId else {
            return ""
        }
        return returnId
    }
    
    public internal(set) var logicalClock: Int?
    
    public internal(set) var schemaVersion: OCKSemanticVersion?
    
    public internal(set) var createdDate: Date?
    
    public internal(set) var updatedDate: Date?
    
    public internal(set) var deletedDate: Date?
    
    public var timezone: TimeZone
    
    public var userInfo: [String : String]?
    
    public var groupIdentifier: String?
    
    public var tags: [String]?
    
    public var source: String?
    
    public var asset: String?
    
    public var notes: [Note]?
    
    public var remoteID: String?
    
    var encodingForParse: Bool = true
    
    public var objectId: String?
    
    public var createdAt: Date?
    
    public var updatedAt: Date?
    
    public var ACL: ParseACL?
    
    public var index:Int?
    public var kind:String?
    public var units:String?
    public var value: AnyCodable?
    var type: OCKOutcomeValueType?
    
    enum CodingKeys: String, CodingKey {
        case uuid, schemaVersion, createdDate, updatedDate, timezone, userInfo, groupIdentifier, tags, source, asset, remoteID, notes, logicalClock
        case index, kind, units, value, type
    }
    
    public static func copyValues(from other: OutcomeValue, to here: OutcomeValue) throws -> Self {
        var here = here
        here.copyCommonValues(from: other)
        here.index = other.index
        here.kind = other.kind
        here.units = other.units
        here.type = other.type
       
        guard let copied = here as? Self else {
            throw ParseCareKitError.cantCastToNeededClassType
        }
        return copied
    }
    
    open class func copyCareKit(_ outcomeValue: OCKOutcomeValue) throws -> OutcomeValue {
        let encoded = try JSONEncoder().encode(outcomeValue)
        let decoded = try JSONDecoder().decode(Self.self, from: encoded)
        return decoded
    }
    
    open func convertToCareKit(fromCloud:Bool=true) throws -> OCKOutcomeValue {
        let encoded = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(OCKOutcomeValue.self, from: encoded)
    }
    
    func stamp(_ clock: Int){
        self.logicalClock = clock
        self.notes?.forEach{
            $0.logicalClock = self.logicalClock
        }
    }
    
    open class func replaceWithCloudVersion(_ local:inout [OutcomeValue], cloud:[OutcomeValue]){
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
        try container.encodeIfPresent(value, forKey: .value)
        try self.encodeObjectable(to: encoder)
    }
}
