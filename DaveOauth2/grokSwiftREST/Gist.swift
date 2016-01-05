//
//  Gist.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2015-11-29.
//  Copyright © 2015 Teak Mobile Inc. All rights reserved.
//

import Foundation
import SwiftyJSON

class Gist: ResponseJSONObjectSerializable {
  var id: String?
  var description: String?
  var ownerLogin: String?
  var ownerAvatarURL: String?
  var url: String?
  var files:[File]?  // array of File objects
  var createdAt:NSDate?
  var updatedAt:NSDate?
  
  // have all gists share a single instance of a dateformatter to save processor time.
  static let sharedDateFormatter = Gist.dateFormatter()
  
  required init(json: JSON) {
    self.description = json["description"].string
    self.id = json["id"].string
    self.ownerLogin = json["owner"]["login"].string
    self.ownerAvatarURL = json["owner"]["avatar_url"].string
    self.url = json["url"].string
    
    self.files = [File]()  // init an array of File objects
    if let filesJSON = json["files"].dictionary {
        for (_, fileJSON) in filesJSON {
            if let newFile = File(json: fileJSON) {
                self.files?.append(newFile)
            }
        }
    }
    
    let dateFormatter = Gist.sharedDateFormatter
    if let dateString = json["createdat"].string {
        self.createdAt = dateFormatter.dateFromString(dateString)
    }
    if let dateString = json["updated_at"].string {
        self.updatedAt = dateFormatter.dateFromString(dateString)
    }
    
  }
  
  required init() { }
    
    // This function returns a NSDateFromatter object that has 
    // ben setup to work in a certain way.
    class func dateFormatter() -> NSDateFormatter {
        let aDateFormatter = NSDateFormatter()
        aDateFormatter.dateFormat = "yyy-MM-dd'T'HH:mm:ssZ"
        aDateFormatter.timeZone = NSTimeZone(abbreviation: "UTC")
        aDateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSTX")
        return aDateFormatter
    }
}