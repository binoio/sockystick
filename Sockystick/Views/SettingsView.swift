//
//  SettingsView.swift
//  Sockystick
//
//  Settings / Preferences window using standard macOS form controls.
//

import SwiftUI

public struct SettingsView: View {
    @ObservedObject public var proxyViewModel: ProxyStateViewModel
    @ObservedObject public var updaterViewModel: UpdaterViewModel

    public init(proxyViewModel: ProxyStateViewModel, updaterViewModel: UpdaterViewModel) {
        self.proxyViewModel = proxyViewModel
        self.updaterViewModel = updaterViewModel
    }

    public var body: some View {
        TabView {
            // MARK: - General Tab
            Form {
                Section("Launch & Startup Behavior") {
                    Toggle("Start Sockystick at login", isOn: $proxyViewModel.launchAtLogin)
                    Toggle("Automatically enable SOCKS5 proxy on app launch", isOn: $proxyViewModel.autoStartProxyOnLaunch)
                }

                Section("Default Proxy Parameters") {
                    TextField("Default Host:", text: $proxyViewModel.proxyHost)
                        .textFieldStyle(.roundedBorder)

                    TextField("Default Port:", text: $proxyViewModel.proxyPortString)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Proxy Authentication (Keychain Stored)") {
                    Toggle("Require Authentication", isOn: $proxyViewModel.useAuthentication)

                    TextField("Username:", text: $proxyViewModel.proxyUsername)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password (Saved in Keychain):", text: $proxyViewModel.proxyPassword)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .formStyle(.grouped)
            .padding(10)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            // MARK: - Sparkle Updates Tab
            Form {
                Section("Software Updates (Sparkle 2)") {
                    Toggle("Automatically check for updates", isOn: Binding(
                        get: { updaterViewModel.automaticallyChecksForUpdates },
                        set: { updaterViewModel.automaticallyChecksForUpdates = $0 }
                    ))

                    Toggle("Automatically download updates", isOn: Binding(
                        get: { updaterViewModel.automaticallyDownloadsUpdates },
                        set: { updaterViewModel.automaticallyDownloadsUpdates = $0 }
                    ))
                    .disabled(!updaterViewModel.automaticallyChecksForUpdates)

                    if let lastCheck = updaterViewModel.lastUpdateCheckDate {
                        LabeledContent("Last checked:", value: lastCheck.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    CheckForUpdatesView(viewModel: updaterViewModel)
                }
            }
            .formStyle(.grouped)
            .padding(10)
            .tabItem {
                Label("Updates", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .frame(width: 480, height: 380)
    }
}
