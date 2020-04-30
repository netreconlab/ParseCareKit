//
//  OutcomeValues.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/15/20.
//  Copyright © 2020 NetReconLab. All rights reserved.
//

import Parse
import CareKit


open class OutcomeValue: PFObject, PFSubclassing {

    //Parse only
    @NSManaged public var userUploadedToCloud:User?
    @NSManaged public var userDeliveredToDestination:User?
    
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
    
    //UserInfo fields on CareStore
    @NSManaged public var uuid:String
    
    //SOSDatabase info
    @NSManaged public var sosDeliveredToDestinationAt:Date? //When was the outcome posted D2D
    
    public static func parseClassName() -> String {
        return kPCKOutcomeValueClassKey
    }
    
    public convenience init(careKitEntity:OCKOutcomeValue, storeManager: OCKSynchronizedStoreManager, completion: @escaping(PFObject?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, storeManager: storeManager, completion: completion)
    }
    
    open func copyCareKit(_ outcomeValue: OCKOutcomeValue, storeManager: OCKSynchronizedStoreManager, completion: @escaping(OutcomeValue?) -> Void){
        
        guard let id = outcomeValue.userInfo?[kPCKOutcomeValueUserInfoIDKey] else{
            print("Error in OutcomeValue.copyCareKit(). doesn't contain \(kPCKOutcomeValueUserInfoIDKey) in \(String(describing: outcomeValue.userInfo))")
            completion(nil)
            return
        }
        
        self.uuid = id
        //self.associatedID = associatedOutcome.id
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
        
        //Only copy this over if the Local Version is older than the Parse version
        if self.locallyCreatedAt == nil {
            self.locallyCreatedAt = outcomeValue.createdDate
        } else if self.locallyCreatedAt != nil && outcomeValue.createdDate != nil{
            if outcomeValue.createdDate! < self.locallyCreatedAt!{
                self.locallyCreatedAt = outcomeValue.createdDate
            }
        }
        
        Note.convertCareKitArrayToParse(outcomeValue.notes, storeManager: storeManager){
        copiedNotes in
            self.notes = copiedNotes
            completion(self)
        }
        
    }
    
    open func convertToCareKit()->OCKOutcomeValue?{
        
        guard let underlyingType = OCKOutcomeValueType(rawValue: self.type) else{
            return nil
        }
        
        var outcomeValue:OCKOutcomeValue? = nil
        
        switch underlyingType {
        
        case .integer:
            if let value = self.value[self.type] as? Int{
                outcomeValue = OCKOutcomeValue(value, units: self.units)
            }
        case .double:
            if let value = self.value[self.type] as? Double{
                outcomeValue = OCKOutcomeValue(value, units: self.units)
            }
        case .boolean:
            if let value = self.value[self.type] as? Bool{
                outcomeValue = OCKOutcomeValue(value, units: self.units)
            }
        case .text:
            if let value = self.value[self.type] as? String{
                outcomeValue = OCKOutcomeValue(value, units: self.units)
            }
        case .binary:
            if let value = self.value[self.type] as? Data{
                outcomeValue = OCKOutcomeValue(value, units: self.units)
            }
        case .date:
            if let value = self.value[self.type] as? Date{
                outcomeValue = OCKOutcomeValue(value, units: self.units)
            }
        }
        
        if outcomeValue != nil{
            
            //Can't set nil because of ObjC, make sure to guard against negative index when retreiving
            if self.index == -1 {
                outcomeValue!.index = nil
            }else{
                
                outcomeValue!.index = self.index
            }
            
            outcomeValue!.kind = self.kind
            outcomeValue!.groupIdentifier = self.groupIdentifier
            outcomeValue!.tags = self.tags
            outcomeValue!.source = self.source
            outcomeValue!.notes = self.notes?.compactMap{$0.convertToCareKit()}
            outcomeValue!.remoteID = self.objectId
            
            var convertedUserInfo = [String:String]()
            convertedUserInfo[kPCKOutcomeValueUserInfoIDKey] = self.uuid
            outcomeValue!.userInfo = convertedUserInfo
        }
        
        return outcomeValue
        
    }
    
    open class func convertCareKitArrayToParse(_ values: [OCKOutcomeValue], storeManager: OCKSynchronizedStoreManager, completion: @escaping([OutcomeValue]) -> Void){
        
        var returnValues = [OutcomeValue]()
        
        if values.isEmpty{
            completion(returnValues)
            return
        }
        
        for (index,value) in values.enumerated(){
    
            let newOutcomeValue = OutcomeValue()
            newOutcomeValue.copyCareKit(value, storeManager: storeManager){
                (valueFound) in
                if valueFound != nil{
                    returnValues.append(valueFound!)
                }
                //copyCareKit is async, so we need it to tell us when it's finished
                if index == (values.count-1){
                    completion(returnValues)
                }
            }
        }
    }
}

