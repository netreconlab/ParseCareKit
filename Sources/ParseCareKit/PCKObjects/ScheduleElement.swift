//
//  ScheduleElement.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/18/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore

public class ScheduleElement: ParseObject {
    public var objectId: String?
    
    public var createdAt: Date?
    
    public var updatedAt: Date?
    
    public var ACL: ParseACL? = try? ParseACL.defaultACL()
    

    //1 to 1 between Parse and CareStore
    public var elements:[ScheduleElement]?
    public var end:Date?
    public var interval:DateComponents?
    public var start:Date?
    public var text:String?
    public var targetValues:[OutcomeValue]?
    public var logicalClock:Int?
    public var duration: OCKScheduleElement.Duration?

    public init?(careKitEntity:OCKScheduleElement) {
        do {
            _ = try self.copyCareKit(careKitEntity)
        } catch {
            return nil
        }
    }
    /*
    enum CodingKeys: String, CodingKey {
        case elements, end, interval, start, text, targetValues, logicalClock, duration
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(elements, forKey: .elements)
        try container.encode(end, forKey: .end)
        try container.encode(interval, forKey: .interval)
        try container.encode(start, forKey: .start)
        try container.encode(text, forKey: .text)
        try container.encode(targetValues, forKey: .targetValues)
        try container.encode(duration, forKey: .duration)
        try container.encode(logicalClock, forKey: .logicalClock)
    }*/
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        elements = try container.decode([ScheduleElement].self, forKey: .elements)
        end = try container.decode(Date.self, forKey: .end)
        interval = try container.decode(DateComponents.self, forKey: .interval)
        start = try container.decode(Date.self, forKey: .start)
        text = try container.decode(String.self, forKey: .text)
        targetValues = try container.decode([OutcomeValue].self, forKey: .targetValues)
        duration = try container.decode(OCKScheduleElement.Duration.self, forKey: .duration)
        logicalClock = try container.decode(Int.self, forKey: .logicalClock)
    }
    
    func copyCareKit(_ scheduleElement: OCKScheduleElement) throws -> ScheduleElement {
        let encoded = try JSONEncoder().encode(scheduleElement)
        return try JSONDecoder().decode(Self.self, from: encoded)
        //self.copyCommonValues(from: decoded)
        /*self.text = scheduleElement.text
        self.interval = scheduleElement.interval //CareKitInterval.era.convertToDictionary(scheduleElement.interval)
        self.start = scheduleElement.start
        self.end = scheduleElement.end
        self.duration = scheduleElement.duration
        self.targetValues = scheduleElement.targetValues.compactMap{OutcomeValue(careKitEntity: $0)}
        //self.elements = scheduleElement.elements.compactMap{ScheduleElement(careKitEntity: $0)}
        return self*/
    }
    
    //Note that CarePlans have to be saved to CareKit first in order to properly convert to CareKit
    open func convertToCareKit() throws -> OCKScheduleElement {
        let encoded = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(OCKScheduleElement.self, from: encoded)
        /*
        guard let interval = self.interval,
              let start = self.start,
              let targetValues = self.targetValues else {
            return nil
        }
        let schedhuleInterval = CareKitInterval.era.convertToDateComponents(interval)
        var scheduleElement = OCKScheduleElement(start: start, end: self.end, interval: schedhuleInterval)
        scheduleElement.targetValues = targetValues.compactMap{try? $0.convertToCareKit()}
        //scheduleElement.elements = self.elements.compactMap{$0.convertToCareKit()} //This is marked is get-only
        scheduleElement.text = self.text
        return scheduleElement*/
    }
    
    open class func replaceWithCloudVersion(_ local:inout [ScheduleElement], cloud:[ScheduleElement]){
        for (index,element) in local.enumerated(){
            guard let cloudNote = cloud.first(where: { try! $0.convertToCareKit() == element.convertToCareKit()}) else{
                continue
            }
            local[index] = cloudNote
        }
    }
    
    func stamp(_ clock: Int){
        self.logicalClock = clock
        self.elements?.forEach{
            $0.logicalClock = self.logicalClock
        }
    }
}
