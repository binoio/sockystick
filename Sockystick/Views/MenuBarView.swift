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
            viewModel.disableProxyOnQuit()
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

// MARK: - Menu Bar Vector Icon Generation
public enum MenuBarIcon {
    public static let disconnected: NSImage = createStickImage(withPuck: false)
    public static let connected: NSImage = createStickImage(withPuck: true)

    public static func createStickImage(withPuck: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let black = NSColor.black.cgColor
            ctx.setFillColor(black)
            
            // Balanced vector bounds within 18x18 pt canvas
            let stickPath = CGMutablePath()
            // Handle knob at top-left
            stickPath.move(to: CGPoint(x: 2.6, y: 16.5))
            stickPath.addLine(to: CGPoint(x: 4.4, y: 16.5))
            stickPath.addLine(to: CGPoint(x: 3.9, y: 15.0))
            // Shaft right side
            stickPath.addLine(to: CGPoint(x: 8.6, y: 4.8))
            // Blade top side
            stickPath.addLine(to: CGPoint(x: 13.0, y: 4.8))
            // Blade toe
            stickPath.addArc(tangent1End: CGPoint(x: 14.0, y: 4.8), tangent2End: CGPoint(x: 14.0, y: 2.8), radius: 1.0)
            stickPath.addArc(tangent1End: CGPoint(x: 14.0, y: 2.8), tangent2End: CGPoint(x: 13.0, y: 2.8), radius: 1.0)
            // Blade bottom (ice level)
            stickPath.addLine(to: CGPoint(x: 7.2, y: 2.8))
            // Heel
            stickPath.addArc(tangent1End: CGPoint(x: 6.2, y: 2.8), tangent2End: CGPoint(x: 6.6, y: 4.4), radius: 1.2)
            // Shaft left side
            stickPath.addLine(to: CGPoint(x: 2.2, y: 15.0))
            stickPath.closeSubpath()
            
            ctx.addPath(stickPath)
            ctx.fillPath()
            
            if withPuck {
                // Hockey puck disc on the ice ahead of the blade toe
                let puckRect = CGRect(x: 14.8, y: 2.8, width: 2.4, height: 2.0)
                let puckPath = CGPath(roundedRect: puckRect, cornerWidth: 0.6, cornerHeight: 0.6, transform: nil)
                ctx.addPath(puckPath)
                ctx.fillPath()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
