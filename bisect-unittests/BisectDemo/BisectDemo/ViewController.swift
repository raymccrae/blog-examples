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
        updateLabel()
    }

    @IBAction func sliderValudChanged(_ sender: Any) {
        updateLabel()
    }

    func updateLabel() {
        let value = Int(slider.value)
        let sum = Utilities.sum(values: Array(0...value))
        let average = Utilities.average(values: Array(0...value))
        label.text = "Value: \(value), Avergae: \(average), Sum: \(sum)"
    }
}

