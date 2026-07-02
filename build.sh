#!/bin/bash
# Builds BadgeBar.app from the Swift package and ad-hoc code-signs it.
# No Xcode required — only the Swift toolchain from Command Line Tools.
set -euo pipefail

APP_NAME="BadgeBar"
ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${1:-release}"
BIN_DIR="$ROOT/.build/$CONFIG"
APP_DIR="$ROOT/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"

echo "▸ Compiling ($CONFIG)…"
swift build -c "$CONFIG"

echo "▸ Assembling $APP_NAME.app…"
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN_DIR/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME"
cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"
if [ -f "$ROOT/AppIcon.icns" ]; then
    cp "$ROOT/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
fi

# Prefer a stable self-signed identity (created by setup-signing.sh) so the
# Accessibility permission survives rebuilds. Fall back to ad-hoc otherwise.
# shellcheck source=signing-config.sh
source "$ROOT/signing-config.sh"
BUNDLE_ID="com.ahmetrende.badgebar"

# Note: a self-signed cert is "not trusted", so it won't appear under
# `find-identity -v`; query without -v to find it.
if [ -f "$KEYCHAIN" ] && security find-identity -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "$IDENTITY"; then
    echo "▸ Code-signing with stable identity ($IDENTITY)…"
    security unlock-keychain -p "$KC_PASS" "$KEYCHAIN" 2>/dev/null || true
    codesign --force --sign "$IDENTITY" --identifier "$BUNDLE_ID" "$APP_DIR"
else
    echo "▸ Code-signing (ad-hoc — run ./setup-signing.sh to make permission persist)…"
    codesign --force --sign - "$APP_DIR"
fi

echo "✓ Built $APP_DIR"
