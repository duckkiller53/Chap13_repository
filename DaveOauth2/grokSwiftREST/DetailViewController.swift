//
//  DetailViewController.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2015-10-20.
//  Copyright © 2015 Teak Mobile Inc. All rights reserved.
//

import UIKit
import SafariServices

class DetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    var isStarred: Bool?
    var alertController: UIAlertController?
    @IBOutlet weak var tableView: UITableView!
    
    var gist: Gist? {
        didSet {
            // Update the view.
            self.configureView()
        }
    }
    
    func configureView() {
        // Update the user interface for the detail item.
        if let _: Gist = self.gist {
            fetchStarredStatus()
            if let detailsView = self.tableView {
                detailsView.reloadData()
            }
        }
    }// MARK: - Stars
    
    func fetchStarredStatus() {
        if let gistId = gist?.id {
            GitHubAPIManager.sharedInstance.isGistStarred(gistId, completionHandler: {
                result in
                if let error = result.error
                {
                    print(error)
                    if error.domain == NSURLErrorDomain &&
                        error.code == NSURLErrorUserAuthenticationRequired
                    {
                        self.alertController = UIAlertController(title:
                            "Could not get starred status", message: error.description,
                            preferredStyle: .Alert)
                        // add ok button
                        let okAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
                        self.alertController?.addAction(okAction)
                        self.presentViewController(self.alertController!, animated:true,
                            completion: nil)
                    }
                }
                
                if let status = result.value where self.isStarred == nil
                {
                    // just got it
                    self.isStarred = status
                    self.tableView?.insertRowsAtIndexPaths(
                        [NSIndexPath(forRow: 2, inSection: 0)],
                        withRowAnimation: .Automatic)
                }
            })
        }
    }
    
    // When our call to starGist completes, check for an error if not add 
    // a third row to 1st section.
    func starThisGist() {
        if let gistId = gist?.id {
            GitHubAPIManager.sharedInstance.starGist(gistId, completionHandler: {
                (error) in
                if let error = error {
                    print(error)
                    if error.domain == NSURLErrorDomain &&
                        error.code == NSURLErrorUserAuthenticationRequired {
                            self.alertController = UIAlertController(title: "Could not star gist",
                                message: error.description, preferredStyle: .Alert)
                    } else {
                        self.alertController = UIAlertController(title: "Could not star gist",
                            message: "Sorry, your gist couldn't be starred. " +
                            "Maybe GitHub is down or you don't have an internet connection.",
                            preferredStyle: .Alert)
                    }
                    // add ok button
                    let okAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
                    self.alertController?.addAction(okAction)
                    self.presentViewController(self.alertController!, animated:true, completion: nil)
                }
                else
                {
                    // no error add 3rd row to section 1 to display the text "starrred".
                    self.isStarred = true
                    self.tableView.reloadRowsAtIndexPaths(
                        [NSIndexPath(forRow: 2, inSection: 0)],
                        withRowAnimation: .Automatic)
                }
            })
        }
    }
    
    func unstarThisGist() {
        if let gistId = gist?.id {
            GitHubAPIManager.sharedInstance.unstarGist(gistId, completionHandler: {
                (error) in
                if let error = error {
                    print(error)
                    if error.domain == NSURLErrorDomain &&
                        error.code == NSURLErrorUserAuthenticationRequired {
                            self.alertController = UIAlertController(title: "Could not unstar gist",
                                message: error.description, preferredStyle: .Alert)
                    } else {
                        self.alertController = UIAlertController(title: "Could not unstar gist",
                            message: "Sorry, your gist couldn't be unstarred. " +
                            " Maybe GitHub is down or you don't have an internet connection.",
                            preferredStyle: .Alert)
                    }
                    // add ok button
                    let okAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
                    self.alertController?.addAction(okAction)
                    self.presentViewController(self.alertController!, animated:true, completion: nil)
                } else {
                    self.isStarred = false
                    self.tableView.reloadRowsAtIndexPaths(
                        [NSIndexPath(forRow: 2, inSection: 0)],
                        withRowAnimation: .Automatic)
                }
            })
        }
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.configureView()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view data source and delegate
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    /*
        If section == 0 and the isStarred was set to true or false (we know we had a response)
        return 3 rows.  else if isStarred = nil (there was an error) set rows to 2.  Else if
        section = 1, return file count.
    */
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            if let _ = isStarred
            {
                return 3
            }
            return 2
        } else {
            return gist?.files?.count ?? 0
        }
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "About"
        } else {
            return "Files"
        }
    }
    
    
    // Set the data for the cell.
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
        
        if indexPath.section == 0
        {
            if indexPath.row == 0
            {
                cell.textLabel?.text = gist?.description
            } else if indexPath.row == 1 {
                cell.textLabel?.text = gist?.ownerLogin
            } else {
                // Were in section 0 row 2 test if gist is starred or not.
                if let starred = isStarred {
                    if starred {
                        cell.textLabel?.text = "Unstar"
                    } else {
                        cell.textLabel?.text = "Star"                    }
                }
            }
        } else // were in section 1.  display file link
        {
            if let file = gist?.files?[indexPath.row] {
                cell.textLabel?.text = file.filename
            }
        }
        
        return cell

    }
    
    /* This is very cool.  If the user selected the second section, we get the
     index path of the row and use that to get the filename from or gist object's
     collection of file names. Then we convert the string to a NSURL and dynamiclly
     add a SafariViewController to our navigationController.  Because we add it to
     the nav controller, we don't have to worry about a back button.  It now will
     be handled by the nav controller.
    */
    
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == 0 {
            if indexPath.row == 2 { // star or unstar
                if let starred = isStarred {
                    if starred {
                        // unstar
                        unstarThisGist()
                    } else {
                        // star
                        starThisGist()
                    }
                }
            }
        } else if indexPath.section == 1 {
            if let file = gist?.files?[indexPath.row],
                urlString = file.raw_url,
                url = NSURL(string: urlString) {
                    let safariViewController = SFSafariViewController(URL: url)
                    safariViewController.title = file.filename
                    self.navigationController?.pushViewController(safariViewController, animated: true)
            }
        }
    }

}

