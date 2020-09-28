//
//  KnowledgeVector.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/9/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import ParseSwift
import CareKitStore

struct KnowledgeVector: ParseObject {
    var objectId: String?
    
    var createdAt: Date?
    
    var updatedAt: Date?
    
    var ACL: ParseACL?
    
    var uuid:String

    var vector:String

    init(uuid: UUID) {
        self.uuid = uuid.uuidString
        self.vector = "{\"processes\":[{\"id\":\"\(self.uuid)\",\"clock\":0}]}"
    }
    
    func decodeKnowledgeVector(completion:@escaping(OCKRevisionRecord.KnowledgeVector?)->Void){
        guard let data = self.vector.data(using: .utf8) else{
            print("Error in KnowlegeVector. Couldn't get data as utf8")
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
    
    mutating func encodeKnowledgeVector(_ knowledgeVector: OCKRevisionRecord.KnowledgeVector)->String?{
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
    
    static func fetchFromCloud(uuid:UUID, createNewIfNeeded:Bool, completion:@escaping(KnowledgeVector?, OCKRevisionRecord.KnowledgeVector?, ParseError?)->Void){
        
        //Fetch KnowledgeVector from Cloud
        let query = KnowledgeVector.query(kPCKKnowledgeVectorPatientTypeUUIDKey == uuid.uuidString)
        query.first(callbackQueue: .global(qos: .background)) { result in
            
            switch result {
            
            case .success(let foundVector):
                foundVector.decodeKnowledgeVector(){
                    possiblyDecoded in
                    completion(foundVector, possiblyDecoded, nil)
                }
            case .failure(let error):
                if !createNewIfNeeded{
                    completion(nil, nil, error)
                }else{
                    //This is the first time the KnowledgeVector is user setup for this user
                    let newVector = KnowledgeVector(uuid: uuid)
                    newVector.decodeKnowledgeVector(){
                        possiblyDecoded in
                        completion(newVector,possiblyDecoded,error)
                    }
                }
            }
        }
    }
}
