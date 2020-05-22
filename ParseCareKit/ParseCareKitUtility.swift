//
//  ParseCareKitUtility.swift
//  ParseCareKit
//
//  Created by Corey Baker on 4/26/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

import Foundation

public class ParseCareKitUtility {
    
    public class func dateToString(_ date:Date)->String{
        let dateFormatter:DateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        
        return dateFormatter.string(from: date)
    }
    
    public class func stringToDate(_ date:String)->Date?{
        let dateFormatter:DateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        
        return dateFormatter.date(from: date)
    }
}
