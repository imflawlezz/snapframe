# Changelog

All notable changes to Snapframe are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0] — 2026-08-11

First public release.

### Added

- Native macOS video workspace (SwiftUI + AppKit) with libmpv playback
- Timeline scrubbing, frame step, variable speed, mute
- Frame preview via `vo=null` + `screenshot-raw` (no embedded video view)
- Square crop overlay: drag, corner resize, scroll to size
- Crop export to PNG/JPEG into `{stem}_crops/` with `metadata.json`
- Cue sidecar (`*.cues.json`): pending/done, next/prev, optional snap-to-cue
- Recents with silent midpoint thumbnails (no preview blink on open)
- Preferences: System/Light/Dark theme, export format, cue workflow, snap range
- Clean Architecture layout: Domain / Application / Infrastructure / Presentation

### Notes

- Requires Homebrew `mpv` (`libmpv`) at runtime; not bundled
- App Sandbox and Hardened Runtime disabled so Homebrew libraries can load
- Downloaded builds may need quarantine cleared (`xattr` or right-click Open)
- Licensed under MIT; mpv remains a separate GPL-licensed dependency

[Unreleased]: https://github.com/imflawlezz/snapframe/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/imflawlezz/snapframe/releases/tag/v1.0.0
