//
//  ViewController.swift
//  BisectDemo
//
//  Created by Raymond Mccrae on 18/03/2018.
//  Copyright © 2018 Raymond Mccrae. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        updateLabel()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func sliderValudChanged(_ sender: Any) {
        updateLabel()
    }

    func updateLabel() {
        let value = Int(slider.value)
        let average = Utilities.average(values: Array(0...value))
        label.text = "Avergae: \(average)"
    }
}

