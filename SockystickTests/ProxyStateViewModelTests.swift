//
//  ProxyStateViewModelTests.swift
//  SockystickTests
//

import XCTest
@testable import Sockystick

final class MockNetworkProxyManager: NetworkProxyManagerProtocol {
    var defaultDeviceToReturn: String? = "en0"
    var interfacesToReturn: [NetworkInterface] = [
        NetworkInterface(name: "Wi-Fi", device: "en0", isPrimary: true),
        NetworkInterface(name: "USB 10/100/1000 LAN", device: "en5", isPrimary: false)
    ]
    var socksConfigToReturn = ProxyConfig(host: "127.0.0.1", port: 1080, isEnabled: false)

    var toggleCalledCount = 0
    var setProxyStateCalledCount = 0
    var lastAuthUsed = false
    var lastUsername = ""
    var lastPassword = ""

    func fetchDefaultDevice() -> String? {
        return defaultDeviceToReturn
    }

    func fetchAllInterfaces() -> [NetworkInterface] {
        return interfacesToReturn
    }

    func getSOCKSProxy(for interfaceName: String) -> ProxyConfig {
        return socksConfigToReturn
    }

    func setSOCKSProxy(for interfaceName: String, host: String, port: Int, useAuthentication: Bool, username: String, password: String) -> Bool {
        socksConfigToReturn.host = host
        socksConfigToReturn.port = port
        socksConfigToReturn.isAuthenticated = useAuthentication
        socksConfigToReturn.username = username
        socksConfigToReturn.password = password
        lastAuthUsed = useAuthentication
        lastUsername = username
        lastPassword = password
        return true
    }

    func setSOCKSProxyState(for interfaceName: String, enabled: Bool) -> Bool {
        setProxyStateCalledCount += 1
        socksConfigToReturn.isEnabled = enabled
        return true
    }

    func disableHTTPProxies(for interfaceName: String) {}

    func toggleSOCKSProxy(for interfaceName: String, host: String, port: Int, useAuthentication: Bool, username: String, password: String) -> ProxyConfig {
        toggleCalledCount += 1
        socksConfigToReturn.isEnabled.toggle()
        socksConfigToReturn.host = host
        socksConfigToReturn.port = port
        socksConfigToReturn.isAuthenticated = useAuthentication
        socksConfigToReturn.username = username
        socksConfigToReturn.password = password
        lastAuthUsed = useAuthentication
        lastUsername = username
        lastPassword = password
        return socksConfigToReturn
    }

    var disableAllCalledCount = 0
    var lastPriorityInterface: String? = nil
    var resetSafariCalledCount = 0

    func disableAllSOCKSProxies(priorityInterfaceName: String?) {
        disableAllCalledCount += 1
        lastPriorityInterface = priorityInterfaceName
        socksConfigToReturn.isEnabled = false
    }

    @discardableResult
    func resetSafariNetworking(synchronous: Bool) -> Int {
        resetSafariCalledCount += 1
        return 1
    }
}

@MainActor
final class ProxyStateViewModelTests: XCTestCase {
    var mockManager: MockNetworkProxyManager!
    var viewModel: ProxyStateViewModel!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "sockystick.proxyHost")
        UserDefaults.standard.removeObject(forKey: "sockystick.proxyPort")
        UserDefaults.standard.removeObject(forKey: "sockystick.useAuthentication")
        UserDefaults.standard.removeObject(forKey: "sockystick.proxyUsername")
        UserDefaults.standard.removeObject(forKey: "sockystick.proxyPassword")
        UserDefaults.standard.removeObject(forKey: "sockystick.autoStartProxyOnLaunch")
        UserDefaults.standard.removeObject(forKey: "sockystick.hideDockIcon")
        UserDefaults.standard.removeObject(forKey: "sockystick.resetSafariNetworkingOnToggle")
        KeychainHelper.shared.deletePassword(forAccount: "socks5_password_test")
        mockManager = MockNetworkProxyManager()
        viewModel = ProxyStateViewModel(proxyManager: mockManager, keychainAccount: "socks5_password_test")
        viewModel.useAuthentication = false
        viewModel.proxyUsername = ""
        viewModel.proxyPassword = ""
    }

    override func tearDown() {
        KeychainHelper.shared.deletePassword(forAccount: "socks5_password_test")
        viewModel = nil
        mockManager = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(viewModel.availableInterfaces.count, 2)
        XCTAssertEqual(viewModel.activeInterface?.name, "Wi-Fi")
        XCTAssertFalse(viewModel.isProxyEnabled)
        XCTAssertFalse(viewModel.hideDockIcon)
    }

    func testToggleProxyUnauthenticated() {
        XCTAssertFalse(viewModel.isProxyEnabled)

        viewModel.toggleProxy()

        XCTAssertTrue(viewModel.isProxyEnabled)
        XCTAssertEqual(mockManager.toggleCalledCount, 1)
        XCTAssertFalse(mockManager.lastAuthUsed)
        XCTAssertTrue(viewModel.statusMessage.contains("SOCKS5 Enabled"))
    }

    func testToggleProxyAuthenticated() {
        viewModel.useAuthentication = true
        viewModel.proxyUsername = "alice"
        viewModel.proxyPassword = "secretpassword"

        viewModel.toggleProxy()

        XCTAssertTrue(viewModel.isProxyEnabled)
        XCTAssertTrue(mockManager.lastAuthUsed)
        XCTAssertEqual(mockManager.lastUsername, "alice")
        XCTAssertEqual(mockManager.lastPassword, "secretpassword")
        XCTAssertTrue(viewModel.statusMessage.contains("Auth: alice"))
    }

    func testSelectInterface() {
        let lan = mockManager.interfacesToReturn[1]
        viewModel.selectInterface(lan)

        XCTAssertEqual(viewModel.activeInterface?.name, "USB 10/100/1000 LAN")
    }

    func testApplyPreset() {
        viewModel.applyPreset(host: "10.0.0.9", port: 9050)

        XCTAssertEqual(viewModel.proxyHost, "10.0.0.9")
        XCTAssertEqual(viewModel.proxyPortString, "9050")
        XCTAssertEqual(viewModel.parsedPort, 9050)
    }

    func testDisableProxyOnQuit() {
        // Enable proxy first
        viewModel.toggleProxy()
        XCTAssertTrue(viewModel.isProxyEnabled)

        // Trigger quit cleanup
        viewModel.disableProxyOnQuit()

        XCTAssertFalse(viewModel.isProxyEnabled)
        XCTAssertEqual(mockManager.disableAllCalledCount, 1)
        XCTAssertEqual(mockManager.lastPriorityInterface, "Wi-Fi")
        XCTAssertEqual(viewModel.statusMessage, "SOCKS5 Proxy Disabled")
    }

    func testMenuBarIconsExistAndAreTemplates() {
        let disconnectedIcon = MenuBarIcon.disconnected
        XCTAssertNotNil(disconnectedIcon)
        XCTAssertEqual(disconnectedIcon.size.width, 18.0)
        XCTAssertEqual(disconnectedIcon.size.height, 18.0)
        XCTAssertTrue(disconnectedIcon.isTemplate)

        let connectedIcon = MenuBarIcon.connected
        XCTAssertNotNil(connectedIcon)
        XCTAssertEqual(connectedIcon.size.width, 18.0)
        XCTAssertEqual(connectedIcon.size.height, 18.0)
        XCTAssertTrue(connectedIcon.isTemplate)
    }

    func testHideDockIconToggleAndPersistence() {
        XCTAssertFalse(viewModel.hideDockIcon)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "sockystick.hideDockIcon"))

        viewModel.hideDockIcon = true
        XCTAssertTrue(viewModel.hideDockIcon)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "sockystick.hideDockIcon"))

        viewModel.hideDockIcon = false
        XCTAssertFalse(viewModel.hideDockIcon)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "sockystick.hideDockIcon"))
    }

    func testApplyDockIconVisibility() {
        viewModel.hideDockIcon = true
        viewModel.applyDockIconVisibility()
        
        viewModel.hideDockIcon = false
        viewModel.applyDockIconVisibility()
    }

    func testResetSafariNetworkingOnToggleDefaultAndBehavior() {
        XCTAssertTrue(viewModel.resetSafariNetworkingOnToggle)
        XCTAssertEqual(mockManager.resetSafariCalledCount, 0)

        // Turning ON resets Safari Networking
        viewModel.toggleProxy()
        XCTAssertTrue(viewModel.isProxyEnabled)
        XCTAssertEqual(mockManager.resetSafariCalledCount, 1)

        // Turning OFF resets Safari Networking
        viewModel.toggleProxy()
        XCTAssertFalse(viewModel.isProxyEnabled)
        XCTAssertEqual(mockManager.resetSafariCalledCount, 2)

        // When disabled in settings, toggling does not reset Safari Networking
        viewModel.resetSafariNetworkingOnToggle = false
        viewModel.toggleProxy()
        XCTAssertTrue(viewModel.isProxyEnabled)
        XCTAssertEqual(mockManager.resetSafariCalledCount, 2)

        // Quit when enabled respects setting
        viewModel.disableProxyOnQuit()
        XCTAssertEqual(mockManager.resetSafariCalledCount, 2)

        // Re-enable setting and verify quit resets Safari Networking once when proxy was active
        viewModel.resetSafariNetworkingOnToggle = true
        viewModel.toggleProxy()
        XCTAssertEqual(mockManager.resetSafariCalledCount, 3)
        viewModel.disableProxyOnQuit()
        XCTAssertEqual(mockManager.resetSafariCalledCount, 4)
        // Second quit call while already disabled should not reset Safari again
        viewModel.disableProxyOnQuit()
        XCTAssertEqual(mockManager.resetSafariCalledCount, 4)
    }
}
