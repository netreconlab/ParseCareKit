//
//  ScheduleElement.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/18/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore

open class ScheduleElement: PFObject, PFSubclassing {

    //1 to 1 between Parse and CareStore
    @NSManaged public var elements:[ScheduleElement]
    @NSManaged public var end:Date?
    @NSManaged public var interval:[String:Any]
    @NSManaged public var start:Date
    @NSManaged public var text:String?
    @NSManaged public var targetValues:[OutcomeValue]
    @NSManaged public var logicalClock:Int
    
    public static func parseClassName() -> String {
        return kAScheduleElementClassKey
    }
    
    public convenience init(careKitEntity:OCKScheduleElement) {
        self.init()
        _ = self.copyCareKit(careKitEntity)
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
    open func convertToCareKit()->OCKScheduleElement{
        let interval = CareKitInterval.era.convertToDateComponents(self.interval)
        var scheduleElement = OCKScheduleElement(start: self.start, end: self.end, interval: interval)
        scheduleElement.targetValues = self.targetValues.compactMap{$0.convertToCareKit()}
        //scheduleElement.elements = self.elements.compactMap{$0.convertToCareKit()} //This is marked is get-only
        scheduleElement.text = self.text
        return scheduleElement
    }
    
    open class func updateIfNeeded(_ parse:[ScheduleElement], careKit: [OCKScheduleElement])->[ScheduleElement]{
        let indexesToDelete = parse.count - careKit.count
        if indexesToDelete > 0{
            let stopIndex = parse.count - 1 - indexesToDelete
            for index in stride(from: parse.count-1, to: stopIndex, by: -1) {
                parse[index].deleteInBackground()
            }
        }
        var updatedValues = [ScheduleElement]()
        for (index,value) in careKit.enumerated(){
            let updated:ScheduleElement
            //Replace if currently in cloud or create a new one
            if index <= parse.count-1{
                updated = parse[index].copyCareKit(value)
            }else{
                updated = ScheduleElement(careKitEntity: value)
            }
            updatedValues.append(updated)
        }
        return updatedValues
    }
    
    func stamp(_ clock: Int){
        self.logicalClock = clock
        self.elements.forEach{
            $0.logicalClock = self.logicalClock
        }
    }
}
