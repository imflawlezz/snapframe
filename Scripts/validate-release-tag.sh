#!/usr/bin/env bash
set -euo pipefail

# Verify a release tag matches MARKETING_VERSION and CHANGELOG has notes.
#
# Usage:
#   ./Scripts/validate-release-tag.sh v1.4.0

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:?usage: validate-release-tag.sh vX.Y.Z}"
VERSION="${TAG#v}"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

MARKETING="$(
  xcodebuild -showBuildSettings \
    -project "$ROOT/snapframe.xcodeproj" \
    -scheme snapframe \
    -configuration Release \
    2>/dev/null \
  | awk -F' = ' '/MARKETING_VERSION/{print $2; exit}'
)"

[[ -n "$MARKETING" ]] || die "could not read MARKETING_VERSION from Xcode project"
[[ "$VERSION" == "$MARKETING" ]] \
  || die "tag $TAG does not match MARKETING_VERSION $MARKETING"

python3 "$ROOT/Scripts/extract-release-notes.py" "$VERSION" >/dev/null \
  || die "CHANGELOG.md has no release notes for $VERSION"

printf 'release tag %s matches MARKETING_VERSION %s\n' "$TAG" "$MARKETING"
