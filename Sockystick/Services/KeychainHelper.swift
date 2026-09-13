//
//  KeychainHelper.swift
//  Sockystick
//
//  Secure credential management wrapper using macOS Security framework.
//

import Foundation
import Security

public class KeychainHelper {
    public static let shared = KeychainHelper()
    private let serviceName = "com.binoio.sockystick.proxy-credentials"

    public init() {}

    // MARK: - Generic Password Handling

    @discardableResult
    public func savePassword(_ password: String, forAccount account: String) -> Bool {
        guard let passwordData = password.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        var newItem = query
        newItem[kSecValueData as String] = passwordData

        let status = SecItemAdd(newItem as CFDictionary, nil)
        return status == errSecSuccess
    }

    public func readPassword(forAccount account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        guard status == errSecSuccess, let data = dataTypeRef as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    public func deletePassword(forAccount account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - macOS System Internet Password Handling (SOCKS Proxy)

    @discardableResult
    public func saveSOCKSCredentials(host: String, port: Int, username: String, password: String) -> Bool {
        guard !host.isEmpty, !username.isEmpty, let passwordData = password.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: host,
            kSecAttrPort as String: port,
            kSecAttrProtocol as String: kSecAttrProtocolSOCKS
        ]

        // Delete existing items for host & port to avoid duplicates
        SecItemDelete(query as CFDictionary)

        var newItem = query
        newItem[kSecAttrAccount as String] = username
        newItem[kSecValueData as String] = passwordData

        let status = SecItemAdd(newItem as CFDictionary, nil)
        return status == errSecSuccess
    }

    @discardableResult
    public func deleteSOCKSCredentials(host: String, port: Int) -> Bool {
        guard !host.isEmpty else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: host,
            kSecAttrPort as String: port,
            kSecAttrProtocol as String: kSecAttrProtocolSOCKS
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
