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

    @IBAction func sliderValudChanged(_ sender: Any) {
        updateLabel()
    }

    func updateLabel() {
        let value = Int(slider.value)
        let values = Utilities.sequence(value)
        let sum = Utilities.sum(values: values)
        let average = Utilities.average(values: values)
        label.text = "Value: \(value), Average: \(average), Sum: \(sum)"
    }
}

