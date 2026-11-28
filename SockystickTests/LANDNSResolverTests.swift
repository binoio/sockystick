//
//  LANDNSResolverTests.swift
//  SockystickTests
//

import XCTest
import Network
@testable import Sockystick

final class LANDNSResolverTests: XCTestCase {

    /// Builds a response to `query` with a CNAME then the given A records (name-compressed).
    private func makeResponse(to query: Data, aRecords: [[UInt8]], rcode: UInt8 = 0) -> Data {
        var r = Data(query)
        r[2] = 0x81; r[3] = 0x80 | rcode
        r[7] = UInt8(1 + aRecords.count) // ANCOUNT
        // CNAME answer pointing at the question name (offset 12)
        r.append(contentsOf: [0xC0, 0x0C, 0x00, 0x05, 0x00, 0x01, 0, 0, 0x0E, 0x10, 0x00, 0x02, 0xC0, 0x0C])
        for a in aRecords {
            r.append(contentsOf: [0xC0, 0x0C, 0x00, 0x01, 0x00, 0x01, 0, 0, 0x00, 0x3C, 0x00, 0x04])
            r.append(contentsOf: a)
        }
        return r
    }

    func testBuildQueryEncodesLabels() throws {
        let q = try XCTUnwrap(LANDNSResolver.buildQuery(host: "dns.example.com.", id: 0xABCD))
        XCTAssertEqual(Array(q.prefix(2)), [0xAB, 0xCD])
        XCTAssertEqual(Array(q.suffix(from: 12)), [3] + Array("dns".utf8) + [7] + Array("example".utf8) + [3] + Array("com".utf8) + [0, 0, 1, 0, 1])
        XCTAssertNil(LANDNSResolver.buildQuery(host: "a..b", id: 1))
    }

    func testParseResponseSkipsCNAMEAndBlockedAnswers() throws {
        let q = try XCTUnwrap(LANDNSResolver.buildQuery(host: "dns.example.com", id: 7))
        let resp = makeResponse(to: q, aRecords: [[0, 0, 0, 0], [192, 168, 7, 205]])
        let parsed = try XCTUnwrap(LANDNSResolver.parseResponse(resp, expectedID: 7))
        XCTAssertEqual(parsed.addresses, [IPv4Address("192.168.7.205")!])
        XCTAssertEqual(parsed.ttl, 60)
        XCTAssertNil(LANDNSResolver.parseResponse(resp, expectedID: 8))
        XCTAssertNil(LANDNSResolver.parseResponse(makeResponse(to: q, aRecords: [], rcode: 3), expectedID: 7))
    }

    func testDomainMatching() {
        XCTAssertTrue(LANDNSSettings(domains: "").matches(host: "anything.org"))
        let s = LANDNSSettings(domains: "example.com, .home.arpa")
        XCTAssertTrue(s.matches(host: "dns.example.com"))
        XCTAssertTrue(s.matches(host: "EXAMPLE.com."))
        XCTAssertTrue(s.matches(host: "nas.home.arpa"))
        XCTAssertFalse(s.matches(host: "notexample.com"))
        XCTAssertFalse(s.matches(host: "apple.com"))
    }

    func testPrivateIPv4Detection() {
        XCTAssertTrue(LANDNSResolver.isPrivateIPv4("192.168.7.202"))
        XCTAssertTrue(LANDNSResolver.isPrivateIPv4("10.0.0.1"))
        XCTAssertTrue(LANDNSResolver.isPrivateIPv4("172.20.1.1"))
        XCTAssertFalse(LANDNSResolver.isPrivateIPv4("45.90.28.189"))
        XCTAssertFalse(LANDNSResolver.isPrivateIPv4("fd80::1"))
    }

    func testBridgeRequestParseAndRewrite() throws {
        var req = Data([0x05, 0x01, 0x00, 0x03, UInt8("dns.example.com".utf8.count)])
        req.append(contentsOf: Array("dns.example.com".utf8))
        req.append(contentsOf: [0x01, 0xBB])
        let parsed = try XCTUnwrap(SOCKS5BridgeServer.parseDomainRequest(req))
        XCTAssertEqual(parsed.host, "dns.example.com")
        XCTAssertEqual(parsed.port, 443)

        let rewritten = SOCKS5BridgeServer.ipv4Request(command: 0x01, address: IPv4Address("192.168.7.205")!, port: 443)
        XCTAssertEqual(Array(rewritten), [0x05, 0x01, 0x00, 0x01, 192, 168, 7, 205, 0x01, 0xBB])

        var literal = Data([0x05, 0x01, 0x00, 0x03, 8])
        literal.append(contentsOf: Array("10.0.0.1".utf8))
        literal.append(contentsOf: [0x00, 0x50])
        XCTAssertNil(SOCKS5BridgeServer.parseDomainRequest(literal))
    }

    func testResolveAgainstLocalUDPServerAndTimeout() throws {
        let listener = try NWListener(using: .udp, on: .any)
        let serverQueue = DispatchQueue(label: "test.fakedns")
        listener.newConnectionHandler = { conn in
            conn.start(queue: serverQueue)
            conn.receiveMessage { data, _, _, _ in
                guard let data = data else { return }
                conn.send(content: self.makeResponse(to: data, aRecords: [[192, 168, 7, 205]]), completion: .idempotent)
            }
        }
        let ready = expectation(description: "listener ready")
        listener.stateUpdateHandler = { if case .ready = $0 { ready.fulfill() } }
        listener.start(queue: serverQueue)
        wait(for: [ready], timeout: 2)
        defer { listener.cancel() }

        let port = try XCTUnwrap(listener.port)
        let resolved = expectation(description: "resolved")
        resolveVia(port: port) { addrs in
            XCTAssertEqual(addrs, [IPv4Address("192.168.7.205")!])
            resolved.fulfill()
        }
        wait(for: [resolved], timeout: 3)

        // Unreachable server: completes empty within the timeout instead of hanging.
        let resolver = LANDNSResolver()
        resolver.timeout = 0.3
        let timedOut = expectation(description: "timed out")
        resolver.resolveA(host: "dns.example.com", server: "192.0.2.1") { addrs in
            XCTAssertTrue(addrs.isEmpty)
            timedOut.fulfill()
        }
        wait(for: [timedOut], timeout: 2)
    }

    private func resolveVia(port: NWEndpoint.Port, completion: @escaping ([IPv4Address]) -> Void) {
        let resolver = LANDNSResolver()
        resolver.serverPort = port
        resolver.resolveA(host: "dns.example.com", server: "127.0.0.1", completion: completion)
    }
}
