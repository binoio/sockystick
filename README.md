# Sockystick

A macOS GUI Dock and Menu Bar app for quickly toggling SOCKS5 proxy configurations on active network interfaces.

![Sockystick Icon](docs/images/icon.svg)

## Features

- **One-Click Proxy Toggle**: Easily enable or disable SOCKS5 proxy state on active default or selected network interfaces (`Wi-Fi`, `Ethernet`).
- **Dock & Menu Bar Modes**: Control proxy settings from the status item popover or the main desktop window.
- **Auto-Detection**: Automatically identifies your active default network device (e.g. `en0`) and maps it to the system network setup service.
- **Sparkle 2 Updates**: Integrated automatic software updates signed with EdDSA keys.
- **Developer ID & Notarization**: Native macOS app built with Swift and SwiftUI, signed with Apple Developer ID.

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0+ to build from source

## Developer Workflow

```bash
# Build Debug configuration
zsh Scripts/build.sh

# Run Debug app
zsh Scripts/run.sh

# Run test suite
zsh Scripts/test.sh

# Run unit and UI test suite
zsh Scripts/test.sh --ui

# Render icon assets
xcrun swift Scripts/generate_icon.swift
```

## Release Workflow

```bash
# Build, sign, notarize, generate Sparkle appcast, and publish release
zsh Scripts/release.sh
```

## License

MIT License. Copyright © 2026 Michael Bino.
