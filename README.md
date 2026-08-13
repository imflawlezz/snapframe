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
- Cue list from a sidecar JSON next to the video
- Free-form crop overlay (width × height), optional **aspect lock** / **square**
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
2. Optionally load cues: auto-import `Movie.cues.json` beside the file, or **Import Cues…** (⌘I).
3. Scrub the timeline; step frames with ← / → (⇧ for ±10). Click the scrollbar track to jump the viewport.
4. Show the crop overlay (**C**), place and size the crop, **Save crop** (⌘S).
   Scroll adjusts height; **⇧scroll** adjusts width. **Aspect lock** (**L**) keeps the current ratio; **Square** (**R**) forces 1:1.
5. Find exports in `Movie_crops/` next to the source, with `metadata.json`.

### Supported formats

`.mp4` · `.m4v` · `.mov`

### Cues file

For `Movie.mp4`, Snapframe looks for:

```text
Movie.cues.json
```

| Field | Notes |
|-------|--------|
| `format` | `snapframe-cues` |
| `source` | Must match the video filename |
| `t` / `timecode` | Seconds and/or `HH:MM:SS.mmm` |
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
| [ / ] | Previous / next cue |
| ⌫ | Delete active cue |
| ⇧⌫ | Delete active crop |
| C | Toggle crop overlay |
| L | Aspect lock |
| R | Square proportions |
| P | Follow playhead |
| G | Go to timecode |
| Esc | Close video |
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

```text
snapframe/
  Domain/           entities + ports (CropRepository, CueRepository, ImageEncoding)
  Application/      use cases (e.g. SaveCropUseCase)
  Infrastructure/   AVFoundation player, stores, file access, image encode
  Presentation/     SwiftUI + AppKit UI, AppState composition root
```

`AppState` wires concrete Infrastructure types into Application ports. Domain stays Foundation / CoreGraphics only.

---

## License

Snapframe is released under the [MIT License](LICENSE).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
