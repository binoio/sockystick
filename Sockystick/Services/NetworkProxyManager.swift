//
//  NetworkProxyManager.swift
//  Sockystick
//

import Foundation
import AppKit

public protocol NetworkProxyManagerProtocol {
    func fetchDefaultDevice() -> String?
    func fetchAllInterfaces() -> [NetworkInterface]
    func getSOCKSProxy(for interfaceName: String) -> ProxyConfig
    func setSOCKSProxy(for interfaceName: String, host: String, port: Int, useAuthentication: Bool, username: String, password: String) -> Bool
    func setSOCKSProxyState(for interfaceName: String, enabled: Bool) -> Bool
    func disableHTTPProxies(for interfaceName: String)
    func toggleSOCKSProxy(for interfaceName: String, host: String, port: Int, useAuthentication: Bool, username: String, password: String) -> ProxyConfig
    func disableAllSOCKSProxies(priorityInterfaceName: String?)
    @discardableResult func resetSafariNetworking(synchronous: Bool) -> Int
}

public extension NetworkProxyManagerProtocol {
    func disableAllSOCKSProxies() {
        disableAllSOCKSProxies(priorityInterfaceName: nil)
    }

    @discardableResult
    func resetSafariNetworking() -> Int {
        return resetSafariNetworking(synchronous: false)
    }

    @discardableResult
    func resetSafariNetworking(synchronous: Bool) -> Int {
        return 0
    }
}

public class NetworkProxyManager: NetworkProxyManagerProtocol {
    public static let shared = NetworkProxyManager()

    public init() {}

    // MARK: - Process Execution

    @discardableResult
    open func runCommand(executablePath: String, arguments: [String]) -> (stdout: String, stderr: String, exitCode: Int32) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executablePath)
        task.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        let sanitizedArgs = sanitizeArguments(arguments)
        let execName = URL(fileURLWithPath: executablePath).lastPathComponent
        let cmdLine = "\(executablePath) \(sanitizedArgs.joined(separator: " "))"

        do {
            try task.run()
            task.waitUntilExit()
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            let exitCode = task.terminationStatus

            var details = "Command: \(cmdLine)\nExit Code: \(exitCode)"
            if !stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                details += "\n\nStandard Output:\n\(stdout)"
            }
            if !stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                details += "\n\nStandard Error:\n\(stderr)"
            }

            if exitCode != 0 {
                LogStore.log(
                    level: .error,
                    category: "CLI",
                    message: "Command failed (\(execName)): Exit code \(exitCode)",
                    details: details
                )
            } else if !stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                LogStore.log(
                    level: .warning,
                    category: "CLI",
                    message: "Command returned warning (\(execName))",
                    details: details
                )
            } else {
                LogStore.log(
                    level: .info,
                    category: "CLI",
                    message: "Exec: \(execName) \(sanitizedArgs.joined(separator: " "))",
                    details: details
                )
            }

            return (stdout, stderr, exitCode)
        } catch {
            let errorMsg = error.localizedDescription
            let details = "Command: \(cmdLine)\nError: \(errorMsg)"
            LogStore.log(
                level: .error,
                category: "CLI",
                message: "Failed to launch process \(executablePath)",
                details: details
            )
            return ("", errorMsg, -1)
        }
    }

    private func sanitizeArguments(_ arguments: [String]) -> [String] {
        var result: [String] = []
        var i = 0
        while i < arguments.count {
            let arg = arguments[i]
            result.append(arg)
            if arg == "on" && i + 2 < arguments.count {
                result.append(arguments[i + 1]) // username
                result.append("********")       // password masked
                i += 3
                continue
            }
            i += 1
        }
        return result
    }

    // MARK: - Default Device Detection

    public func fetchDefaultDevice() -> String? {
        let result = runCommand(executablePath: "/sbin/route", arguments: ["get", "default"])
        guard result.exitCode == 0 else { return nil }
        
        for line in result.stdout.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("interface:") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count >= 2 {
                    return parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return nil
    }

    // MARK: - Network Interfaces Listing

    public func fetchAllInterfaces() -> [NetworkInterface] {
        let result = runCommand(executablePath: "/usr/sbin/networksetup", arguments: ["-listnetworkserviceorder"])
        guard result.exitCode == 0 else { return [] }

        let defaultDevice = fetchDefaultDevice()
        return parseNetworkServiceOrderOutput(result.stdout, defaultDevice: defaultDevice)
    }

    public func parseNetworkServiceOrderOutput(_ output: String, defaultDevice: String?) -> [NetworkInterface] {
        var interfaces: [NetworkInterface] = []
        let lines = output.components(separatedBy: .newlines)

        var currentServiceName: String? = nil

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if let match = trimmed.range(of: #"^\*?\s*\(\d+\)\s+(.+)$"#, options: .regularExpression) {
                let headerContent = String(trimmed[match])
                if let colonIdx = headerContent.firstIndex(of: ")") {
                    let nameStart = headerContent.index(after: colonIdx)
                    let name = String(headerContent[nameStart...]).trimmingCharacters(in: .whitespaces)
                    currentServiceName = name
                }
            }
            else if trimmed.contains("Device:"), let serviceName = currentServiceName {
                if let devRange = trimmed.range(of: #"Device:\s*([a-zA-Z0-9_]+)"#, options: .regularExpression) {
                    let devSubstring = String(trimmed[devRange])
                    let parts = devSubstring.components(separatedBy: ":")
                    if parts.count >= 2 {
                        let devName = parts[1].trimmingCharacters(in: .whitespaces)
                        let isPrimary = (defaultDevice != nil && devName == defaultDevice)
                        let iface = NetworkInterface(name: serviceName, device: devName, isPrimary: isPrimary)
                        interfaces.append(iface)
                    }
                }
                currentServiceName = nil
            }
        }

        return interfaces.sorted { if1, if2 in
            if if1.isPrimary != if2.isPrimary {
                return if1.isPrimary && !if2.isPrimary
            }
            return if1.name < if2.name
        }
    }

    // MARK: - Proxy Status & Configuration

    public func getSOCKSProxy(for interfaceName: String) -> ProxyConfig {
        let result = runCommand(executablePath: "/usr/sbin/networksetup", arguments: ["-getsocksfirewallproxy", interfaceName])
        guard result.exitCode == 0 else {
            LogStore.log(level: .error, category: "Proxy", message: "Failed to get SOCKS proxy status for \(interfaceName)")
            return ProxyConfig()
        }
        return parseSOCKSProxyOutput(result.stdout)
    }

    public func parseSOCKSProxyOutput(_ output: String) -> ProxyConfig {
        var enabled = false
        var server = ""
        var port = 1080
        var authenticated = false
        var username = ""

        for line in output.components(separatedBy: .newlines) {
            let parts = line.components(separatedBy: ":")
            guard parts.count >= 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1...].joined(separator: ":").trimmingCharacters(in: .whitespaces)

            switch key {
            case "Enabled":
                enabled = (value.lowercased() == "yes" || value == "1")
            case "Server":
                server = value
            case "Port":
                if let p = Int(value), p > 0 {
                    port = p
                }
            case "Authenticated Proxy Enabled":
                authenticated = (value == "1" || value.lowercased() == "yes")
            case "Authenticated Proxy Username":
                username = value
            default:
                break
            }
        }

        return ProxyConfig(
            host: server,
            port: port,
            isEnabled: enabled,
            isAuthenticated: authenticated,
            username: username
        )
    }

    public func disableHTTPProxies(for interfaceName: String) {
        _ = runCommand(executablePath: "/usr/sbin/networksetup", arguments: ["-setwebproxystate", interfaceName, "off"])
        _ = runCommand(executablePath: "/usr/sbin/networksetup", arguments: ["-setsecurewebproxystate", interfaceName, "off"])
    }

    @discardableResult
    public func setSOCKSProxy(
        for interfaceName: String,
        host: String,
        port: Int,
        useAuthentication: Bool = false,
        username: String = "",
        password: String = ""
    ) -> Bool {
        LogStore.log(
            level: .info,
            category: "Proxy",
            message: "Configuring SOCKS5 host \(host):\(port) on interface '\(interfaceName)' (Auth: \(useAuthentication ? username : "No"))"
        )

        // Ensure HTTP/HTTPS web proxies are turned off to prevent SOCKS5/HTTP protocol mismatch
        disableHTTPProxies(for: interfaceName)

        var targetHost = host
        var targetPort = port

        // The local bridge is needed for authentication (Safari can't do RFC 1929) and for
        // LAN DNS resolution (so split-horizon names reach LAN vhosts, not WAN addresses).
        let lanDNS = LANDNSSettings.load()
        if useAuthentication || lanDNS.isEnabled {
            let bridgePort: UInt16 = 10800
            do {
                try SOCKS5BridgeServer.shared.start(
                    port: bridgePort,
                    upstreamHost: host,
                    upstreamPort: UInt16(port),
                    username: useAuthentication ? username : "",
                    password: useAuthentication ? password : "",
                    lanDNS: lanDNS
                )
                targetHost = "127.0.0.1"
                targetPort = Int(bridgePort)
                LogStore.log(
                    level: .info,
                    category: "Proxy",
                    message: "Routing system SOCKS5 proxy through local auth bridge on 127.0.0.1:\(bridgePort)"
                )
            } catch {
                LogStore.log(
                    level: .error,
                    category: "Bridge",
                    message: "Failed to start local SOCKS5 auth bridge",
                    details: error.localizedDescription
                )
            }
        } else {
            SOCKS5BridgeServer.shared.stop()
        }

        if useAuthentication {
            _ = KeychainHelper.shared.saveSOCKSCredentials(host: host, port: port, username: username, password: password)
        } else {
            _ = KeychainHelper.shared.deleteSOCKSCredentials(host: host, port: port)
        }

        // Configure SOCKS5 firewall proxy server in networksetup
        let args = ["-setsocksfirewallproxy", interfaceName, targetHost, String(targetPort)]
        let result = runCommand(executablePath: "/usr/sbin/networksetup", arguments: args)
        let success = (result.exitCode == 0)
        if success {
            LogStore.log(level: .success, category: "Proxy", message: "SOCKS5 proxy server set successfully for \(interfaceName)")
        } else {
            LogStore.log(level: .error, category: "Proxy", message: "Failed setting SOCKS5 proxy server for \(interfaceName)", details: result.stderr)
        }
        return success
    }

    @discardableResult
    public func setSOCKSProxyState(for interfaceName: String, enabled: Bool) -> Bool {
        let stateStr = enabled ? "on" : "off"
        LogStore.log(
            level: .info,
            category: "Proxy",
            message: "Turning SOCKS5 proxy \(stateStr.uppercased()) on interface '\(interfaceName)'"
        )
        
        // Always ensure HTTP/HTTPS web proxies are disabled when managing SOCKS5
        disableHTTPProxies(for: interfaceName)

        let result = runCommand(executablePath: "/usr/sbin/networksetup", arguments: ["-setsocksfirewallproxystate", interfaceName, stateStr])
        let success = (result.exitCode == 0)

        // Stop the local auth bridge AFTER disabling the system proxy so apps don't
        // hit a dead 127.0.0.1:10800 listener during the networksetup transition,
        // while still forcefully closing any lingering bridged connections.
        if !enabled {
            SOCKS5BridgeServer.shared.stop()
        }

        if success {
            LogStore.log(level: .success, category: "Proxy", message: "SOCKS5 proxy state on \(interfaceName) turned \(stateStr.uppercased())")
        } else {
            LogStore.log(level: .error, category: "Proxy", message: "Failed to turn SOCKS5 proxy state \(stateStr) for \(interfaceName)", details: result.stderr)
        }
        return success
    }

    public func toggleSOCKSProxy(
        for interfaceName: String,
        host: String,
        port: Int,
        useAuthentication: Bool = false,
        username: String = "",
        password: String = ""
    ) -> ProxyConfig {
        let current = getSOCKSProxy(for: interfaceName)
        let newEnabled = !current.isEnabled

        LogStore.log(
            level: .info,
            category: "Proxy",
            message: "Toggling SOCKS5 proxy state from \(current.isEnabled ? "ENABLED" : "DISABLED") to \(newEnabled ? "ENABLED" : "DISABLED") on '\(interfaceName)'"
        )

        if newEnabled {
            let setOk = setSOCKSProxy(
                for: interfaceName,
                host: host,
                port: port,
                useAuthentication: useAuthentication,
                username: username,
                password: password
            )
            let stateOk = setSOCKSProxyState(for: interfaceName, enabled: true)

            if !setOk || !stateOk {
                LogStore.log(
                    level: .error,
                    category: "Proxy",
                    message: "Failed to enable SOCKS5 proxy on interface '\(interfaceName)'",
                    details: "setSOCKSProxy success: \(setOk), setSOCKSProxyState success: \(stateOk)"
                )
            }
        } else {
            let stateOk = setSOCKSProxyState(for: interfaceName, enabled: false)
            if !stateOk {
                LogStore.log(
                    level: .error,
                    category: "Proxy",
                    message: "Failed to disable SOCKS5 proxy on interface '\(interfaceName)'"
                )
            }
        }

        return getSOCKSProxy(for: interfaceName)
    }

    public func disableAllSOCKSProxies(priorityInterfaceName: String? = nil) {
        LogStore.log(
            level: .info,
            category: "Proxy",
            message: "Disabling SOCKS5 proxy on all interfaces (Priority: \(priorityInterfaceName ?? "None"))"
        )
        if let priority = priorityInterfaceName, !priority.isEmpty {
            _ = setSOCKSProxyState(for: priority, enabled: false)
        }
        let interfaces = fetchAllInterfaces()
        for iface in interfaces {
            if iface.name == priorityInterfaceName { continue }
            let config = getSOCKSProxy(for: iface.name)
            if config.isEnabled {
                _ = setSOCKSProxyState(for: iface.name, enabled: false)
            }
        }
        SOCKS5BridgeServer.shared.stop()
    }

    // MARK: - Safari Networking Pool Reset

    public struct RunningProcessDescriptor: Equatable {
        public let pid: pid_t
        public let bundleIdentifier: String?
        public let localizedName: String?

        public init(pid: pid_t, bundleIdentifier: String?, localizedName: String?) {
            self.pid = pid
            self.bundleIdentifier = bundleIdentifier
            self.localizedName = localizedName
        }
    }

    public func findSafariNetworkingPIDs(in processes: [RunningProcessDescriptor]) -> [pid_t] {
        processes.compactMap { proc in
            guard proc.pid > 0,
                  proc.bundleIdentifier == "com.apple.WebKit.Networking",
                  let name = proc.localizedName,
                  name.localizedCaseInsensitiveContains("Safari") else {
                return nil
            }
            return proc.pid
        }
    }

    /// Gracefully restarts Safari's background `com.apple.WebKit.Networking` XPC process
    /// (keeping Safari windows, tabs, and WebContent processes intact) so Safari immediately
    /// drops stale pre-proxy iCloud Private Relay QUIC tunnels on connect and stale proxied
    /// connection pools on disconnect.
    @discardableResult
    public func resetSafariNetworking(synchronous: Bool = false) -> Int {
        let descriptors = NSWorkspace.shared.runningApplications.map {
            RunningProcessDescriptor(
                pid: $0.processIdentifier,
                bundleIdentifier: $0.bundleIdentifier,
                localizedName: $0.localizedName
            )
        }
        let pids = findSafariNetworkingPIDs(in: descriptors)
        guard !pids.isEmpty else {
            LogStore.log(
                level: .info,
                category: "Safari",
                message: "Safari Networking is not running; no connection pool reset needed"
            )
            return 0
        }

        var resetCount = 0
        var signaledPIDs: [pid_t] = []
        for pid in pids {
            if Darwin.kill(pid, SIGTERM) == 0 {
                resetCount += 1
                signaledPIDs.append(pid)
                LogStore.log(
                    level: .info,
                    category: "Safari",
                    message: "Signaled Safari Networking process (PID \(pid)) to flush pooled connections"
                )
            } else {
                let errCode = errno
                LogStore.log(
                    level: .warning,
                    category: "Safari",
                    message: "Failed to signal Safari Networking (PID \(pid)): errno \(errCode)"
                )
            }
        }

        // com.apple.WebKit.Networking is a libxpc transaction-managed service that traps
        // SIGTERM and waits after draining transactions rather than exiting on its own.
        // Give it a short grace period to drain transactions, then send SIGKILL if still
        // alive so Safari transparently respawns a clean Networking XPC process.
        if !signaledPIDs.isEmpty {
            let finishReset = {
                for pid in signaledPIDs where Darwin.kill(pid, 0) == 0 {
                    if Darwin.kill(pid, SIGKILL) == 0 {
                        LogStore.log(
                            level: .info,
                            category: "Safari",
                            message: "Completed Safari Networking reset (PID \(pid)) so Safari respawns with updated proxy routing"
                        )
                    }
                }
            }
            if synchronous {
                Thread.sleep(forTimeInterval: 0.15)
                finishReset()
            } else {
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.15, execute: finishReset)
            }
        }
        return resetCount
    }
}
