//
//  ProxyConfig.swift
//  Sockystick
//

import Foundation

public struct ProxyConfig: Equatable, Codable {
    public var host: String
    public var port: Int
    public var isEnabled: Bool
    public var isAuthenticated: Bool
    public var username: String
    public var password: String

    public init(
        host: String = "192.168.7.202",
        port: Int = 1080,
        isEnabled: Bool = false,
        isAuthenticated: Bool = false,
        username: String = "",
        password: String = ""
    ) {
        self.host = host
        self.port = port
        self.isEnabled = isEnabled
        self.isAuthenticated = isAuthenticated
        self.username = username
        self.password = password
    }

    public var serverString: String {
        guard !host.isEmpty else { return "None" }
        if isAuthenticated && !username.isEmpty {
            return "\(username)@\(host):\(port)"
        }
        return "\(host):\(port)"
    }
}
