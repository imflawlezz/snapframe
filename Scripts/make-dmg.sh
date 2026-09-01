#!/usr/bin/env bash
set -euo pipefail

# Build a styled Snapframe-VERSION.dmg via dmgbuild.
#
# Visible: Snapframe.app · Applications · Quarantine.command
# Hidden:  .background.png
#
# Usage:
#   ./Scripts/make-dmg.sh
#   ./Scripts/make-dmg.sh --build

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/Snapframe.app"
PACKAGING="$ROOT/Packaging"
QUARANTINE="$PACKAGING/Quarantine.command"
BG_SRC="$PACKAGING/dmg-background.png"
BG_GEN="$PACKAGING/generate-dmg-background.swift"
SETTINGS="$PACKAGING/dmgbuild-settings.py"
VENV="$DIST/.dmg-venv"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

if [[ "${1:-}" == "--build" ]]; then
  "$ROOT/Scripts/build-release.sh"
fi

[[ -d "$APP" ]] || die "missing $APP — run ./Scripts/build-release.sh first (or pass --build)"
[[ -f "$SETTINGS" ]] || die "missing $SETTINGS"
[[ -f "$QUARANTINE" ]] || die "missing $QUARANTINE"

if [[ ! -f "$BG_SRC" ]]; then
  echo "Generating DMG background…"
  swift "$BG_GEN" "$BG_SRC"
fi
[[ -f "$BG_SRC" ]] || die "missing $BG_SRC"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo "0.0.0")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist" 2>/dev/null || echo "0")"
DMG_NAME="Snapframe_${VERSION}.dmg"
DMG_PATH="$DIST/$DMG_NAME"
VOLUME_NAME="Snapframe ${VERSION}"

eject_snapframe_volumes() {
  shopt -s nullglob
  local vol
  for vol in /Volumes/Snapframe*; do
    echo "Ejecting $vol …"
    hdiutil detach "$vol" -force >/dev/null 2>&1 || true
  done
  shopt -u nullglob
}

eject_snapframe_volumes

if [[ ! -x "$VENV/bin/dmgbuild" ]]; then
  echo "Installing dmgbuild into $VENV …"
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q --upgrade pip
  "$VENV/bin/pip" install -q 'dmgbuild>=1.6'
fi

chmod +x "$QUARANTINE"

rm -f "$DMG_PATH"
rm -f "$DIST"/rw.*.dmg "$DIST"/Snapframe-rw.dmg

echo "Creating styled DMG with dmgbuild …"
"$VENV/bin/dmgbuild" \
  -s "$SETTINGS" \
  -D "app=$APP" \
  -D "quarantine=$QUARANTINE" \
  -D "background=$BG_SRC" \
  "$VOLUME_NAME" \
  "$DMG_PATH"

xattr -dr com.apple.quarantine "$DMG_PATH" 2>/dev/null || true

SIZE="$(du -h "$DMG_PATH" | awk '{print $1}')"
echo
echo "Built: $DMG_PATH ($SIZE)"
echo "Version: $VERSION ($BUILD)"
echo "Visible: Snapframe.app · Applications · Quarantine.command"
echo "Open with: open \"$DMG_PATH\""
