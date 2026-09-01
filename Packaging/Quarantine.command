#!/bin/bash
# Double-click after dragging Snapframe into Applications.
# Clears macOS Gatekeeper quarantine so Snapframe can launch.

set -euo pipefail

clear 2>/dev/null || true
echo "========================================"
echo "  Snapframe — Clear Quarantine"
echo "========================================"
echo

find_app() {
  local candidates=(
    "/Applications/Snapframe.app"
    "$HOME/Applications/Snapframe.app"
    "$(cd "$(dirname "$0")" && pwd)/Snapframe.app"
  )
  local p
  for p in "${candidates[@]}"; do
    if [[ -d "$p" ]]; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

APP="$(find_app || true)"
if [[ -z "${APP:-}" ]]; then
  echo "Snapframe.app not found."
  echo "Drag Snapframe into Applications, then run this again."
  echo
  read -r -p "Press Return to close…" _
  exit 1
fi

echo "Found: $APP"
echo
echo "→ Clearing quarantine…"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
echo "  done"
echo
echo "========================================"
echo "  Quarantine cleared"
echo "  You can open Snapframe from Applications."
echo "========================================"
echo
read -r -p "Press Return to close…" _
