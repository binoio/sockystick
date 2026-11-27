# Sockystick 1.0.6

Sockystick 1.0.6 adds clean connection handoff for Safari and iCloud Private Relay so Safari immediately obeys the SOCKS5 proxy on connect and returns cleanly on disconnect.

### What's New
- **Safari & iCloud Private Relay Handoff**: Automatically restarts Safari's background `Safari Networking` XPC process on connect, disconnect, and quit (keeping windows and tabs open) so cached iCloud Private Relay QUIC tunnels and stale proxy pools are flushed immediately. Configurable in **Settings → General**.
- **Clean Bridge Teardown**: Tracks and closes all active bridged connections when stopping the local SOCKS5 auth bridge, and disables the macOS SOCKS5 proxy before stopping the bridge to eliminate transition errors.
- **Default Host**: Defaults the proxy host to `127.0.0.1` instead of a private LAN address for fresh setups.
