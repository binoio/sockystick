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
                Section("Appearance") {
                    Toggle("Show Dock Icon", isOn: Binding(
                        get: { !proxyViewModel.hideDockIcon },
                        set: { proxyViewModel.hideDockIcon = !$0 }
                    ))

                    if proxyViewModel.hideDockIcon {
                        Text("Sockystick will remain available from the menu bar extra while the Dock icon is hidden.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Launch & Startup Behavior") {
                    Toggle("Start Sockystick at login", isOn: $proxyViewModel.launchAtLogin)
                    Toggle("Automatically enable SOCKS5 proxy on app launch", isOn: $proxyViewModel.autoStartProxyOnLaunch)
                }

                Section("Safari & iCloud Private Relay") {
                    Toggle("Reset Safari networking on connect/disconnect", isOn: $proxyViewModel.resetSafariNetworkingOnToggle)
                    Text("Restarts Safari's background networking process (keeping windows and tabs open) so Safari drops cached iCloud Private Relay or proxy connections immediately.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("LAN DNS (Split-Horizon Names)") {
                    Toggle("Resolve hostnames via LAN DNS before proxying", isOn: $proxyViewModel.lanDNSEnabled)
                    TextField("DNS Server:", text: $proxyViewModel.lanDNSServer, prompt: Text("Auto (\(proxyViewModel.detectedLANDNSServer))"))
                        .textFieldStyle(.roundedBorder)
                        .disabled(!proxyViewModel.lanDNSEnabled)
                        .onSubmit { proxyViewModel.applyLANDNSSettings() }
                    TextField("Domains:", text: $proxyViewModel.lanDNSDomains, prompt: Text("All hostnames (e.g. example.com, home.arpa)"))
                        .textFieldStyle(.roundedBorder)
                        .disabled(!proxyViewModel.lanDNSEnabled)
                        .onSubmit { proxyViewModel.applyLANDNSSettings() }
                    Text("Looks up names on your LAN DNS server (e.g. Pi-hole) and sends the LAN address to the proxy, so internal names don't resolve to public WAN addresses on the remote side. Falls back to remote resolution if the lookup fails. Press Return to apply.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        .frame(width: 480, height: 520)
    }
}
