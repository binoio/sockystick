//
//  ContentView.swift
//  Sockystick
//
//  Standard macOS window UI matched to default size and layout.
//

import SwiftUI

public struct ContentView: View {
    @ObservedObject public var viewModel: ProxyStateViewModel
    @Environment(\.openWindow) private var openWindow

    public init(viewModel: ProxyStateViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            Form {
                // MARK: - Network Interface Section
                Section("Network Interface") {
                    Picker("Active Interface:", selection: Binding(
                        get: { viewModel.activeInterface ?? viewModel.availableInterfaces.first },
                        set: { if let iface = $0 { viewModel.selectInterface(iface) } }
                    )) {
                        ForEach(viewModel.availableInterfaces) { iface in
                            Text(iface.displayName).tag(Optional(iface))
                        }
                    }
                    .pickerStyle(.menu)
                }

                // MARK: - Proxy Server Configuration Section
                Section("SOCKS5 Proxy Server") {
                    TextField("IP / Host:", text: $viewModel.proxyHost)
                        .textFieldStyle(.roundedBorder)

                    TextField("Port:", text: $viewModel.proxyPortString)
                        .textFieldStyle(.roundedBorder)

                    Toggle("Require Authentication", isOn: $viewModel.useAuthentication)

                    TextField("Username:", text: $viewModel.proxyUsername)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password:", text: $viewModel.proxyPassword)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 12) {
                        Text("Presets:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Default (192.168.7.202:1080)") {
                            viewModel.applyPreset(host: "192.168.7.202", port: 1080)
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)

                        Button("Localhost (127.0.0.1:1080)") {
                            viewModel.applyPreset(host: "127.0.0.1", port: 1080)
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    .padding(.top, 2)
                }

                // MARK: - Action Row Section
                Section {
                    HStack {
                        StatusBadgeView(isEnabled: viewModel.isProxyEnabled)

                        Spacer()

                        Button(action: {
                            viewModel.toggleProxy()
                        }) {
                            Label(
                                viewModel.isProxyEnabled ? "Turn Off SOCKS5 Proxy" : "Turn On SOCKS5 Proxy",
                                systemImage: "power"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(viewModel.isProxyEnabled ? .red : .accentColor)
                        .controlSize(.regular)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // MARK: - Footer Status Bar
            HStack {
                Image(systemName: viewModel.useAuthentication ? "lock.shield" : "info.circle")
                    .foregroundColor(.secondary)
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                Button(action: {
                    openWindow(id: "logs")
                }) {
                    Image(systemName: "scroll")
                }
                .buttonStyle(.plain)
                .help("Open Diagnostic Logs")

                Button(action: {
                    viewModel.refreshStatus()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(viewModel.isUpdating ? 360 : 0))
                }
                .buttonStyle(.plain)
                .help("Refresh Status")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .navigationTitle("Sockystick")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    openWindow(id: "logs")
                } label: {
                    Label("Logs", systemImage: "scroll")
                }
                .help("Open Diagnostic Logs (Cmd+Option+L)")
            }
        }
        .frame(minWidth: 480, idealWidth: 520, maxWidth: 580, minHeight: 480, idealHeight: 520, maxHeight: 600)
    }
}
