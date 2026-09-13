//
//  SOCKS5BridgeServerTests.swift
//  SockystickTests
//

import XCTest
@testable import Sockystick

final class SOCKS5BridgeServerTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
    }

    func testServerStartAndStop() {
        let bridge = SOCKS5BridgeServer()
        bridge.stop()
        XCTAssertFalse(bridge.isRunning)

        XCTAssertNoThrow(try bridge.start(
            port: 10899,
            upstreamHost: "127.0.0.1",
            upstreamPort: 1080,
            username: "testuser",
            password: "testpassword"
        ))

        let expectation = XCTestExpectation(description: "Server ready state")
        let startTime = Date()
        func checkRunning() {
            if bridge.isRunning {
                XCTAssertEqual(bridge.listeningPort, 10899)
                bridge.stop()
                XCTAssertFalse(bridge.isRunning)
                expectation.fulfill()
            } else if Date().timeIntervalSince(startTime) < 2.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    checkRunning()
                }
            } else {
                XCTFail("Server failed to reach running state within 2 seconds")
            }
        }
        checkRunning()

        wait(for: [expectation], timeout: 2.5)
    }
}
