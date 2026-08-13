# Changelog

All notable changes to Snapframe are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.2.0] — 2026-08-13

### Added

- Free-form crop rectangle: independent **width** / **height**, not only square
- **Aspect lock** (**L**) freezes the current ratio; **Square** (**R**) forces 1:1 (mutually exclusive)
- Crop bar above the viewer: Width / Height, Center X / Y, lock buttons, live ratio readout, Save (⌘S)
- Edge resize handles (N/E/S/W) in addition to corners; locked resize keeps the opposite side centered
- Follow playhead (**P**) with a margin so the playhead stays in view during playback
- Timeline scrollbar: click empty track to jump the viewport under the cursor (then drag as usual)
- Transport **Time Skip** group: −5s / −1s / +1s / +5s (same bindings as ⌥ / ⇧⌥ arrows)
- Menu items for Aspect Lock, Square Proportions, Follow Playhead, and second seeks

### Changed

- Crop export / `metadata.json` store `width` and `height` (legacy square `size` still loads)
- Crop overlay: scroll changes **height**; **⇧scroll** changes **width** (Option no longer required)
- Aspect lock starts **off**; enabling it captures the current W:H as the locked ratio
- Transport deck regrouped: Playback | Frame Skip | Time Skip | Speed
- Timeline ruler uses a fixed 1–2–5 (or N-frame) grid from `t = 0`; labels/ticks translate with `viewStart` instead of being regenerated from the left edge
- Ruler labels clip inside the timeline surface (full-width track, no side gutters leaking digits)
- Letter hotkeys (**C**, **M**, **L**, **R**, **P**, **G**, **1**–**3**, brackets) are handled by a local `keyCode` monitor before SwiftUI menus, so they work on any keyboard layout
- Crop wheel sensitivity raised slightly for faster sizing
- Save path injects `ImageEncoding` (Domain port); unused AV/AppKit `VideoPlaying` port removed from Domain

### Fixed

- With aspect / square lock, growing one axis after the other hit the video frame no longer breaks the ratio — both axes stop together
- Locked edge resize no longer shifts only one side when clamped to the letterbox
- **⇧scroll** width adjust failed because AppKit reports Shift+vertical wheel as `scrollingDeltaX`
- Timeline labels jumped and showed irregular gaps (e.g. 0.5 → 4.5) while panning; they now stay on the global grid
- Bare letter shortcuts failed on non-English layouts (menus matched Latin characters; physical keys still emit the local glyph)
- Zero-tolerance AVPlayer seeks could stall on long-GOP files; scrub/precise seeks use frame-based tolerances instead
- Playhead 1 ms drift after seeks: positions snap to frame boundaries via `Timecode.snapped`
- Time observer no longer overwrites the UI position with sub-frame AVPlayer noise while paused / scrubbing
- Frame step avoids syncing noisy player time back onto the displayed position

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

[Unreleased]: https://github.com/imflawlezz/snapframe/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/imflawlezz/snapframe/releases/tag/v1.2.0
[1.1.0]: https://github.com/imflawlezz/snapframe/releases/tag/v1.1.0
[1.0.0]: https://github.com/imflawlezz/snapframe/releases/tag/v1.0.0
