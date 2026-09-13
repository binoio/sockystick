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
    var socksConfigToReturn = ProxyConfig(host: "192.168.7.202", port: 1080, isEnabled: false)

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

    func disableAllSOCKSProxies(priorityInterfaceName: String?) {
        disableAllCalledCount += 1
        lastPriorityInterface = priorityInterfaceName
        socksConfigToReturn.isEnabled = false
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
        KeychainHelper.shared.deletePassword(forAccount: "socks5_password")
        mockManager = MockNetworkProxyManager()
        viewModel = ProxyStateViewModel(proxyManager: mockManager)
        viewModel.useAuthentication = false
        viewModel.proxyUsername = ""
        viewModel.proxyPassword = ""
    }

    override func tearDown() {
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
}
