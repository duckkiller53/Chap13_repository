//
//  MasterViewController.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2015-10-20.
//  Copyright © 2015 Teak Mobile Inc. All rights reserved.
//

import UIKit
import PINRemoteImage
import SafariServices
import Alamofire

class MasterViewController: UITableViewController, LoginViewDelegate, SFSafariViewControllerDelegate {
  
  var detailViewController: DetailViewController? = nil
  var gists = [Gist]()
  var nextPageURLString: String?
  var isLoading = false
  var dateFormatter = NSDateFormatter()
  var safariViewController: SFSafariViewController?
    
    @IBOutlet weak var gistSegmentedControl: UISegmentedControl!
    
    
    @IBAction func segmentedControlValueChanged(sender: AnyObject) {
        loadGists(nil)
    }
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    self.navigationItem.leftBarButtonItem = self.editButtonItem()
    
    let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "insertNewObject:")
    self.navigationItem.rightBarButtonItem = addButton
    if let split = self.splitViewController {
      let controllers = split.viewControllers
      self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
    }
    
  }
    
  
  override func viewWillAppear(animated: Bool) {
    self.clearsSelectionOnViewWillAppear = self.splitViewController!.collapsed
    super.viewWillAppear(animated)
    
    // add refresh control for pull to refresh
    if (self.refreshControl == nil) {
      self.refreshControl = UIRefreshControl()
      self.refreshControl?.attributedTitle = NSAttributedString(string: "Pull to refresh")
      self.refreshControl?.addTarget(self, action: "refresh:",
        forControlEvents: UIControlEvents.ValueChanged)
      self.dateFormatter.dateStyle = NSDateFormatterStyle.ShortStyle
      self.dateFormatter.timeStyle = NSDateFormatterStyle.LongStyle
    }
  }
    
  override func viewDidAppear(animated: Bool) {
     super.viewDidAppear(animated)
    
    // Note: NSUserDefaults are only saved while app runs.
    let defaults = NSUserDefaults.standardUserDefaults()
    //defaults.setBool(false, forKey: "loadingOAuthToken")
    
    // false if we don't have a Token.
    if (!defaults.boolForKey("loadingOAuthToken")) {        
         loadInitialData()
    }
    
  }
   
  // show the login screen.
  func loadInitialData()
  {
    isLoading = true
    GitHubAPIManager.sharedInstance.OAuthTokenCompletionHandler = { (error) -> Void in
        self.safariViewController?.dismissViewControllerAnimated(true, completion: nil)
        if let error = error
        {
            print(error)
            self.isLoading = false
            // TODO: handle error
            // Something went wrong, try again
            self.showOAuthLoginView()
        } else {
            self.loadGists(nil)
        }
    }
    
    if(!GitHubAPIManager.sharedInstance.hasOAuthToken()) {
        self.showOAuthLoginView()
    } else {
        loadGists(nil)
    }
    
  }
    
    func showOAuthLoginView()
    {
        let storyboard = UIStoryboard(name: "Main", bundle: NSBundle.mainBundle())
        if let loginVC = storyboard.instantiateViewControllerWithIdentifier(
            "LoginViewController") as? LoginViewController {
                loginVC.delegate = self
                self.presentViewController(loginVC, animated: true, completion: nil)
        
        }
    }
    
  // When we call the url with safari the return to our app gets handled 
  // via our call from the AppDelegate.handleOpenURL call to 
  // processOAuthStep1Response()
  func didTapLoginButton() {
        
       // write to disc that were loading an OAuth Token.
       let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setBool(true, forKey: "loadingOAuthToken")
        
       self.dismissViewControllerAnimated(false, completion: nil)
        
        if let authURL = GitHubAPIManager.sharedInstance.URLToStartOAuth2Login() {
            safariViewController = SFSafariViewController(URL: authURL)
            safariViewController?.delegate = self
            if let webViewController = safariViewController {
                self.presentViewController(webViewController, animated: true, completion: nil)
            }
        } else {
            defaults.setBool(false, forKey: "loadingOAuthToken")
            
            // Note:  We set the completion handler in loadInitialData()
            //        then we get that completion handler and call it with
            //        our custom error of type NSError.
            if let completionHandler =
                GitHubAPIManager.sharedInstance.OAuthTokenCompletionHandler {
                    let error = NSError(domain: GitHubAPIManager.ErrorDomain, code: -1,
                        userInfo: [NSLocalizedDescriptionKey:
                        "Could not create an OAuth authorization URL",
                        NSLocalizedRecoverySuggestionErrorKey: "Please retry your request"])
                    completionHandler(error)
                    
            }
    }
        
    }
    
    // MARK:  Safari stuff
    
    func safariViewcontroller(controller: SFSafariViewController, didCompleteInitalLoad
        didLoadSuccessfully: Bool)
    {
        
        // Detect not being able to load the OAuth URL
            if (!didLoadSuccessfully)
            {
                let defaults = NSUserDefaults.standardUserDefaults()
                defaults.setBool(false, forKey: "loadingOAuthToken")
                if let completionHandler =
                    GitHubAPIManager.sharedInstance.OAuthTokenCompletionHandler
                {
                        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet,
                            userInfo: [NSLocalizedDescriptionKey: "No Internet Connection",
                                NSLocalizedRecoverySuggestionErrorKey: "Please retry your request"])
                        completionHandler(error)
                }
                
                // This is the safari view controller.
                controller.dismissViewControllerAnimated(true, completion: nil)
            }            
            
    }
    
    
    func loadGists(urlToLoad: String?) {
        
        self.isLoading = true
        let completionHandler: (Result<[Gist], NSError>, String?) -> Void =
        { (result, nextPage) in
            self.isLoading = false
            self.nextPageURLString = nextPage
            
            // tell refresh control it can stop showing up now
            if self.refreshControl != nil && self.refreshControl!.refreshing
            {
                self.refreshControl?.endRefreshing()
            }
            
            guard result.error == nil else {
                print(result.error)
                self.nextPageURLString = nil
                
                self.isLoading = false
                if let error = result.error {
                    if error.domain == NSURLErrorDomain &&
                        error.code == NSURLErrorUserAuthenticationRequired {
                            self.showOAuthLoginView()
                    }
                }
                return
            }
            
            if let fetchedGists = result.value {
                if self.nextPageURLString != nil {
                    self.gists += fetchedGists
                } else {
                    self.gists = fetchedGists
                }
            }
            
            // update "last updated" title for refresh control
            let now = NSDate()
            let updateString = "Last Updated at " + self.dateFormatter.stringFromDate(now)
            self.refreshControl?.attributedTitle = NSAttributedString(string: updateString)
            
            self.tableView.reloadData()
        }
        
        // Note: We pass in our completionHandler block of code, which will
        // get called if an error occurs.
        switch gistSegmentedControl.selectedSegmentIndex {
        case 0:
            GitHubAPIManager.sharedInstance.getPublicGists(urlToLoad, completionHandler:
                completionHandler)
        case 1:
            GitHubAPIManager.sharedInstance.getMyStarredGists(urlToLoad, completionHandler:
                completionHandler)
        case 2:
            GitHubAPIManager.sharedInstance.getMyGists(urlToLoad, completionHandler:
                completionHandler)
        default:
            print("got an index that I didn't expect for selectedSegmentIndex")
        }

        
    }
    
    func refresh(sender: AnyObject) {
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setBool(false, forKey: "loadingOAuthToken")
        
        nextPageURLString = nil // so it doesn't try to append the results
        loadInitialData()
    }

  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  func insertNewObject(sender: AnyObject) {
    let alert = UIAlertController(title: "Not Implemented", message: "Can't create new gists yet, will implement later", preferredStyle: UIAlertControllerStyle.Alert)
    alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
    self.presentViewController(alert, animated: true, completion: nil)
  }
  
  // MARK: - Segues
  
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    
    
    if segue.identifier == "showDetail"
    {
        if let indexPath = self.tableView.indexPathForSelectedRow
        {
            let gist = gists[indexPath.row] as Gist
            if let detailViewController = (segue.destinationViewController as! UINavigationController).topViewController as? DetailViewController
            {
                detailViewController.gist = gist
                detailViewController.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
                detailViewController.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }       
        
  }
  
  // MARK: - Table View
  
  override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return 1
  }
  
  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return gists.count
  }
  
  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
    
    let gist = gists[indexPath.row]
    cell.textLabel!.text = gist.description
    cell.detailTextLabel!.text = gist.ownerLogin
    cell.imageView?.image = nil
    
    // set cell.imageView to display image at gist.ownerAvatarURL
    if let urlString = gist.ownerAvatarURL, url = NSURL(string: urlString) {
      cell.imageView?.pin_setImageFromURL(url, placeholderImage:
      UIImage(named: "placeholder.png"))
    } else {
      cell.imageView?.image = UIImage(named: "placeholder.png")
    }
            
    // See if we need to load more gists
    let rowsToLoadFromBottom = 5;
    let rowsLoaded = gists.count
    if let nextPage = nextPageURLString {
      if (!isLoading && (indexPath.row >= (rowsLoaded - rowsToLoadFromBottom))) {
      self.loadGists(nextPage)
      }
    }
    
    return cell
  }
  
  override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    // Return false if you do not want the specified item to be editable.
    return true
  }
  
  override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    if editingStyle == .Delete {
      gists.removeAtIndex(indexPath.row)
      tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
    } else if editingStyle == .Insert {
      // Create a new instance of the appropriate class, insert it into the array,
      // and add a new row to the table view.
    }
  }

}

