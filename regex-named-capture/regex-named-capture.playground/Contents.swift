//: Playground - noun: a place where people can play

import Foundation

extension String {
    var nsrange: NSRange {
        return NSRange(location: 0, length: self.utf16.count)
    }

    func substring(with nsrange: NSRange) -> Substring? {
        guard let range = Range(nsrange, in: self) else {
            return nil
        }
        return self[range]
    }
}


let str = "Contact me on (541) 754-3010"
let domesticUSTelephoneRegex = try! NSRegularExpression(pattern: "\\((?<areacode>\\d{3})\\) \\d{3}-\\d{4}",
                                                        options: [])

if let match = domesticUSTelephoneRegex.firstMatch(in: str, options: [], range: str.nsrange) {
    str.substring(with: match.range)
    str.substring(with: match.range(at: 1))
    str.substring(with: match.range(withName: "areacode"))
}
