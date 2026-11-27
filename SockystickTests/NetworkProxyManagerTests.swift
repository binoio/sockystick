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
        Server: 192.0.2.10
        Port: 1080
        Authenticated Proxy Enabled: 0
        """

        let config = manager.parseSOCKSProxyOutput(sampleOutput)

        XCTAssertTrue(config.isEnabled)
        XCTAssertEqual(config.host, "192.0.2.10")
        XCTAssertEqual(config.port, 1080)
        XCTAssertFalse(config.isAuthenticated)
    }

    func testParseSOCKSProxyOutputAuthenticated() {
        let sampleOutput = """
        Enabled: Yes
        Server: 192.0.2.10
        Port: 1080
        Authenticated Proxy Enabled: 1
        Authenticated Proxy Username: testuser
        """

        let config = manager.parseSOCKSProxyOutput(sampleOutput)

        XCTAssertTrue(config.isEnabled)
        XCTAssertEqual(config.host, "192.0.2.10")
        XCTAssertEqual(config.port, 1080)
        XCTAssertTrue(config.isAuthenticated)
        XCTAssertEqual(config.username, "testuser")
        XCTAssertEqual(config.serverString, "testuser@192.0.2.10:1080")
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

    func testFindSafariNetworkingPIDsFiltersStrictlyToSafari() {
        let processes = [
            NetworkProxyManager.RunningProcessDescriptor(pid: 100, bundleIdentifier: "com.apple.Safari", localizedName: "Safari"),
            NetworkProxyManager.RunningProcessDescriptor(pid: 200, bundleIdentifier: "com.apple.WebKit.Networking", localizedName: "Safari Networking"),
            NetworkProxyManager.RunningProcessDescriptor(pid: 201, bundleIdentifier: "com.apple.WebKit.Networking", localizedName: "Safari Technology Preview Networking"),
            NetworkProxyManager.RunningProcessDescriptor(pid: 300, bundleIdentifier: "com.apple.WebKit.Networking", localizedName: "Mail Networking"),
            NetworkProxyManager.RunningProcessDescriptor(pid: 301, bundleIdentifier: "com.apple.WebKit.WebContent", localizedName: "Safari Web Content"),
            NetworkProxyManager.RunningProcessDescriptor(pid: 0, bundleIdentifier: "com.apple.WebKit.Networking", localizedName: "Safari Networking")
        ]

        let pids = manager.findSafariNetworkingPIDs(in: processes)
        XCTAssertEqual(pids, [200, 201])
    }
}
