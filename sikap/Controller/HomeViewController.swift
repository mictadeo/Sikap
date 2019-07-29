//
//  ViewController.swift
//  sikap
//
//  Created by Michael Tadeo on 5/25/19.
//  Copyright © 2019 Tadeo Man. All rights reserved.
//

import UIKit
import AWSAuthUI


class HomeViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Login with Amazon Web Service
        if !AWSSignInManager.sharedInstance().isLoggedIn {
            AWSAuthUIViewController
                .presentViewController(with: self.navigationController!,
                                       configuration: nil,
                                       completionHandler: { (provider: AWSSignInProvider, error: Error?) in
                                        if error != nil {
                                            print("Error occurred: \(String(describing: error))")
                                        } else {
                                            // Sign in successful.
                                        }
                })
        }
    }
}
