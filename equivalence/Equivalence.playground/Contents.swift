//: Playground - noun: a place where people can play

import UIKit
import XCTest

infix operator ≡

/// A type that can be compared for value equivalence.
///
/// Types that conform to the `Equivalent` protocol can be compared for equivalence
/// using the equivalent-to operator (`≡`).
public protocol Equivalent {

    /// Returns a Boolean value indicating whether two values are equivalent.
    ///
    /// Equivalence is commutative. For any values `a` and `b`,
    /// `a ≡ b` must give the same result as `b ≡ a`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    static func ≡(lhs: Self, rhs: Self) -> Bool

}

extension URLComponents: Equivalent {

    /// Returns the default port number for a given URL scheme.
    ///
    /// - Parameters:
    ///   - scheme: A URL scheme.
    /// - Returns: The default port number or nil if not known.
    static func defaultPort(forScheme scheme: String) -> Int? {
        let port: Int?
        switch scheme {
        case "http":
            port = 80
        case "https":
            port = 443
        case "ftp":
            port = 21
        case "ssh":
            port = 22
        case "telnet":
            port = 23
        default:
            port = nil
        }
        return port
    }

    private var _port: Int? {
        if let port = port {
            return port
        }
        guard let scheme = scheme else {
            return nil
        }
        return URLComponents.defaultPort(forScheme: scheme)
    }

    public static func ≡(lhs: URLComponents, rhs: URLComponents) -> Bool {
        guard lhs.scheme == rhs.scheme,
            lhs.host == rhs.host,
            lhs._port == rhs._port,
            lhs.user == rhs.user,
            lhs.password == rhs.password,
            lhs.path == rhs.path else {
                return false
        }

        guard let lItems = lhs.queryItems,
            let rItems = rhs.queryItems else {
                return (lhs.queryItems == nil && rhs.queryItems == nil)
        }

        guard lItems.count == rItems.count else {
            return false
        }

        let lQueryItems = Set(lItems)
        let rQueryItems = Set(rItems)

        return lQueryItems == rQueryItems
    }
}

extension URL: Equivalent {

    public static func ≡(lhs: URL, rhs: URL) -> Bool {
        guard let lc = URLComponents(url: lhs, resolvingAgainstBaseURL: true) else {
            return URLComponents(url: rhs, resolvingAgainstBaseURL: true) == nil
        }
        guard let rc = URLComponents(url: rhs, resolvingAgainstBaseURL: true) else {
            return false
        }

        return lc ≡ rc
    }

}

public func XCTAssertEquivalent<T>(_ expression1: @autoclosure () throws -> T,
                                   _ expression2: @autoclosure () throws -> T,
                                   _ message: @autoclosure () -> String = "",
                                   file: StaticString = #file,
                                   line: UInt = #line) where T : Equivalent {
    do {
        let exp1 = try expression1()
        let exp2 = try expression2()
        let result = exp1 ≡ exp2
        guard result else {
            let formatted = "XCTAssertEquivalent failed: (\(exp1)) is not equivalent to (\(exp2)) - " + message()
            XCTFail(formatted,
                    file: file,
                    line: line)
            return
        }
    } catch {
        let formatted = "XCTAssertEquivalent failed: error thrown \(String(describing: error)) (\(error.localizedDescription)) - " + message()
        XCTFail(formatted, file: file, line: line)
    }
}

public func XCTAssertEquivalent<T>(_ expression1: T?,
                                   _ expression2: T?,
                                   _ message: @autoclosure () -> String = "",
                                   file: StaticString = #file,
                                   line: UInt = #line) where T : Equivalent {
    guard let exp1 = expression1, let exp2 = expression2 else {
        if expression1 == nil ? expression2 != nil : expression2 == nil {
            let formatted = "XCTAssertEquivalent failed: (\(String(describing: expression1))) is not equivalent to (\(String(describing: expression2))) - " + message()
            XCTFail(formatted,
                    file: file,
                    line: line)
        }
        return
    }

    XCTAssertEquivalent(exp1, exp2, message, file: file, line: line)
}

class EquivalentTests: XCTestCase {

    let baseURL = URL(string: "https://myservice.com/webservices/")

    func testIdenticalURLs() {
        let a = URL(string: "https://myservice.com/webservices/test")
        let b = URL(string: "https://myservice.com/webservices/test")
        XCTAssertEquivalent(a, b)
    }

    func testRelativeURLs() {
        let a = URL(string: "a/b", relativeTo: baseURL)
        let b = URL(string: "https://myservice.com/webservices/a/b")
        XCTAssertEquivalent(a, b)
    }

    func testReorderedQueryItems() {
        let a = URL(string: "test?a=1&b=2&c=3", relativeTo: baseURL)
        let b = URL(string: "test?c=3&b=2&a=1", relativeTo: baseURL)
        XCTAssertEquivalent(a, b)
    }

    func testPercentEncodingPath() {
        let a = URL(string: "test", relativeTo: baseURL)
        let b = URL(string: "%74%65%73%74", relativeTo: baseURL)
        XCTAssertEquivalent(a, b)
    }

    func testPercentEncodingQueryItems() {
        let a = URL(string: "test?a=1", relativeTo: baseURL)
        let b = URL(string: "test?a=%31", relativeTo: baseURL)
        XCTAssertEquivalent(a, b)
    }

    func testDefaultPort() {
        let a = URL(string: "https://myservice.com/webservices")
        let b = URL(string: "https://myservice.com:443/webservices")
        XCTAssertEquivalent(a, b)
    }

}

EquivalentTests.defaultTestSuite.run()
