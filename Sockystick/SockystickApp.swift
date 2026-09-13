//
//  SockystickApp.swift
//  Sockystick
//
//  GUI Dock and Menubar App for SOCKS5 proxy switching on macOS.
//

import SwiftUI
import Sparkle

@MainActor
class SockystickAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
    lazy var updaterViewModel = UpdaterViewModel(updater: updaterController.updater)
    var proxyViewModel: ProxyStateViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil,
           NSClassFromString("XCTestCase") == nil {
            updaterController.startUpdater()
        }
        if let icon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = icon
        }

        let hideDock = UserDefaults.standard.bool(forKey: "sockystick.hideDockIcon")
        if hideDock {
            NSApp.setActivationPolicy(.accessory)
            DispatchQueue.main.async {
                for window in NSApp.windows where window.canBecomeMain {
                    window.orderOut(nil)
                }
            }
        } else {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async {
                if let firstWindow = NSApp.windows.first(where: { $0.canBecomeMain }) {
                    firstWindow.makeKeyAndOrderFront(nil)
                }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        LogStore.log(level: .info, category: "Lifecycle", message: "applicationShouldTerminate: Disabling SOCKS5 proxy on exit")
        proxyViewModel?.disableProxyOnQuit()
        NetworkProxyManager.shared.disableAllSOCKSProxies(priorityInterfaceName: proxyViewModel?.activeInterface?.name)
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        LogStore.log(level: .info, category: "Lifecycle", message: "applicationWillTerminate: Disabling SOCKS5 proxy on exit")
        proxyViewModel?.disableProxyOnQuit()
        NetworkProxyManager.shared.disableAllSOCKSProxies(priorityInterfaceName: proxyViewModel?.activeInterface?.name)
    }
}

@main
struct SockystickApp: App {
    @NSApplicationDelegateAdaptor(SockystickAppDelegate.self) var appDelegate
    @StateObject private var proxyViewModel = ProxyStateViewModel()
    @StateObject private var logStore = LogStore.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // MARK: - Main Dock Window
        WindowGroup("Sockystick", id: "main") {
            ContentView(viewModel: proxyViewModel)
                .onAppear {
                    appDelegate.proxyViewModel = proxyViewModel
                    proxyViewModel.applyDockIconVisibility()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit Sockystick") {
                    proxyViewModel.disableProxyOnQuit()
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }

            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(viewModel: appDelegate.updaterViewModel)
            }

            CommandMenu("Proxy") {
                Button(proxyViewModel.isProxyEnabled ? "Disable SOCKS5 Proxy" : "Enable SOCKS5 Proxy") {
                    proxyViewModel.toggleProxy()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Refresh Status") {
                    proxyViewModel.refreshStatus()
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandGroup(after: .windowArrangement) {
                Button("Logs") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "logs")
                }
                .keyboardShortcut("l", modifiers: [.command, .option])
            }
        }

        // MARK: - Menu Bar Item (Native macOS NSMenu style)
        MenuBarExtra {
            MenuBarView(
                viewModel: proxyViewModel,
                updaterViewModel: appDelegate.updaterViewModel,
                openMainWindowAction: {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                    DispatchQueue.main.async {
                        if let firstWindow = NSApp.windows.first(where: { $0.canBecomeMain }) {
                            firstWindow.makeKeyAndOrderFront(nil)
                        }
                    }
                },
                openLogsWindowAction: {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "logs")
                }
            )
        } label: {
            Image(nsImage: proxyViewModel.isProxyEnabled ? MenuBarIcon.connected : MenuBarIcon.disconnected)
                .renderingMode(.template)
                .help(proxyViewModel.isProxyEnabled ? "Sockystick: SOCKS5 Active" : "Sockystick: SOCKS5 Disconnected")
        }
        .menuBarExtraStyle(.menu)

        // MARK: - Diagnostic Logs Window
        Window("Diagnostic Logs", id: "logs") {
            LogsView(logStore: logStore)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

        // MARK: - Settings Window
        Settings {
            SettingsView(proxyViewModel: proxyViewModel, updaterViewModel: appDelegate.updaterViewModel)
        }
    }
}
