#!/bin/bash
# Build BadgeBar.app and package it into a drag-to-install BadgeBar.dmg.
# Zero dependencies — uses the system `hdiutil`.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="BadgeBar"
APP="$ROOT/$APP_NAME.app"
DMG="$ROOT/$APP_NAME.dmg"

"$ROOT/build.sh" release

echo "▸ Staging disk image…"
STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"   # drag-to-install shortcut

echo "▸ Creating $APP_NAME.dmg…"
rm -f "$DMG"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG" >/dev/null
rm -rf "$STAGING"

echo "✓ Built $DMG ($(du -h "$DMG" | cut -f1))"
