# Release Instructions for Sockystick

To publish a new release of Sockystick:

1. **Version Bump**:
   - Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Sockystick.xcodeproj/project.pbxproj`.
   - Update `VERSION` file.
   
2. **Release Notes**:
   - Write `ReleaseNotes/Sockystick-X.Y.Z.md` (for GitHub releases).
   - Write `ReleaseNotes/Sockystick-X.Y.Z.html` (for Sparkle appcast).

3. **Release Execution**:
   ```bash
   zsh Scripts/release.sh
   ```

`release.sh` handles:
- Preflight verification (working tree clean, version matching, release notes).
- Building Release configuration with Xcode.
- Inside-out codesigning with entitlements and hardened runtime (`Scripts/codesign_app.sh`).
- Notarization with Apple Store Connect API (`notarytool`) and stapling (`stapler`).
- Generating Sparkle appcast (`docs/appcast.xml`).
- Publishing release to GitHub and pushing tags.
