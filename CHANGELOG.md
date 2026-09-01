# Changelog

All notable changes to Snapframe are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- Paused still preview now shows the exact frame used for export, so the stage matches saved crops
- Frame crop toolbar uses a shorter slide animation; the dim backdrop and crop overlay fade in after the toolbar settles, including when switching between **Frame crop** (**C**) and **Scissors** (**X**)
- Inspector show/hide is more responsive; the crop dim overlay stays aligned with the video during sidebar resize and toolbar transitions

### Fixed

- Cue navigation, **Refresh Preview** (**⌘R**), add cue at playhead (**N**), and **Save crop** (**⌘S**) now stay on the frame shown in the viewer; exported crops carry the correct timecode, and **Mark cue done after save** marks the cue at the playhead
- Frame crop overlay is shown again after returning from Home and reopening a video when **Frame crop** is still active

## [1.4.0] — 2026-08-25

### Added

- Check for Updates… in the app menu: compares the current version to the latest GitHub release and offers Download / View Release links

### Fixed

- Closing the last window quits the app and stops playback instead of leaving audio running in the background
- Document types no longer claim ownership of video files (`LSHandlerRank` Alternate; only `.mp4` / `.m4v` / `.mov`), so Snapframe does not become the default opener

## [1.3.0] — 2026-08-15

### Added

- **Scissors crop** (**X**): drag a region and save on release; hold **Shift** for a square; **Esc** exits; mutually exclusive with Frame crop
- Scissors hover readout of center-offset frame coordinates (`+x, +y`) near the cursor
- Add cue at playhead (**N**), creating/updating `Movie.cues.json` beside the source
- In-inspector cue editing (double-click or context menu), plus Mark Done and Delete
- **Snap to cues** (**S**) on the timeline, with separate time- and frame-based ranges in Preferences
- Go to start (**Return**) when focus is outside a text field (Playback menu included)
- Compact inspector layout for narrow widths (single-line crop rows; filename in the wide layout only)
- Custom About window in native macOS panel style (blurb, stack, “Made with ♥ by imflawlezz”)
- Crop inspector context menu: Reveal in Finder and Delete
- `snapframeTests` target, shared test scheme/plan, and unit tests for timecode parsing, digit-field filtering, crop geometry, cue/crop stores, and `SaveCropUseCase`

### Changed

- Frame crop (**C**) is optional and off by default; enabling scissors turns Frame crop off, and vice versa
- Inspector cue and crop lists follow the timeline Time / Frame display mode
- Timeline markers distinguish cues and crops by color; selection highlight is frame-exact and clears when the playhead leaves that frame
- Multiple cues/crops on the same frame can be pinned by clicking a specific row (for delete shortcuts)
- Clicking a cue or crop seeks immediately; crop clicks also restore the saved rectangle
- Timeline snap magnet applies to cues only (never crops), and only when Snap is enabled
- Timecode fields accept compact digit entry and flexible separators (`: ; . , - /`, spaces)
- Hardened Runtime enabled; App Sandbox remains off so sidecars can be written next to the video
- Cue repository covers in-app add/bind; crop metadata DTO lives in Infrastructure; shared crops-folder path helper
- Docs updated for the new crop modes, cue workflow, shortcuts, and architecture notes

### Fixed

- Cancel pending AVPlayer seeks before precise jumps so cue/crop navigation does not queue behind scrub seeks
- Remove leftover no-op player APIs and unused theme/motion helpers from the AVFoundation migration

### Removed

- Unused `snapframe.entitlements` (explicit sandbox-off) and empty Objective-C bridging header
- Crop-row tooltips in the inspector

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

[Unreleased]: https://github.com/imflawlezz/snapframe/compare/v1.4.0...HEAD
[1.4.0]: https://github.com/imflawlezz/snapframe/releases/tag/v1.4.0
[1.3.0]: https://github.com/imflawlezz/snapframe/releases/tag/v1.3.0
[1.2.0]: https://github.com/imflawlezz/snapframe/releases/tag/v1.2.0
[1.1.0]: https://github.com/imflawlezz/snapframe/releases/tag/v1.1.0
[1.0.0]: https://github.com/imflawlezz/snapframe/releases/tag/v1.0.0
