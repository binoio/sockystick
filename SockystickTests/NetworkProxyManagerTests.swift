//
//  NetworkProxyManagerTests.swift
//  SockystickTests
//

import XCTest
@testable import Sockystick

final class NetworkProxyManagerTests: XCTestCase {
    var manager: NetworkProxyManager!

    override func setUp() {
        super.setUp()
        manager = NetworkProxyManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    func testParseNetworkServiceOrderOutput() {
        let sampleOutput = """
        An asterisk (*) denotes that a network service is disabled.
        (1) USB 10/100/1000 LAN
        (Hardware Port: USB 10/100/1000 LAN, Device: en5)

        (2) Thunderbolt Bridge
        (Hardware Port: Thunderbolt Bridge, Device: bridge0)

        (3) Wi-Fi
        (Hardware Port: Wi-Fi, Device: en0)
        """

        let interfaces = manager.parseNetworkServiceOrderOutput(sampleOutput, defaultDevice: "en0")

        XCTAssertEqual(interfaces.count, 3)
        
        let wifi = interfaces.first(where: { $0.device == "en0" })
        XCTAssertNotNil(wifi)
        XCTAssertEqual(wifi?.name, "Wi-Fi")
        XCTAssertTrue(wifi?.isPrimary ?? false)

        let lan = interfaces.first(where: { $0.device == "en5" })
        XCTAssertNotNil(lan)
        XCTAssertEqual(lan?.name, "USB 10/100/1000 LAN")
        XCTAssertFalse(lan?.isPrimary ?? true)

        XCTAssertEqual(interfaces.first?.device, "en0")
    }

    func testParseSOCKSProxyOutputEnabled() {
        let sampleOutput = """
        Enabled: Yes
        Server: 192.168.7.202
        Port: 1080
        Authenticated Proxy Enabled: 0
        """

        let config = manager.parseSOCKSProxyOutput(sampleOutput)

        XCTAssertTrue(config.isEnabled)
        XCTAssertEqual(config.host, "192.168.7.202")
        XCTAssertEqual(config.port, 1080)
        XCTAssertFalse(config.isAuthenticated)
    }

    func testParseSOCKSProxyOutputAuthenticated() {
        let sampleOutput = """
        Enabled: Yes
        Server: 192.168.7.202
        Port: 1080
        Authenticated Proxy Enabled: 1
        Authenticated Proxy Username: testuser
        """

        let config = manager.parseSOCKSProxyOutput(sampleOutput)

        XCTAssertTrue(config.isEnabled)
        XCTAssertEqual(config.host, "192.168.7.202")
        XCTAssertEqual(config.port, 1080)
        XCTAssertTrue(config.isAuthenticated)
        XCTAssertEqual(config.username, "testuser")
        XCTAssertEqual(config.serverString, "testuser@192.168.7.202:1080")
    }

    func testParseSOCKSProxyOutputDisabled() {
        let sampleOutput = """
        Enabled: No
        Server: 
        Port: 0
        Authenticated Proxy Enabled: 0
        """

        let config = manager.parseSOCKSProxyOutput(sampleOutput)

        XCTAssertFalse(config.isEnabled)
        XCTAssertEqual(config.host, "")
        XCTAssertEqual(config.port, 1080)
    }
}
