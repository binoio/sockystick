#!/bin/zsh
#
# release.sh: Build, sign, notarize (App Store Connect API), EdDSA-sign,
# and publish a Sockystick release with an updated Sparkle appcast.

set -euo pipefail

IDENTITY="${SOCKYSTICK_SIGN_IDENTITY:-Developer ID Application: Michael Bino (43L352U8Y8)}"
REPO="binoio/sockystick"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

NOTARY_PROFILE=""
for candidate in "${SOCKYSTICK_NOTARY_PROFILE:-}" sockystick-notary edith-notary atmo-notary; do
    [[ -n "$candidate" ]] || continue
    if xcrun notarytool history --keychain-profile "$candidate" >/dev/null 2>&1; then
        NOTARY_PROFILE="$candidate"
        break
    fi
done

VERSION=$(grep -m1 'MARKETING_VERSION' Sockystick.xcodeproj/project.pbxproj | sed 's/[^0-9.]*//g')
BUILD_NUMBER=$(grep -m1 'CURRENT_PROJECT_VERSION' Sockystick.xcodeproj/project.pbxproj | sed 's/[^0-9.]*//g')
TAG="v${VERSION}"
DERIVED_DATA="build/DerivedData"
APP="dist/Sockystick.app"
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
ZIP="dist/Sockystick-${VERSION}.zip"
NOTES_MD="ReleaseNotes/Sockystick-${VERSION}.md"
NOTES_HTML="ReleaseNotes/Sockystick-${VERSION}.html"

echo "==> Preflight for Sockystick ${VERSION} (build ${BUILD_NUMBER}, notary profile: ${NOTARY_PROFILE:-none})"

[[ "$BUILD_NUMBER" == "$VERSION" ]] || { echo "error: CURRENT_PROJECT_VERSION ($BUILD_NUMBER) must match MARKETING_VERSION ($VERSION)" >&2; exit 1; }
[[ -f "$NOTES_MD" ]] || { echo "error: $NOTES_MD missing" >&2; exit 1; }
[[ -f "$NOTES_HTML" ]] || { echo "error: $NOTES_HTML missing" >&2; exit 1; }

echo "==> Building (Release, unsigned; signed inside-out below)"
xcodebuild \
    -project Sockystick.xcodeproj \
    -scheme Sockystick \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    -destination 'generic/platform=macOS' \
    build \
    CODE_SIGNING_ALLOWED=NO

mkdir -p dist
rm -rf "$APP"
ditto "$DERIVED_DATA/Build/Products/Release/Sockystick.app" "$APP"

SPARKLE_BIN=$(find "$DERIVED_DATA/SourcePackages/artifacts" -type d -name bin -path "*parkle*" 2>/dev/null | head -1)

echo "==> Verifying bundle"
PLIST="$APP/Contents/Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$PLIST")" == "com.binoio.sockystick" ]] || { echo "error: wrong bundle id" >&2; exit 1; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$PLIST")" == "$VERSION" ]] || { echo "error: bundle version mismatch" >&2; exit 1; }

if [[ -n "$IDENTITY" && "$IDENTITY" != "none" ]]; then
    echo "==> Codesigning (inside-out; never --deep)"
    zsh Scripts/codesign_app.sh "$APP" "$IDENTITY"
    codesign --verify --deep --strict "$APP"
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
    echo "==> Notarizing via App Store Connect API"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
fi

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

if [[ -n "$SPARKLE_BIN" && -x "$SPARKLE_BIN/generate_appcast" ]]; then
    echo "==> Generating appcast"
    WORK="dist/appcast-work"
    rm -rf "$WORK"
    mkdir -p "$WORK"
    cp "$ZIP" "$WORK/"
    cp "$NOTES_HTML" "$WORK/Sockystick-${VERSION}.html"
    "$SPARKLE_BIN/generate_appcast" \
        --download-url-prefix "https://github.com/${REPO}/releases/download/${TAG}/" \
        --embed-release-notes \
        -o docs/appcast.xml "$WORK"
fi

echo "==> Build & release packaging complete: $ZIP"
