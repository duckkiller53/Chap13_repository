//
//  LoginViewController.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2015-11-30.
//  Copyright © 2015 Teak Mobile Inc. All rights reserved.
//

import UIKit

// this is a delegate function that can be used
// to call a function outside this class to do
// something on behafe of this class.
protocol LoginViewDelegate: class {
  func didTapLoginButton()
}

class LoginViewController: UIViewController {
  weak var delegate: LoginViewDelegate?
  
  @IBAction func tappedLoginButton() {    
    if let delegate = self.delegate {
    delegate.didTapLoginButton()
    }
  }
}