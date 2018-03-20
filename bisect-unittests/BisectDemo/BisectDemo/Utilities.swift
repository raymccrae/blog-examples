//
//  File.swift
//  BisectDemo
//
//  Created by Raymond Mccrae on 20/03/2018.
//  Copyright © 2018 Raymond Mccrae. All rights reserved.
//

import Foundation

class Utilities {

    static func average(values: [Int]) -> Int {
        var sum = 0
        for value in values {
            sum += value
        }

        if values.count > 0 {
            return sum / values.count
        } else {
            return 0
        }
    }

}
