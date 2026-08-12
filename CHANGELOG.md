# Changelog

All notable changes to Snapframe are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.1.0] — 2026-08-12

### Changed

- Replaced Homebrew **libmpv** playback with native **AVFoundation** (`AVPlayer` + frame-accurate capture)
- DMG ships **Quarantine.command** to clear Gatekeeper quarantine
- Keyboard shortcuts redesigned for a frame-step workflow; bindings use physical key positions so they work on any input layout
- Frame skip controls use single / double chevrons instead of digit labels
- Preferences trimmed: removed snap-to-cue and obsolete mpv-era preview settings
- Crop overlay toggle shortcut is now **C** (was ⌘⇧C)

### Added

- Embedded video stage with live preview
- Custom NLE-style timeline: ruler, playhead, frame/time grid, cue and crop markers
- Timeline pan (scroll) and zoom (⇧scroll) at cursor
- Resizable inspector sidebar and cues/crops split (widths persisted)
- `SnapMotion` animation tokens for UI transitions
- Transport volume slider (level persisted)
- Recents clear / remove transitions
- Speed shortcuts: **1** / **2** / **3** → 0.5× / 1× / 2×

### Removed

- Runtime dependency on Homebrew `mpv` / `libmpv`
- Snap-to-nearest-cue seeking and related preference
- Bare letter shortcuts that conflicted with typed input (`O` / `I` without ⌘)

### Fixed

- Frame step no longer briefly unpauses or plays audio
- Resize dividers no longer jitter during drag
- Home button tooltip no longer sticks after leaving the workspace
- Crop delete shortcut uses **⇧⌫** (⌘⌫ conflicted with system behavior)

### Notes

- Supported formats: MP4, MOV, M4V
- Downloaded builds may still need quarantine cleared (`Quarantine.command`, `xattr`, or right-click Open)
- Licensed under MIT; no third-party media engine is bundled or required

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

- Required Homebrew `mpv` (`libmpv`) at runtime; not bundled
- App Sandbox and Hardened Runtime disabled so Homebrew libraries can load
- Downloaded builds may need quarantine cleared (`xattr` or right-click Open)
- Licensed under MIT; mpv remained a separate GPL-licensed dependency

[Unreleased]: https://github.com/imflawlezz/snapframe/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/imflawlezz/snapframe/releases/tag/v1.1.0
[1.0.0]: https://github.com/imflawlezz/snapframe/releases/tag/v1.0.0
