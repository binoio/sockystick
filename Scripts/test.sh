#!/bin/zsh
#
# test.sh: Run the Sockystick test suites.
#
# Usage: Scripts/test.sh [--ui]
#   Runs the SockystickTests unit suite by default; --ui also runs SockystickUITests.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

killall Sockystick 2>/dev/null || true

ARGS=(-project Sockystick.xcodeproj -scheme Sockystick -derivedDataPath build/DerivedData -destination 'platform=macOS')
if [[ "${1:-}" == "--ui" ]]; then
    echo "==> Running unit and UI tests"
    xcodebuild test "${ARGS[@]}"
else
    echo "==> Running unit tests (SockystickTests)"
    xcodebuild test "${ARGS[@]}" -only-testing:SockystickTests
fi
