#!/usr/bin/env bash
set -euo pipefail

# Build a universal (arm64 + x86_64) Release Snapframe.app into dist/.
#
# Usage (from repo root):
#   ./Scripts/build-release.sh

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
DERIVED="$DIST/DerivedData"
APP_DST="$DIST/Snapframe.app"

log() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

build_slice() {
  local arch="$1"
  local out_app="$2"
  local slice_derived="$DERIVED/$arch"

  log "Building $arch …"
  rm -rf "$slice_derived"
  mkdir -p "$slice_derived"

  xcodebuild \
    -project "$ROOT/snapframe.xcodeproj" \
    -scheme snapframe \
    -configuration Release \
    -derivedDataPath "$slice_derived" \
    -destination 'generic/platform=macOS' \
    ARCHS="$arch" \
    ONLY_ACTIVE_ARCH=YES \
    EXCLUDED_ARCHS="" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY=- \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=YES \
    DEVELOPMENT_TEAM= \
    build

  local built="$slice_derived/Build/Products/Release/Snapframe.app"
  [[ -d "$built" ]] || die "missing $built"
  rm -rf "$out_app"
  cp -R "$built" "$out_app"
}

rm -rf "$APP_DST" "$DIST/Snapframe-x86_64.app" "$DIST/Snapframe-arm64.app"
mkdir -p "$DIST"

build_slice x86_64 "$DIST/Snapframe-x86_64.app"
build_slice arm64 "$DIST/Snapframe-arm64.app"

X86_BIN="$DIST/Snapframe-x86_64.app/Contents/MacOS/Snapframe"
ARM_BIN="$DIST/Snapframe-arm64.app/Contents/MacOS/Snapframe"
[[ -f "$X86_BIN" && -f "$ARM_BIN" ]] || die "slice binaries missing"

rm -rf "$APP_DST"
cp -R "$DIST/Snapframe-arm64.app" "$APP_DST"
UNIVERSAL_BIN="$APP_DST/Contents/MacOS/Snapframe"
lipo -create -output "$UNIVERSAL_BIN" "$ARM_BIN" "$X86_BIN"
chmod +x "$UNIVERSAL_BIN"

IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/{print $2; exit}')"
if [[ -n "${CI:-}" ]]; then
  codesign --force --deep --sign - "$APP_DST"
elif [[ -n "$IDENTITY" ]]; then
  codesign --force --deep --options runtime --sign "$IDENTITY" "$APP_DST"
else
  codesign --force --deep --sign - "$APP_DST"
fi

log
log "Built: $APP_DST"
log "Version: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DST/Contents/Info.plist" 2>/dev/null || echo '?') ($(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_DST/Contents/Info.plist" 2>/dev/null || echo '?'))"
log "Binary:  $(lipo -info "$UNIVERSAL_BIN")"
log
log "Open with: open \"$APP_DST\""
