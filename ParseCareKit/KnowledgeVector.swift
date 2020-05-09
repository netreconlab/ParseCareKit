//
//  KnowledgeVector.swift
//  ParseCareKit
//
//  Created by Corey Baker on 5/9/20.
//  Copyright © 2020 University of Kentucky. All rights reserved.
//

import Parse
import CareKitStore

open class KnowledgeVector: PFObject, PFSubclassing {
    //1 to 1 between Parse and CareStore
    @NSManaged public var user:User
    @NSManaged public var vector:String
    @NSManaged public var uuid:String
    
    public static func parseClassName() -> String {
        return kPCKKnowledgeVectorClassKey
    }
    
    public override init() {
        super.init()
        uuid = UUID.init().uuidString
    }
}
