//
//  ScheduleElement.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/18/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import ParseSwift
import CareKitStore

public class ScheduleElement: ParseObject {
    public var objectId: String?
    
    public var createdAt: Date?
    
    public var updatedAt: Date?
    
    public var ACL: ParseACL?
    

    //1 to 1 between Parse and CareStore
    public var elements:[ScheduleElement]?
    public var end:Date?
    public var interval:[String:Any]?
    public var start:Date?
    public var text:String?
    public var targetValues:[OutcomeValue]?
    public var logicalClock:Int?
    
    public static func className() -> String {
        return kAScheduleElementClassKey
    }

    public init(careKitEntity:OCKScheduleElement) {
        _ = self.copyCareKit(careKitEntity)
    }
    
    public func encode(to encoder: Encoder) throws {
        fatalError("init(from:) has not been implemented")
    }
    required public init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
    
    func copyCareKit(_ scheduleElement: OCKScheduleElement)->ScheduleElement{
        self.text = scheduleElement.text
        self.interval = CareKitInterval.era.convertToDictionary(scheduleElement.interval)
        self.start = scheduleElement.start
        self.end = scheduleElement.end
        self.targetValues = scheduleElement.targetValues.compactMap{OutcomeValue(careKitEntity: $0)}
        //self.elements = scheduleElement.elements.compactMap{ScheduleElement(careKitEntity: $0)}
        return self
    }
    
    //Note that CarePlans have to be saved to CareKit first in order to properly convert to CareKit
    open func convertToCareKit() -> OCKScheduleElement? {
        guard let interval = self.interval,
              let start = self.start,
              let targetValues = self.targetValues else {
            return nil
        }
        let schedhuleInterval = CareKitInterval.era.convertToDateComponents(interval)
        var scheduleElement = OCKScheduleElement(start: start, end: self.end, interval: schedhuleInterval)
        scheduleElement.targetValues = targetValues.compactMap{$0.convertToCareKit()}
        //scheduleElement.elements = self.elements.compactMap{$0.convertToCareKit()} //This is marked is get-only
        scheduleElement.text = self.text
        return scheduleElement
    }
    
    open class func replaceWithCloudVersion(_ local:inout [ScheduleElement], cloud:[ScheduleElement]){
        for (index,element) in local.enumerated(){
            guard let cloudNote = cloud.filter({$0.convertToCareKit() == element.convertToCareKit()}).first else{
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
