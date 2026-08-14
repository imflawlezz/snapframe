# Snapframe

**Snapframe** is a native macOS tool for frame-accurate video scrubbing, cue-based navigation, and free-form crop export.

Open a video, jump between marked moments, frame a crop (free, locked ratio, or square), and save stills next to the source — without a heavyweight NLE.

| | |
|---|---|
| **Platform** | macOS |
| **Version** | 1.2.0 |
| **License** | [MIT](LICENSE) |
| **Playback** | AVFoundation |

---

## Install

1. Open `Snapframe_1.2.0.dmg`.
2. Drag **Snapframe.app** into **Applications**.
3. Double-click **Quarantine.command** in the DMG.  
   If macOS blocks it: right-click → **Open** → **Open**.
4. Launch **Snapframe** from Applications.

Downloaded builds are quarantined by Gatekeeper. **Quarantine.command** clears that flag. Manually:

```bash
xattr -dr com.apple.quarantine /Applications/Snapframe.app
open /Applications/Snapframe.app
```

Or right-click the app → **Open**.

---

## Features

- Live video stage with frame-accurate scrubbing and still capture
- Cue list: mark moments in-app (**N**), double-click to edit, or import a sidecar JSON
- **Frame crop** overlay (width × height), optional **aspect lock** / **square**
- **Scissors crop**: drag a region and save on release, like a screenshot
- Crop bar: size, center offset, locks, ratio readout
- Export crops as PNG or JPEG into a `{name}_crops/` folder
- Timeline with pan, zoom, follow playhead, markers, and a fixed time/frame grid
- Transport: playback, frame skip, time skip (−5s…+5s), speed
- Recents with thumbnails
- Light / Dark / System appearance
- Keyboard-first workflow (physical keys, any input layout)

---

## Usage

1. **Open** a video (⌘O), drop a file onto the window, or pick a recent item.
2. Mark cues at the playhead (**N**), or load a list: auto-import `Movie.cues.json` beside the file, or **Import Cues…** (⌘I). Double-click a cue (or right-click → **Edit**) to change time and label. Time / Frame on the timeline also switches the inspector lists. **Snap to cues** (**S**) pulls the playhead onto a nearby cue; snap range is in Preferences (separate time / frame values).
3. Scrub the timeline; step frames with ← / → (⇧ for ±10). Click the scrollbar track to jump the viewport.
4. **Frame crop** (**C**) shows the overlay and crop bar. Place and size the crop, then **Save crop** (**⌘S**).
   Scroll adjusts height; **⇧scroll** adjusts width. **Aspect lock** (**L**) keeps the current ratio; **Square** (**R**) forces 1:1.
   **Scissors crop** (**X**) is an alternative: the viewer stays clean until you drag. Press, drag to the opposite corner, release — the crop saves immediately. **Esc** exits scissors. Frame crop and scissors are mutually exclusive.
5. Find exports in `Movie_crops/` next to the source, with `metadata.json`.

### Supported formats

`.mp4` · `.m4v` · `.mov`

### Cues file

Adding a cue (**N**) creates this sidecar next to the video. Snapframe also auto-imports it on open, or you can **Import Cues…**.

For `Movie.mp4`:

```text
Movie.cues.json
```

| Field | Notes |
|-------|--------|
| `format` | `snapframe-cues` |
| `source` | Must match the video filename |
| `t` / `timecode` | Seconds and/or `HH:MM:SS.mmm` (compact digits and flexible separators also work in the app) |
| `done` | Mark finished cues |

Example: [`Examples/Sample.cues.json`](Examples/Sample.cues.json)

### Crop output

```text
Movie_crops/
  crop_001.png
  crop_002.jpg
  metadata.json
```

Each crop stores `x` / `y` / `width` / `height` (legacy square `size` still loads).  
Example: [`Examples/Sample_crops/metadata.json`](Examples/Sample_crops/metadata.json)

### Keyboard shortcuts

Shortcuts use physical key positions (US QWERTY), so they work the same on any input layout.

| Key | Action |
|-----|--------|
| Space | Play / pause |
| ← / → | Frame −1 / +1 |
| ⇧← / ⇧→ | Frame −10 / +10 |
| ⌥← / ⌥→ | Seek −1s / +1s |
| ⇧⌥← / ⇧⌥→ | Seek −5s / +5s |
| 1 / 2 / 3 | Speed 0.5× / 1× / 2× |
| M | Mute |
| N | Add cue at playhead |
| [ / ] | Previous / next cue |
| ⌫ | Delete active cue |
| ⇧⌫ | Delete active crop |
| C | Frame crop |
| X | Scissors crop |
| L | Aspect lock |
| R | Square proportions |
| P | Follow playhead |
| S | Snap to cues |
| G | Go to timecode |
| Return | Go to start |
| Esc | Exit scissors / close video |
| ⌘O | Open video |
| ⌘I | Import cues |
| ⌘S | Save crop |
| ⌘R | Refresh preview |
| ⌘\\ | Toggle inspector |
| ⌘, | Preferences |

---

## Build from source

Requires **Xcode**.

```bash
open snapframe.xcodeproj
```

Select the **Snapframe** scheme and run (Debug or Release).

Unit tests live in the **snapframeTests** scheme (⌘U in Xcode), or:

```bash
xcodebuild test -scheme snapframeTests -destination 'platform=macOS'
```

```text
snapframe/
  Domain/           entities + ports (CropRepository, CueRepository, ImageEncoding)
  Application/      use cases (e.g. SaveCropUseCase)
  Infrastructure/   AVFoundation player, stores, file access, image encode
  Presentation/     SwiftUI + AppKit UI, AppState composition root
  snapframeTests/   XCTest coverage for domain and persistence
```

`AppState` is the composition root: it owns Infrastructure types and drives the one Application use case (`SaveCropUseCase`). Domain stays Foundation / CoreGraphics only.

---

## License

Snapframe is released under the [MIT License](LICENSE).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
