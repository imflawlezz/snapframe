#!/usr/bin/env bash
set -euo pipefail

# Run xcodebuild without a local Apple Development certificate.
# GitHub Actions runners have no team signing identity installed.

exec xcodebuild \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  DEVELOPMENT_TEAM= \
  "$@"
