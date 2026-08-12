# Snapframe

**Snapframe** is a native macOS tool for frame-accurate video scrubbing, cue-based navigation, and square crop export.

Open a video, jump between marked moments, frame a square crop, and save stills next to the source — without a heavyweight NLE.

| | |
|---|---|
| **Platform** | macOS |
| **Version** | 1.1.0 |
| **License** | [MIT](LICENSE) |
| **Playback** | AVFoundation |

---

## Install

1. Open `Snapframe_1.1.0.dmg`.
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
- Square crop overlay — drag, resize, scroll to change size
- Export crops as PNG or JPEG into a `{name}_crops/` folder
- Timeline with zoom, markers, and frame/time grid
- Recents with thumbnails
- Light / Dark / System appearance
- Keyboard-first workflow (physical keys, any input layout)

---

## Usage

1. **Open** a video (⌘O), drop a file onto the window, or pick a recent item.
2. Optionally load cues: auto-import `Movie.cues.json` beside the file, or **Import Cues…** (⌘I).
3. Scrub the timeline; step frames with ← / → (⇧ for ±10).
4. Show the crop overlay (**C**), place the square, **Save crop** (⌘S).
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
  crop_002.png
  metadata.json
```

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
  Domain/           entities + ports
  Application/      use cases
  Infrastructure/   AVFoundation player, stores, file access
  Presentation/     SwiftUI + AppKit UI
```

---

## License

Snapframe is released under the [MIT License](LICENSE).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
