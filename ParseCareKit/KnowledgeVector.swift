//
//  KnowledgeVector.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/9/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Parse
import CareKitStore

class KnowledgeVector: PFObject, PFSubclassing {
    @NSManaged public var userTypeUUID:String
    @NSManaged public var vector:String
    
    static func parseClassName() -> String {
        return kPCKKnowledgeVectorClassKey
    }
    
    convenience init(userTypeUUID: UUID) {
        self.init()
        self.userTypeUUID = userTypeUUID.uuidString
        self.vector = "{\"processes\":[{\"id\":\"\(self.userTypeUUID)\",\"clock\":0}]}"
    }
    
    func decodeKnowledgeVector(completion:@escaping(OCKRevisionRecord.KnowledgeVector?)->Void){
        guard let data = self.vector.data(using: .utf8) else{
            return
        }
        
        let cloudVector:OCKRevisionRecord.KnowledgeVector?
        do {
            cloudVector = try JSONDecoder().decode(OCKRevisionRecord.KnowledgeVector.self, from: data)
        }catch{
            let error = error
            print("Error in KnowledgeVector.decodeKnowledgeVector(). Couldn't decode vector \(data). Error: \(error)")
            cloudVector = nil
        }
        completion(cloudVector)
    }
    
    func encodeKnowledgeVector(_ knowledgeVector: OCKRevisionRecord.KnowledgeVector)->String?{
        do{
            let json = try JSONEncoder().encode(knowledgeVector)
            let cloudVectorString = String(data: json, encoding: .utf8)!
            self.vector = cloudVectorString
            return self.vector
        }catch{
            let error = error
            print("Error in KnowledgeVector.encodeKnowledgeVector(). Couldn't encode vector \(knowledgeVector). Error: \(error)")
            return nil
        }
    }
    
    class func fetchFromCloud(userTypeUUID:UUID, createNewIfNeeded:Bool, completion:@escaping(KnowledgeVector?,OCKRevisionRecord.KnowledgeVector?,Error?)->Void){
        
        //Fetch KnowledgeVector from Cloud
        let query = KnowledgeVector.query()!
        query.whereKey(kPCKKnowledgeVectorPatientTypeUUIDKey, equalTo: userTypeUUID)
        query.getFirstObjectInBackground{ (object,error) in
            
            guard let foundVector = object as? KnowledgeVector else{
                if !createNewIfNeeded{
                    completion(nil,nil,error)
                }else{
                    //This is the first time the KnowledgeVector is user setup for this user
                    let newVector = KnowledgeVector(userTypeUUID: userTypeUUID)
                    newVector.decodeKnowledgeVector(){
                        possiblyDecoded in
                        completion(newVector,possiblyDecoded,error)
                    }
                }
                return
            }
            foundVector.decodeKnowledgeVector(){
                possiblyDecoded in
                completion(foundVector,possiblyDecoded,error)
            }
        }
    }
}
