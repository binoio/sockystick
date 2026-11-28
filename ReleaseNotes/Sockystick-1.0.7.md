# Sockystick 1.0.7

Sockystick 1.0.7 resolves hostnames on your LAN DNS server before proxying, so split-horizon names (for example a Pi-hole local record) reach your LAN services instead of their public WAN addresses.

### What's New
- **LAN DNS Resolution**: The local bridge looks up each hostname on your LAN DNS server (auto-detected from the system's private IPv4 resolver, e.g. Pi-hole) and forwards the LAN address to the remote SOCKS5 proxy. TLS SNI and Host headers are unchanged, so the right virtual host and certificate are still selected. Lookups that fail, time out, or are blocked fall back to remote resolution. Configurable in **Settings → General → LAN DNS**, with an optional server override and domain list.
- **Fail-Fast Upstream Errors**: When the remote SOCKS5 server is unreachable or refuses the connection, the bridge now returns an immediate "connection refused" reply instead of leaving browser connections hanging.
- **Bridge Without Authentication**: The local bridge now also runs for unauthenticated proxies when LAN DNS resolution is enabled.
- **Test Isolation**: Running the test suite no longer clears the app's saved proxy settings.
