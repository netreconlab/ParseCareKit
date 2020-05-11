//
//  OutcomeValues.swift
//  ParseCareKit
//
//  Created by Corey Baker on 1/15/20.
//  Copyright © 2020 NetReconLab. All rights reserved.
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
    
    //UserInfo fields on CareStore
    @NSManaged public var entityId:String
    
    //SOSDatabase info
    @NSManaged public var sosDeliveredToDestinationAt:Date? //When was the outcome posted D2D
    
    public static func parseClassName() -> String {
        return kPCKOutcomeValueClassKey
    }
    
    public convenience init(careKitEntity:OCKOutcomeValue, store: OCKAnyStoreProtocol, completion: @escaping(PFObject?) -> Void) {
        self.init()
        self.copyCareKit(careKitEntity, store: store, completion: completion)
    }
    
    open func copyCareKit(_ outcomeValue: OCKOutcomeValue, store: OCKAnyStoreProtocol, completion: @escaping(OutcomeValue?) -> Void){
        
        guard let id = outcomeValue.userInfo?[kPCKOutcomeValueUserInfoEntityIdKey] else{
            print("Error in \(parseClassName).copyCareKit(). doesn't contain \(kPCKOutcomeValueUserInfoEntityIdKey) in \(String(describing: outcomeValue.userInfo))")
            completion(nil)
            return
        }
        self.entityId = id
        
        guard let uuid = getUUIDFromCareKit(outcomeValue) else{
            print("Error in \(parseClassName).copyCareKit(). doesn't contain a uuid")
            return
        }
        self.uuid = uuid
        
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
        
        Note.convertCareKitArrayToParse(outcomeValue.notes, store: store){
        copiedNotes in
            self.notes = copiedNotes
            completion(self)
        }
        
    }
    
    open func convertToCareKit()->OCKOutcomeValue?{
        
        guard var outcomeValue = createDeserializedEntity()else{return nil}
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
        
        var convertedUserInfo = [String:String]()
        convertedUserInfo[kPCKOutcomeValueUserInfoEntityIdKey] = self.entityId
        outcomeValue.userInfo = convertedUserInfo
        
        return outcomeValue
        
    }
    
    open func createDeserializedEntity()->OCKOutcomeValue?{
        guard let underlyingType = OCKOutcomeValueType(rawValue: self.type), let createdDate = self.locallyCreatedAt?.timeIntervalSinceReferenceDate,
            let updatedDate = self.locallyUpdatedAt?.timeIntervalSinceReferenceDate else{
                print("Error in \(parseClassName).createDeserializedEntity(). Missing either locallyCreatedAt \(String(describing: locallyCreatedAt)) or locallyUpdatedAt \(String(describing: locallyUpdatedAt))")
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
        let jsonString:String!
        do{
            let jsonData = try JSONEncoder().encode(outcomeValue)
            jsonString = String(data: jsonData, encoding: .utf8)!
        }catch{
            print("Error \(error)")
            return nil
        }
        
        //Create bare CareKit entity from json
        let insertValue = "\"uuid\":\"\(self.entityId)\",\"createdDate\":\(createdDate),\"updatedDate\":\(updatedDate)"
        guard let modifiedJson = ParseCareKitUtility.insertReadOnlyKeys(insertValue, json: jsonString),
            let data = modifiedJson.data(using: .utf8) else{return nil}
        let entity:OCKOutcomeValue!
        do {
            entity = try JSONDecoder().decode(OCKOutcomeValue.self, from: data)
        }catch{
            print("Error in \(parseClassName).createDeserializedEntity(). \(error)")
            return nil
        }
        return entity
    }
    
    open func getUUIDFromCareKit(_ entity: OCKOutcomeValue)->String?{
        let jsonString:String!
        do{
            let jsonData = try JSONEncoder().encode(entity)
            jsonString = String(data: jsonData, encoding: .utf8)!
        }catch{
            print("Error \(error)")
            return nil
        }
        let initialSplit = jsonString.split(separator: ",")
        let uuids = initialSplit.compactMap{ splitString -> String? in
            if splitString.contains("uuid"){
                let secondSplit = splitString.split(separator: ":")
                return String(secondSplit[1]).replacingOccurrences(of: "\"", with: "")
            }else{
                return nil
            }
        }
        
        if uuids.count == 0 {
            print("Error in \(parseClassName).getUUIDFromCareKit(). The UUID is missing in \(jsonString!) for entity \(entity)")
            return nil
        }else if uuids.count > 1 {
            print("Warning in \(parseClassName).getUUIDFromCareKit(). Found multiple UUID's, using first one in \(jsonString!) for entity \(entity)")
        }
        return uuids.first
    }
    
    open class func convertCareKitArrayToParse(_ values: [OCKOutcomeValue], store: OCKAnyStoreProtocol, completion: @escaping([OutcomeValue]) -> Void){
        
        var returnValues = [OutcomeValue]()
        
        if values.isEmpty{
            completion(returnValues)
            return
        }
        
        for (index,value) in values.enumerated(){
    
            let newOutcomeValue = OutcomeValue()
            newOutcomeValue.copyCareKit(value, store: store){
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
    
    func compareUpdate(_ careKit: OCKOutcomeValue, parse: OutcomeValue, store: OCKAnyStoreProtocol)->OCKOutcomeValue?{
        guard let careKitLastUpdated = careKit.updatedDate,
            let cloudUpdatedAt = parse.locallyUpdatedAt else{
            return nil
        }
        
        if cloudUpdatedAt < careKitLastUpdated{
            parse.copyCareKit(careKit, store: store){copiedCareKit in
                //An update may occur when Internet isn't available, try to update at some point
                copiedCareKit?.saveInBackground{(success, error) in
                    if !success{
                        print("Error in \(self.parseClassName).compareUpdate(). Couldn't update in cloud: \(careKit)")
                    }else{
                        print("Successfully updated \(self.parseClassName) \(self) in the Cloud")
                    }
                }
            }
        }else if cloudUpdatedAt > careKitLastUpdated {
            return parse.convertToCareKit()
        }
        
        return nil
    }
}

