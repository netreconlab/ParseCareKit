//
//  Clock.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/9/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore

class Clock: PFObject, PFSubclassing {
    @NSManaged public var uuid:String
    @NSManaged public var vector:String
    
    static func parseClassName() -> String {
        return kPCKClockClassKey
    }
    
    convenience init(uuid: UUID) {
        self.init()
        self.uuid = uuid.uuidString
        self.vector = "{\"processes\":[{\"id\":\"\(self.uuid)\",\"clock\":0}]}"
    }
    
    func decodeClock(completion:@escaping(OCKRevisionRecord.KnowledgeVector?)->Void){
        guard let data = self.vector.data(using: .utf8) else{
            print("Error in KnowlegeVector. Couldn't get data as utf8")
            return
        }
        
        let cloudClock:OCKRevisionRecord.KnowledgeVector?
        do {
            cloudClock = try JSONDecoder().decode(OCKRevisionRecord.KnowledgeVector.self, from: data)
        }catch{
            let error = error
            print("Error in Clock.decodeClock(). Couldn't decode vector \(data). Error: \(error)")
            cloudClock = nil
        }
        completion(cloudClock)
    }
    
    func encodeClock(_ clock: OCKRevisionRecord.KnowledgeVector)->String?{
        do{
            let json = try JSONEncoder().encode(clock)
            let cloudClockString = String(data: json, encoding: .utf8)!
            self.vector = cloudClockString
            return self.vector
        }catch{
            let error = error
            print("Error in Clock.encodeClock(). Couldn't encode vector \(clock). Error: \(error)")
            return nil
        }
    }
    
    class func fetchFromCloud(uuid:UUID, createNewIfNeeded:Bool, completion:@escaping(Clock?,OCKRevisionRecord.KnowledgeVector?,Error?)->Void){
        
        //Fetch Clock from Cloud
        let query = Clock.query()!
        query.whereKey(kPCKClockPatientTypeUUIDKey, equalTo: uuid.uuidString)
        query.getFirstObjectInBackground{ (object,error) in
            
            guard let foundVector = object as? Clock else{
                if !createNewIfNeeded{
                    completion(nil,nil,error)
                }else{
                    //This is the first time the Clock is user setup for this user
                    let newVector = Clock(uuid: uuid)
                    newVector.decodeClock(){
                        possiblyDecoded in
                        completion(newVector,possiblyDecoded,error)
                    }
                }
                return
            }
            foundVector.decodeClock(){
                possiblyDecoded in
                completion(foundVector,possiblyDecoded,error)
            }
        }
    }
}
