//
//  NetworkInterface.swift
//  Sockystick
//

import Foundation

public struct NetworkInterface: Identifiable, Hashable, Codable {
    public var id: String { name }
    public let name: String     // e.g. "Wi-Fi" or "USB 10/100/1000 LAN"
    public let device: String   // e.g. "en0" or "en5"
    public let isPrimary: Bool  // Whether this is the current default route interface

    public init(name: String, device: String, isPrimary: Bool = false) {
        self.name = name
        self.device = device
        self.isPrimary = isPrimary
    }

    public var displayName: String {
        if isPrimary {
            return "\(name) (\(device)) — Active Default"
        } else {
            return "\(name) (\(device))"
        }
    }
}
