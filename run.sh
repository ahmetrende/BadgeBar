#!/bin/bash
# Build then (re)launch BadgeBar.app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$ROOT/BadgeBar.app"

"$ROOT/build.sh" "${1:-release}"

echo "▸ Relaunching…"
killall BadgeBar 2>/dev/null || true
open "$APP_DIR"
echo "✓ Launched. Look for icons in the menu bar."
