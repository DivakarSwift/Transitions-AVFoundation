//
//  ViewController.swift
//  Transitions
//
//  Created by German Pereyra on 9/14/16.
//  Copyright © 2016 German Pereyra. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class ViewController: UIViewController {
    var myOwnCode = false

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(animated: Bool) {
        if !myOwnCode {
            MovieTransitions().start { (url) in
                if let url = url {
                    let videoURL = url
                    let player = AVPlayer(URL: videoURL)
                    let playerViewController = AVPlayerViewController()
                    playerViewController.player = player
                    self.presentViewController(playerViewController, animated: true) {
                        playerViewController.player!.play()
                    }
                }
            }
        } else {
            VideoTransitions().start { (url) in
                if let url = url {
                    let videoURL = url
                    let player = AVPlayer(URL: videoURL)
                    let playerViewController = AVPlayerViewController()
                    playerViewController.player = player
                    self.presentViewController(playerViewController, animated: true) {
                        playerViewController.player!.play()
                    }
                }
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

