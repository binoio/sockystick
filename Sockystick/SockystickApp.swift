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

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil,
           NSClassFromString("XCTestCase") == nil {
            updaterController.startUpdater()
        }
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            if let firstWindow = NSApp.windows.first(where: { $0.canBecomeMain }) {
                firstWindow.makeKeyAndOrderFront(nil)
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
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
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
                },
                openLogsWindowAction: {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "logs")
                }
            )
        } label: {
            HStack(spacing: 4) {
                Image(systemName: proxyViewModel.isProxyEnabled ? "network.badge.shield.half.filled" : "network")
                if proxyViewModel.isProxyEnabled {
                    Text("SOCKS")
                        .font(.caption2.bold())
                }
            }
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
