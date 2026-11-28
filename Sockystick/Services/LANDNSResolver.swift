//
//  LANDNSResolver.swift
//  Sockystick
//
//  Resolves hostnames against the LAN's own DNS server (e.g. Pi-hole) before the
//  bridge forwards a CONNECT upstream. Without this, the remote SOCKS5 server
//  resolves names with its own resolver (often a container/public resolver) and
//  split-horizon names such as `dns.example.com` land on the WAN address instead
//  of the LAN vhost.
//

import Foundation
import Network
import SystemConfiguration

public struct LANDNSSettings: Equatable {
    public static let enabledKey = "sockystick.lanDNSEnabled"
    public static let serverKey = "sockystick.lanDNSServer"
    public static let domainsKey = "sockystick.lanDNSDomains"

    /// Master switch.
    public var isEnabled: Bool
    /// IPv4 DNS server. Empty means auto-detect the system's primary LAN DNS server.
    public var server: String
    /// Comma/space separated domain suffixes. Empty means every hostname.
    public var domains: String

    public init(isEnabled: Bool = true, server: String = "", domains: String = "") {
        self.isEnabled = isEnabled
        self.server = server
        self.domains = domains
    }

    public static func load(from defaults: UserDefaults = .standard) -> LANDNSSettings {
        let enabled = defaults.object(forKey: enabledKey) == nil ? true : defaults.bool(forKey: enabledKey)
        return LANDNSSettings(
            isEnabled: enabled,
            server: defaults.string(forKey: serverKey) ?? "",
            domains: defaults.string(forKey: domainsKey) ?? ""
        )
    }

    public var domainSuffixes: [String] {
        domains
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased() }
            .filter { !$0.isEmpty }
    }

    public func matches(host: String) -> Bool {
        let suffixes = domainSuffixes
        guard !suffixes.isEmpty else { return true }
        let h = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return suffixes.contains { h == $0 || h.hasSuffix("." + $0) }
    }

    /// The DNS server to query: the explicit setting, else the system's primary private IPv4 resolver.
    public func effectiveServer() -> String? {
        let explicit = server.trimmingCharacters(in: .whitespaces)
        if !explicit.isEmpty { return IPv4Address(explicit) != nil ? explicit : nil }
        return LANDNSResolver.systemLANDNSServer()
    }
}

public final class LANDNSResolver {
    private struct CacheEntry { let addresses: [IPv4Address]; let expires: Date }

    private let queue = DispatchQueue(label: "com.sockystick.landns")
    private var cache: [String: CacheEntry] = [:]
    public var timeout: TimeInterval = 1.5
    /// DNS server port; overridable for tests.
    var serverPort: NWEndpoint.Port = 53

    public init() {}

    // MARK: - System DNS discovery

    /// First RFC 1918 IPv4 address in the system DNS configuration (DHCP or manual).
    public static func systemLANDNSServer() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "Sockystick" as CFString, nil, nil),
              let dict = SCDynamicStoreCopyValue(store, "State:/Network/Global/DNS" as CFString) as? [String: Any],
              let servers = dict["ServerAddresses"] as? [String] else { return nil }
        return servers.first(where: isPrivateIPv4)
    }

    public static func isPrivateIPv4(_ s: String) -> Bool {
        guard let addr = IPv4Address(s) else { return false }
        let b = [UInt8](addr.rawValue)
        return b[0] == 10 || (b[0] == 172 && (16...31).contains(b[1])) || (b[0] == 192 && b[1] == 168)
    }

    // MARK: - Resolution

    /// Resolves `host` to IPv4 addresses via `server`. Completion is called once, on an internal queue,
    /// with an empty array on timeout, NXDOMAIN or any failure.
    public func resolveA(host: String, server: String, completion: @escaping ([IPv4Address]) -> Void) {
        let key = "\(server)|\(host.lowercased())"
        let cached: [IPv4Address]? = queue.sync {
            guard let entry = cache[key], entry.expires > Date() else { return nil }
            return entry.addresses
        }
        if let cached = cached {
            completion(cached)
            return
        }

        guard let serverAddr = IPv4Address(server) else {
            completion([])
            return
        }

        let txid = UInt16.random(in: 0...UInt16.max)
        guard let query = Self.buildQuery(host: host, id: txid) else {
            completion([])
            return
        }

        let params = NWParameters.udp
        params.preferNoProxies = true
        let conn = NWConnection(host: .ipv4(serverAddr), port: serverPort, using: params)

        var finished = false
        // Strong capture: the completion must fire even if the caller drops the resolver.
        let finish: ([IPv4Address], UInt32) -> Void = { addrs, ttl in
            self.queue.async {
                guard !finished else { return }
                finished = true
                conn.cancel()
                if !addrs.isEmpty {
                    let ttlSeconds = TimeInterval(min(max(ttl, 5), 300))
                    self.cache[key] = CacheEntry(addresses: addrs, expires: Date().addingTimeInterval(ttlSeconds))
                }
                completion(addrs)
            }
        }

        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                conn.send(content: query, completion: .contentProcessed { err in
                    if err != nil { finish([], 0) }
                })
                conn.receiveMessage { data, _, _, _ in
                    guard let data = data, let parsed = Self.parseResponse(data, expectedID: txid) else {
                        finish([], 0)
                        return
                    }
                    finish(parsed.addresses, parsed.ttl)
                }
            case .failed, .cancelled:
                finish([], 0)
            default:
                break
            }
        }
        conn.start(queue: queue)
        queue.asyncAfter(deadline: .now() + timeout) { finish([], 0) }
    }

    // MARK: - Wire format (RFC 1035)

    static func buildQuery(host: String, id: UInt16) -> Data? {
        var d = Data([UInt8(id >> 8), UInt8(id & 0xFF), 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        let labels = host.trimmingCharacters(in: CharacterSet(charactersIn: ".")).split(separator: ".", omittingEmptySubsequences: false)
        guard !labels.isEmpty else { return nil }
        for label in labels {
            let bytes = Array(label.utf8)
            guard !bytes.isEmpty, bytes.count <= 63 else { return nil }
            d.append(UInt8(bytes.count))
            d.append(contentsOf: bytes)
        }
        d.append(contentsOf: [0x00, 0x00, 0x01, 0x00, 0x01]) // root, QTYPE=A, QCLASS=IN
        return d
    }

    static func parseResponse(_ data: Data, expectedID: UInt16) -> (addresses: [IPv4Address], ttl: UInt32)? {
        let b = [UInt8](data)
        guard b.count >= 12 else { return nil }
        let id = UInt16(b[0]) << 8 | UInt16(b[1])
        guard id == expectedID, b[2] & 0x80 != 0, b[3] & 0x0F == 0 else { return nil } // QR set, RCODE NOERROR
        let qdcount = Int(UInt16(b[4]) << 8 | UInt16(b[5]))
        let ancount = Int(UInt16(b[6]) << 8 | UInt16(b[7]))

        var i = 12
        func skipName() -> Bool {
            while i < b.count {
                let len = b[i]
                if len & 0xC0 == 0xC0 { i += 2; return i <= b.count }
                i += 1
                if len == 0 { return true }
                i += Int(len)
            }
            return false
        }

        for _ in 0..<qdcount {
            guard skipName() else { return nil }
            i += 4
        }

        var addresses: [IPv4Address] = []
        var minTTL = UInt32.max
        for _ in 0..<ancount {
            guard skipName(), i + 10 <= b.count else { break }
            let type = UInt16(b[i]) << 8 | UInt16(b[i + 1])
            let cls = UInt16(b[i + 2]) << 8 | UInt16(b[i + 3])
            let ttl = UInt32(b[i + 4]) << 24 | UInt32(b[i + 5]) << 16 | UInt32(b[i + 6]) << 8 | UInt32(b[i + 7])
            let rdlen = Int(UInt16(b[i + 8]) << 8 | UInt16(b[i + 9]))
            i += 10
            guard i + rdlen <= b.count else { break }
            // Skip 0.0.0.0 (Pi-hole's blocked-domain answer) so the upstream proxy decides instead.
            if type == 1, cls == 1, rdlen == 4, b[i..<i + 4].contains(where: { $0 != 0 }),
               let addr = IPv4Address(Data(b[i..<i + 4])) {
                addresses.append(addr)
                minTTL = min(minTTL, ttl)
            }
            i += rdlen
        }
        return (addresses, addresses.isEmpty ? 0 : minTTL)
    }
}
