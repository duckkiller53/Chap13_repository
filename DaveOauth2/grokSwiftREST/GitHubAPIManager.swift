//
//  GitHubAPIManager.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2015-11-29.
//  Copyright © 2015 Teak Mobile Inc. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON
import Locksmith

class GitHubAPIManager {
  static let sharedInstance = GitHubAPIManager()
  var alamofireManager: Alamofire.Manager
  var OAuthTokenCompletionHandler:(NSError? -> Void)?
    
  let clientID: String = "a69c6c89a54dea7f3b9a"
  let clientSecret: String = "1f2b6b8f02df928395e7c48b39c8d5722626a0a1"
  static let ErrorDomain = "com.error.GitHubAPIManager"
    
  // computed property with Locksmith to store the token.  Locksmith is
  // a library to store secure data in the IOS keychain.
  var OAuthToken: String? {
    set
    {
        if let valueToSave = newValue
        {
            do
            {
                // updateData saves and updates.  saveData would throw an error
                // if a key existed already.
                try Locksmith.updateData(["token": valueToSave], forUserAccount: "github")
            } catch
            {
                let _  = try? Locksmith.deleteDataForUserAccount("github")
            }
        }
        else
        {
            // they set it to nil, so delete it
            let _ = try? Locksmith.deleteDataForUserAccount("github")
        }
    }
    get
    {
       //try to load from keychain
       Locksmith.loadDataForUserAccount("github")
       let dictionary = Locksmith.loadDataForUserAccount("github")
       if let token = dictionary?["token"] as? String
       {
          return token
       }
       return nil
    }
  }
    
  
  init () {
    let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
    alamofireManager = Alamofire.Manager(configuration: configuration)
  }
    
  func hasOAuthToken() -> Bool {
    if let token = self.OAuthToken {
        // Note: isEmpty is true if token kas no characters.
        return !token.isEmpty
    }
    return false
  }
    
  // MARK:  - OAuth Flow
    
  func URLToStartOAuth2Login() -> NSURL? {
    let authPath: String = "https://github.com/login/oauth/authorize" +
       "?client_id=\(clientID)&scope=gists&state=TEST_STATE"
    guard let authURL:NSURL = NSURL(string: authPath) else {
        return nil
    }
    
    return authURL
    
  }
    
    
  // MARK: - Basic Auth  Not called anymore.
  func printMyStarredGistsWithBasicAuth2() -> Void
  {
      let starredGistsREquest = Alamofire.request(GistRouter.GetMyStarred())
          .responseString { response in
            guard response.result.error == nil else {
                print(response.result.error!)
                return
            }
              if let receivedString = response.result.value
              {
                // David added this to reset flag
                let defaults = NSUserDefaults.standardUserDefaults()
                defaults.setBool(false, forKey: "loadingOAuthToken")
                  print(receivedString)
              }
        }
    
       debugPrint(starredGistsREquest)
  }


  func printPublicGists() -> Void {
    alamofireManager.request(GistRouter.GetPublic())
    .responseString { response in
      if let receivedString = response.result.value {
        print(receivedString)
      }
    }
  }
    
  /*
    This is step one of the Oauth dance.  This is called from the 
    AppDelegate.swift function handleOpenURL
  */
  func processOAuthStep1Response(url: NSURL)
  {
    let components = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)
    var code: String?
    if let queryItems = components?.queryItems
    {
        for queryItem in queryItems
        {
            if (queryItem.name.lowercaseString == "code")
            {
                code = queryItem.value
                break
            }
            
            if (queryItem.name.lowercaseString == "error")
            {
                print(queryItem.value)
            }
        }
    }
    
    // If we get a code, make call for the Token
    if let receivedCode = code
    {
        swapAuthCodeForToken(receivedCode)
    } else
    {
        // no code in URL that we launched with
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setBool(false, forKey: "loadingOAuthToken")
        
        if let completionHandler = self.OAuthTokenCompletionHandler {
            let noCodeInResponseError = NSError(domain: GitHubAPIManager.ErrorDomain, code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Could not obtain an OAuthcode",
                    NSLocalizedRecoverySuggestionErrorKey: "Please retry your request"])
            completionHandler(noCodeInResponseError)
        }
    }
    
  }
    
    func swapAuthCodeForToken(receivedCode: String) {
        
        let getTokenPath:String = "https://github.com/login/oauth/access_token"
            let tokenParams = ["client_id": clientID, "client_secret": clientSecret,
                "code": receivedCode]
            let jsonHeader = ["Accept": "application/json"]
            Alamofire.request(.POST, getTokenPath, parameters: tokenParams,
                headers: jsonHeader)
                .responseString { response in
                    
                    if let error = response.result.error {
                        // Set our user defaults flag that we now have a token.
                        let defaults = NSUserDefaults.standardUserDefaults()
                        defaults.setBool(false, forKey: "loadingOAuthToken")
                        print(error)
                        
                        if let completionHandler = self.OAuthTokenCompletionHandler {
                            completionHandler(error)
                        }
                        return
                    }
                    print(response.result.value)
                    
                    // convert the data to json, loop through key value pairs and find the token.
                    if let receivedResults = response.result.value, jsonData = receivedResults.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false) {
                        let jsonResults = JSON(data: jsonData)
                        for (key, value) in jsonResults {
                            switch key {
                            case "access_token":
                                self.OAuthToken = value.string
                            case "scope":
                                // TODO: verify scope
                                print("SET SCOPE")
                            case "token_type":
                                // TODO: verify is bearer
                                print("CHECK IF BEARER")
                            default:
                                print("got more than I expected from the OAuth token exchange")
                                print(key)
                            }
                        }
                    }
                    
                    
                    // Set our user defaults flag that we now have a token.
                    let defaults = NSUserDefaults.standardUserDefaults()
                    defaults.setBool(false, forKey: "loadingOAuthToken")
                   
                    if let completionHandler = self.OAuthTokenCompletionHandler {
                        if (self.hasOAuthToken()) {
                            completionHandler(nil)
                        } else {
                            let noOAuthError = NSError(domain: GitHubAPIManager.ErrorDomain, code: -1, userInfo:
                                [NSLocalizedDescriptionKey: "Could not obteain an OAuth token",
                                    NSLocalizedRecoverySuggestionErrorKey: "Please retry your request"])
                            
                            completionHandler(noOAuthError)
                        }
                    }
                    
            }
    }
  
  func getGists(urlRequest: URLRequestConvertible, completionHandler: (Result<[Gist], NSError>, String?) -> Void) {
    alamofireManager.request(urlRequest)
      .validate()
      .responseArray { (response:Response<[Gist], NSError>) in
        // Begin handler
        
          if let urlResponse = response.response,
            authError = self.checkUnauthorized(urlResponse) {
                completionHandler(.Failure(authError), nil)
                return
        }
        guard response.result.error == nil,
        let gists = response.result.value else {
          print(response.result.error)
         // completion bubbles up with error to getPublicGists
          completionHandler(response.result, nil)
          return
        }
        
        // need to figure out if this is the last page
        // check the link header, if present.
        let next = self.getNextPageFromHeaders(response.response)
        completionHandler(.Success(gists), next) // bubbles up to getPublicGists
        
        // End handler
    }
  }
  
  func getPublicGists(pageToLoad: String?, completionHandler: (Result<[Gist], NSError>, String?) -> Void) {
    
    if let urlString = pageToLoad {
      getGists(GistRouter.GetAtPath(urlString), completionHandler: completionHandler)
    } else {
      getGists(GistRouter.GetPublic(), completionHandler: completionHandler)
    }
    
  }
    
   func getMyStarredGists(pageToLoad: String?, completionHandler:
    (Result<[Gist], NSError>, String?) -> Void) {
        
        // Note: completion handler bubbles up to LoadGists
        if let urlString = pageToLoad {
            getGists(GistRouter.GetAtPath(urlString), completionHandler: completionHandler)
        } else {
            getGists(GistRouter.GetMyStarred(), completionHandler: completionHandler)
        }
    }
    
    func getMyGists(pageToLoad: String?, completionHandler:
        (Result<[Gist], NSError>, String?) -> Void)
    {
            if let urlString = pageToLoad
            {
                getGists(GistRouter.GetAtPath(urlString), completionHandler: completionHandler)
            }
            else
            {
                getGists(GistRouter.GetMine(), completionHandler: completionHandler)
            }
    }
    
    func checkUnauthorized(urlResponse: NSHTTPURLResponse) -> (NSError?)
    {
        if (urlResponse.statusCode == 401)
        {
            self.OAuthToken = nil
            let lostOAuthError = NSError(domain: NSURLErrorDomain,
                code: NSURLErrorUserAuthenticationRequired,
                userInfo: [NSLocalizedDescriptionKey: "Not Logged In",
                    NSLocalizedRecoverySuggestionErrorKey: "Please re-enter your GitHub credentials"])
            return lostOAuthError
        }
        return nil
    }
    
    
  func imageFromURLString(imageURLString: String, completionHandler:
    (UIImage?, NSError?) -> Void) {
    alamofireManager.request(.GET, imageURLString)
      .response { (request, response, data, error) in
      // use the generic response serializer that returns NSData
      if data == nil {
        completionHandler(nil, nil)
        return
      }
      let image = UIImage(data: data! as NSData)
      completionHandler(image, nil)
    }
  }
  
  private func getNextPageFromHeaders(response: NSHTTPURLResponse?) -> String? {
    if let linkHeader = response?.allHeaderFields["Link"] as? String {
      /* looks like:
      <https://api.github.com/user/20267/gists?page=2>; rel="next", <https://api.github.com/user/20267/gists?page=6>; rel="last"
      */
      // so split on "," then on  ";"
      let components = linkHeader.characters.split {$0 == ","}.map { String($0) }
      // now we have 2 lines like
      // '<https://api.github.com/user/20267/gists?page=2>; rel="next"'
      // So let's get the URL out of there:
      for item in components {
        // see if it's "next"
        let rangeOfNext = item.rangeOfString("rel=\"next\"", options: [])
          if rangeOfNext != nil {
          let rangeOfPaddedURL = item.rangeOfString("<(.*)>;",
          options: .RegularExpressionSearch)
          if let range = rangeOfPaddedURL {
            let nextURL = item.substringWithRange(range)
            // strip off the < and >;
            let startIndex = nextURL.startIndex.advancedBy(1)
            let endIndex = nextURL.endIndex.advancedBy(-2)
            let urlRange = startIndex..<endIndex
            return nextURL.substringWithRange(urlRange)
          }
        }
      }
    }
    return nil
  }
}