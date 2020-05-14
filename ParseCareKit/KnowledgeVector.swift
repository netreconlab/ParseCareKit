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
    //1 to 1 between Parse and CareStore
    @NSManaged public var user:User
    @NSManaged public var vector:String
    @NSManaged public var uuid:String
    
    static func parseClassName() -> String {
        return kPCKKnowledgeVectorClassKey
    }
    
    convenience init(uuid:UUID) {
        self.init()
        self.uuid = uuid.uuidString
        self.vector = "{\"processes\":[{\"id\":\"\(self.uuid)\",\"clock\":0}]}"
        guard let thisUser = User.current() else{
            return
        }
        self.user = thisUser
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
    
    class func fetchFromCloud(user:User, createNewIfNeeded:Bool, completion:@escaping(KnowledgeVector?,OCKRevisionRecord.KnowledgeVector?,UUID?)->Void){
        
        //Fetch KnowledgeVector from Cloud
        let query = KnowledgeVector.query()!
        query.whereKey(kPCKKnowledgeVectorUserKey, equalTo: user)
        query.getFirstObjectInBackground{ (object,error) in
            
            guard let foundVector = object as? KnowledgeVector else{
                if !createNewIfNeeded{
                    completion(nil,nil,nil)
                }else{
                    //This is the first time the KnowledgeVector is being setup for this user
                    let uuid = UUID()
                    let newVector = KnowledgeVector(uuid: uuid)
                    newVector.decodeKnowledgeVector(){
                        possiblyDecoded in
                        completion(newVector,possiblyDecoded,uuid)
                    }
                }
                return
            }
            foundVector.decodeKnowledgeVector(){
                possiblyDecoded in
                completion(foundVector,possiblyDecoded,UUID(uuidString: foundVector.uuid))
            }
        }
    }
}
