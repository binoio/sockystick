//
//  MenuBarView.swift
//  Sockystick
//
//  Standard macOS Menu Bar Extra dropdown menu content conforming to macOS HIG conventions.
//

import SwiftUI

public struct MenuBarView: View {
    @ObservedObject public var viewModel: ProxyStateViewModel
    @ObservedObject public var updaterViewModel: UpdaterViewModel
    public var openMainWindowAction: () -> Void
    public var openLogsWindowAction: (() -> Void)?

    public init(
        viewModel: ProxyStateViewModel,
        updaterViewModel: UpdaterViewModel,
        openMainWindowAction: @escaping () -> Void,
        openLogsWindowAction: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.updaterViewModel = updaterViewModel
        self.openMainWindowAction = openMainWindowAction
        self.openLogsWindowAction = openLogsWindowAction
    }

    public var body: some View {
        // MARK: - Status & Active Config Header
        Button("SOCKS5 Proxy: \(viewModel.isProxyEnabled ? "Active" : "Disabled")") {}
            .disabled(true)

        if let iface = viewModel.activeInterface {
            let authStr = (viewModel.useAuthentication && !viewModel.proxyUsername.isEmpty) ? "\(viewModel.proxyUsername)@" : ""
            Button("Server: \(authStr)\(viewModel.proxyHost):\(viewModel.proxyPortString) (\(iface.name))") {}
                .disabled(true)
        }

        Divider()

        // MARK: - Proxy Toggle Action
        Button(viewModel.isProxyEnabled ? "Turn Off SOCKS5 Proxy" : "Turn On SOCKS5 Proxy") {
            viewModel.toggleProxy()
        }

        // MARK: - Interface Selector Submenu
        Menu("Target Interface") {
            ForEach(viewModel.availableInterfaces) { iface in
                Button(action: {
                    viewModel.selectInterface(iface)
                }) {
                    if iface.id == viewModel.activeInterface?.id {
                        Text("✓ \(iface.displayName)")
                    } else {
                        Text(iface.displayName)
                    }
                }
            }
        }

        Divider()

        // MARK: - Window & Preferences Actions
        Button("Open Sockystick…") {
            openMainWindowAction()
        }

        if let openLogs = openLogsWindowAction {
            Button("Diagnostic Logs…") {
                openLogs()
            }
        }

        Button("Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        .keyboardShortcut(",", modifiers: .command)

        CheckForUpdatesView(viewModel: updaterViewModel)

        Divider()

        // MARK: - Quit Action
        Button("Quit Sockystick") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
