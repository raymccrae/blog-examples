//
//  ViewController.swift
//  BisectDemo
//
//  Created by Raymond Mccrae on 18/03/2018.
//  Copyright © 2018 Raymond Mccrae. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        let average = Utilities.average(values: [])
        self.label.text = "\(average)"
    }


}

