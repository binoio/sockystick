//
//  ProxyConfigTests.swift
//  SockystickTests
//

import XCTest
@testable import Sockystick

final class ProxyConfigTests: XCTestCase {
    func testProxyConfigDefaults() {
        let config = ProxyConfig()
        XCTAssertEqual(config.host, "127.0.0.1")
        XCTAssertEqual(config.port, 1080)
        XCTAssertFalse(config.isEnabled)
        XCTAssertEqual(config.serverString, "127.0.0.1:1080")
    }

    func testProxyConfigServerStringEmptyHost() {
        let config = ProxyConfig(host: "", port: 1080, isEnabled: false)
        XCTAssertEqual(config.serverString, "None")
    }

    func testProxyConfigCustomHostPort() {
        let config = ProxyConfig(host: "10.0.0.5", port: 8080, isEnabled: true)
        XCTAssertEqual(config.serverString, "10.0.0.5:8080")
        XCTAssertTrue(config.isEnabled)
    }
}
