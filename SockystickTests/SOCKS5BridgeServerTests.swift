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

    func testUnreachableUpstreamFailsFastInsteadOfHanging() throws {
        let bridge = SOCKS5BridgeServer()
        defer { bridge.stop() }
        // Port 9 on loopback has no listener, so the upstream connection is refused.
        try bridge.start(port: 10897, upstreamHost: "127.0.0.1", upstreamPort: 9, username: "", password: "")

        let replied = XCTestExpectation(description: "Client receives SOCKS5 failure reply")
        let clientQueue = DispatchQueue(label: "test.refused.client")
        func attempt(_ remaining: Int) {
            let client = NWConnection(host: "127.0.0.1", port: 10897, using: .tcp)
            client.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    var req = Data([0x05, 0x01, 0x00, 0x05, 0x01, 0x00, 0x03, 11])
                    req.append(contentsOf: Array("example.com".utf8))
                    req.append(contentsOf: [0x01, 0xBB])
                    client.send(content: req, completion: .contentProcessed { _ in })
                    client.receive(minimumIncompleteLength: 12, maximumLength: 64) { data, _, _, _ in
                        if let data = data, data.count >= 12 {
                            XCTAssertEqual(Array(data.prefix(2)), [0x05, 0x00])   // greeting reply
                            XCTAssertEqual(data[3], 0x05)                       // connection refused
                            replied.fulfill()
                        }
                        client.cancel()
                    }
                case .waiting, .failed:
                    client.cancel()
                    if remaining > 0 { clientQueue.asyncAfter(deadline: .now() + 0.1) { attempt(remaining - 1) } }
                default: break
                }
            }
            client.start(queue: clientQueue)
        }
        attempt(20)
        wait(for: [replied], timeout: 5)
    }
}
