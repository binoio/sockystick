//
//  ProxyStateViewModel.swift
//  Sockystick
//

import Foundation
import Combine
import SwiftUI
import ServiceManagement

@MainActor
public final class ProxyStateViewModel: ObservableObject {
    @Published public var activeInterface: NetworkInterface?
    @Published public var availableInterfaces: [NetworkInterface] = []
    
    @Published public var proxyHost: String
    @Published public var proxyPortString: String
    @Published public var useAuthentication: Bool
    @Published public var proxyUsername: String
    @Published public var proxyPassword: String

    @Published public var autoStartProxyOnLaunch: Bool {
        didSet {
            UserDefaults.standard.set(autoStartProxyOnLaunch, forKey: "sockystick.autoStartProxyOnLaunch")
            LogStore.log(level: .info, category: "Settings", message: "Auto-start proxy on launch changed to \(autoStartProxyOnLaunch)")
        }
    }

    @Published public var launchAtLogin: Bool = false {
        didSet {
            guard launchAtLogin != (SMAppService.mainApp.status == .enabled) else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                    LogStore.log(level: .success, category: "Settings", message: "Registered app for Launch at Login")
                } else {
                    try SMAppService.mainApp.unregister()
                    LogStore.log(level: .info, category: "Settings", message: "Unregistered app from Launch at Login")
                }
            } catch {
                let errStr = error.localizedDescription
                LogStore.log(level: .error, category: "Settings", message: "SMAppService operation failed", details: errStr)
                print("SMAppService toggle failed: \(errStr)")
            }
        }
    }

    @Published public var isProxyEnabled: Bool = false
    @Published public var statusMessage: String = "Ready"
    @Published public var isUpdating: Bool = false
    @Published public var lastRefreshTime: Date? = nil

    public var parsedPort: Int {
        Int(proxyPortString.trimmingCharacters(in: .whitespaces)) ?? 1080
    }

    private let proxyManager: NetworkProxyManagerProtocol
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?

    public init(proxyManager: NetworkProxyManagerProtocol = NetworkProxyManager.shared) {
        self.proxyManager = proxyManager
        
        let savedHost = UserDefaults.standard.string(forKey: "sockystick.proxyHost") ?? "192.168.7.202"
        let savedPort = UserDefaults.standard.string(forKey: "sockystick.proxyPort") ?? "1080"
        let savedUser = UserDefaults.standard.string(forKey: "sockystick.proxyUsername") ?? ""
        let savedPass = KeychainHelper.shared.readPassword(forAccount: "socks5_password") ?? ""
        
        let hasAuth = (!savedUser.isEmpty || !savedPass.isEmpty) || UserDefaults.standard.bool(forKey: "sockystick.useAuthentication")
        let savedAutoStart = UserDefaults.standard.bool(forKey: "sockystick.autoStartProxyOnLaunch")
        
        self.proxyHost = savedHost
        self.proxyPortString = savedPort
        self.useAuthentication = hasAuth
        self.proxyUsername = savedUser
        self.proxyPassword = savedPass
        self.autoStartProxyOnLaunch = savedAutoStart
        self.launchAtLogin = (SMAppService.mainApp.status == .enabled)

        setupPersistenceSubscribers()
        
        refreshStatus()

        // Ensure SOCKS5 proxy & local auth bridge are running if proxy is active or auto-start is set
        if isProxyEnabled || savedAutoStart {
            LogStore.log(level: .info, category: "AppLaunch", message: "Ensuring SOCKS5 proxy & auth bridge active on launch")
            setProxyState(true)
        }

        startPeriodicRefresh()
    }

    private func setupPersistenceSubscribers() {
        $proxyHost
            .dropFirst()
            .sink { [weak self] host in
                UserDefaults.standard.set(host, forKey: "sockystick.proxyHost")
                if let self = self, self.isProxyEnabled {
                    self.setProxyState(true)
                }
            }
            .store(in: &cancellables)

        $proxyPortString
            .dropFirst()
            .sink { [weak self] port in
                UserDefaults.standard.set(port, forKey: "sockystick.proxyPort")
                if let self = self, self.isProxyEnabled {
                    self.setProxyState(true)
                }
            }
            .store(in: &cancellables)

        $useAuthentication
            .dropFirst()
            .sink { [weak self] useAuth in
                UserDefaults.standard.set(useAuth, forKey: "sockystick.useAuthentication")
                if let self = self, self.isProxyEnabled {
                    self.setProxyState(true)
                }
            }
            .store(in: &cancellables)

        $proxyUsername
            .dropFirst()
            .sink { [weak self] username in
                UserDefaults.standard.set(username, forKey: "sockystick.proxyUsername")
                if !username.isEmpty, let self = self, !self.useAuthentication {
                    self.useAuthentication = true
                }
                if let self = self, self.isProxyEnabled {
                    self.setProxyState(true)
                }
            }
            .store(in: &cancellables)

        $proxyPassword
            .dropFirst()
            .sink { [weak self] password in
                KeychainHelper.shared.savePassword(password, forAccount: "socks5_password")
                if !password.isEmpty, let self = self, !self.useAuthentication {
                    self.useAuthentication = true
                }
                if let self = self, self.isProxyEnabled {
                    self.setProxyState(true)
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        timer?.invalidate()
    }

    public func startPeriodicRefresh() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshStatus(silent: true)
            }
        }
    }

    public func refreshStatus(silent: Bool = false) {
        if !silent { isUpdating = true }
        
        let interfaces = proxyManager.fetchAllInterfaces()
        self.availableInterfaces = interfaces

        if activeInterface == nil || !interfaces.contains(where: { $0.name == activeInterface?.name }) {
            let previousName = activeInterface?.name ?? "None"
            self.activeInterface = interfaces.first(where: { $0.isPrimary }) ?? interfaces.first
            if let newIface = activeInterface {
                LogStore.log(level: .info, category: "Network", message: "Active interface selected: \(newIface.name) (\(newIface.device))", details: "Previous selection: \(previousName)")
            }
        }

        if let currentIface = activeInterface {
            let currentProxy = proxyManager.getSOCKSProxy(for: currentIface.name)
            let prevEnabled = self.isProxyEnabled
            self.isProxyEnabled = currentProxy.isEnabled

            if currentProxy.isEnabled {
                let authStr = useAuthentication ? " (Auth: \(proxyUsername))" : ""
                statusMessage = "SOCKS5 Proxy ENABLED on \(currentIface.name)\(authStr)"
            } else {
                statusMessage = "SOCKS5 Proxy Disabled on \(currentIface.name)"
            }

            if !silent && prevEnabled != currentProxy.isEnabled {
                LogStore.log(
                    level: currentProxy.isEnabled ? .success : .info,
                    category: "Status",
                    message: "Proxy status refresh: SOCKS5 is \(currentProxy.isEnabled ? "ENABLED" : "DISABLED") on \(currentIface.name)"
                )
            }
        } else {
            statusMessage = "No active network interfaces found"
            isProxyEnabled = false
            if !silent {
                LogStore.log(level: .warning, category: "Network", message: "No active network interface detected")
            }
        }

        lastRefreshTime = Date()
        if !silent { isUpdating = false }
    }

    public func toggleProxy() {
        guard let currentIface = activeInterface else {
            statusMessage = "Error: No interface selected"
            LogStore.log(level: .error, category: "Toggle", message: "Cannot toggle proxy: No interface selected")
            return
        }

        let host = proxyHost.trimmingCharacters(in: .whitespaces)
        let port = parsedPort
        let username = proxyUsername.trimmingCharacters(in: .whitespaces)
        let password = proxyPassword

        guard !host.isEmpty else {
            statusMessage = "Error: Proxy IP/Host cannot be empty"
            LogStore.log(level: .error, category: "Validation", message: "Proxy host IP is empty")
            return
        }

        if useAuthentication && username.isEmpty {
            statusMessage = "Error: Username required for authentication"
            LogStore.log(level: .error, category: "Validation", message: "Authentication enabled but username is empty")
            return
        }

        isUpdating = true
        LogStore.log(
            level: .info,
            category: "Toggle",
            message: "User triggered proxy toggle for interface '\(currentIface.name)' target Host: \(host):\(port) (Auth: \(useAuthentication ? username : "No"))"
        )

        if (!username.isEmpty || !password.isEmpty) && !useAuthentication {
            useAuthentication = true
        }
        let effectiveAuth = useAuthentication

        let resultConfig = proxyManager.toggleSOCKSProxy(
            for: currentIface.name,
            host: host,
            port: port,
            useAuthentication: effectiveAuth,
            username: username,
            password: password
        )
        self.isProxyEnabled = resultConfig.isEnabled

        if resultConfig.isEnabled {
            let authLabel = effectiveAuth ? " (Auth: \(username))" : ""
            statusMessage = "SOCKS5 Enabled on \(currentIface.name) (\(host):\(port))\(authLabel)"
            LogStore.log(level: .success, category: "Toggle", message: statusMessage)
        } else {
            statusMessage = "SOCKS5 Disabled on \(currentIface.name)"
            LogStore.log(level: .info, category: "Toggle", message: statusMessage)
        }
        
        lastRefreshTime = Date()
        isUpdating = false
    }

    public func setProxyState(_ enable: Bool) {
        guard let currentIface = activeInterface else {
            LogStore.log(level: .error, category: "State", message: "Cannot set proxy state: No interface selected")
            return
        }
        let host = proxyHost.trimmingCharacters(in: .whitespaces)
        let port = parsedPort
        let username = proxyUsername.trimmingCharacters(in: .whitespaces)
        let password = proxyPassword

        if (!username.isEmpty || !password.isEmpty) && !useAuthentication {
            useAuthentication = true
        }
        let effectiveAuth = useAuthentication

        LogStore.log(level: .info, category: "State", message: "Explicit setProxyState(\(enable)) called for \(currentIface.name)")

        if enable {
            _ = proxyManager.setSOCKSProxy(
                for: currentIface.name,
                host: host,
                port: port,
                useAuthentication: effectiveAuth,
                username: username,
                password: password
            )
            _ = proxyManager.setSOCKSProxyState(for: currentIface.name, enabled: true)
        } else {
            _ = proxyManager.setSOCKSProxyState(for: currentIface.name, enabled: false)
        }
        refreshStatus()
    }

    public func selectInterface(_ interface: NetworkInterface) {
        let oldName = activeInterface?.name ?? "None"
        self.activeInterface = interface
        LogStore.log(level: .info, category: "Network", message: "Switched interface from '\(oldName)' to '\(interface.name)' (\(interface.device))")
        refreshStatus()
    }

    public func applyPreset(host: String, port: Int, username: String = "", password: String = "") {
        LogStore.log(level: .info, category: "Preset", message: "Applying preset: \(host):\(port) (User: \(username.isEmpty ? "None" : username))")
        self.proxyHost = host
        self.proxyPortString = String(port)
        if !username.isEmpty {
            self.useAuthentication = true
            self.proxyUsername = username
            self.proxyPassword = password
        }
        if isProxyEnabled, let currentIface = activeInterface {
            _ = proxyManager.setSOCKSProxy(
                for: currentIface.name,
                host: host,
                port: port,
                useAuthentication: useAuthentication,
                username: proxyUsername,
                password: proxyPassword
            )
            refreshStatus()
        }
    }
}
