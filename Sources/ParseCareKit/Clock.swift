//
//  Clock.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/9/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import ParseSwift
import CareKitStore

struct Clock: ParseObject {
    var objectId: String?
    
    var createdAt: Date?
    
    var updatedAt: Date?
    
    var ACL: ParseACL?
    
    var uuid:UUID?

    var vector:String?

    init(uuid: UUID) {
        self.uuid = uuid
        self.vector = "{\"processes\":[{\"id\":\"\(self.uuid!.uuidString)\",\"clock\":0}]}"
    }
    
    func decodeClock(completion:@escaping(OCKRevisionRecord.KnowledgeVector?)->Void){
        guard let data = self.vector?.data(using: .utf8) else{
            print("Error in Clock. Couldn't get data as utf8")
            return
        }
        
        let cloudVector:OCKRevisionRecord.KnowledgeVector?
        do {
            cloudVector = try JSONDecoder().decode(OCKRevisionRecord.KnowledgeVector.self, from: data)
        }catch{
            let error = error
            print("Error in Clock.decodeClock(). Couldn't decode vector \(data). Error: \(error)")
            cloudVector = nil
        }
        completion(cloudVector)
    }
    
    mutating func encodeClock(_ clock: OCKRevisionRecord.KnowledgeVector)->String?{
        do{
            let json = try JSONEncoder().encode(clock)
            let cloudVectorString = String(data: json, encoding: .utf8)!
            self.vector = cloudVectorString
            return self.vector
        }catch{
            let error = error
            print("Error in Clock.encodeClock(). Couldn't encode vector \(clock). Error: \(error)")
            return nil
        }
    }
    
    static func fetchFromCloud(uuid:UUID, createNewIfNeeded:Bool, completion:@escaping(Clock?, OCKRevisionRecord.KnowledgeVector?, ParseError?)->Void){
        
        //Fetch Clock from Cloud
        let query = Clock.query(kPCKClockPatientTypeUUIDKey == uuid)
        query.first(callbackQueue: .main) { result in
            
            switch result {
            
            case .success(let foundVector):
                foundVector.decodeClock(){
                    possiblyDecoded in
                    completion(foundVector, possiblyDecoded, nil)
                }
            case .failure(let error):
                if !createNewIfNeeded{
                    completion(nil, nil, error)
                }else{
                    //This is the first time the Clock is user setup for this user
                    let newVector = Clock(uuid: uuid)
                    newVector.decodeClock(){
                        possiblyDecoded in
                        completion(newVector,possiblyDecoded,error)
                    }
                }
            }
        }
    }
}
