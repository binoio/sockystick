//
//  SOCKS5BridgeServerTests.swift
//  SockystickTests
//

import XCTest
import Network
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

    func testStopCancelsActiveClientConnections() {
        let bridge = SOCKS5BridgeServer()
        defer { bridge.stop() }

        XCTAssertNoThrow(try bridge.start(
            port: 10898,
            upstreamHost: "127.0.0.1",
            upstreamPort: 1080,
            username: "testuser",
            password: "testpassword"
        ))

        let readyExp = XCTestExpectation(description: "Bridge listener ready")
        let startTime = Date()
        func waitForReady() {
            if bridge.isRunning {
                readyExp.fulfill()
            } else if Date().timeIntervalSince(startTime) < 2.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { waitForReady() }
            }
        }
        waitForReady()
        wait(for: [readyExp], timeout: 2.5)

        let client = NWConnection(host: "127.0.0.1", port: 10898, using: .tcp)
        let connectedExp = XCTestExpectation(description: "Client connected and tracked")
        client.stateUpdateHandler = { state in
            if case .ready = state {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if bridge.activeConnectionCount >= 1 {
                        connectedExp.fulfill()
                    }
                }
            }
        }
        client.start(queue: DispatchQueue(label: "test.client"))
        wait(for: [connectedExp], timeout: 2.5)
        XCTAssertGreaterThanOrEqual(bridge.activeConnectionCount, 1)

        bridge.stop()
        XCTAssertFalse(bridge.isRunning)
        XCTAssertEqual(bridge.activeConnectionCount, 0)
        client.cancel()
    }
}
