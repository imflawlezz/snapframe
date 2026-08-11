# Snapframe

**Snapframe** is a native macOS tool for frame-accurate video scrubbing, cue-based navigation, and square crop export.

Open a video, jump between marked moments, frame a square crop, and save stills next to the source file — without a heavyweight NLE.

| | |
|---|---|
| **Platform** | macOS |
| **Version** | 1.0.0 |
| **License** | [MIT](LICENSE) |
| **Playback** | [libmpv](https://mpv.io) via Homebrew |

---

## Install

### From the DMG

1. Open `Snapframe_1.0.0.dmg`.
2. Drag **Snapframe.app** into **Applications**.
3. Double-click **Dependencies.command** in the DMG.  
   If macOS blocks it: right-click → **Open** → **Open**.
4. Wait until it finishes (installs Homebrew `mpv` / `libmpv` and clears quarantine).
5. Launch **Snapframe** from Applications.

**Requirements:** macOS, internet on first run (Homebrew / mpv). If Homebrew is missing, Dependencies opens [brew.sh](https://brew.sh).

### Manual setup

If you prefer not to use Dependencies.command:

```bash
brew install mpv
xattr -dr com.apple.quarantine /Applications/Snapframe.app
open /Applications/Snapframe.app
```

| Chip | Expected libmpv |
|------|-----------------|
| Apple Silicon | `/opt/homebrew/opt/mpv/lib/libmpv.2.dylib` |
| Intel | `/usr/local/opt/mpv/lib/libmpv.2.dylib` |

Snapframe does **not** bundle mpv. The app loads Homebrew’s library at runtime (App Sandbox is off for that reason).

### Gatekeeper

Downloaded builds are quarantined. Dependencies.command clears this; otherwise use the `xattr` command above, or right-click the app → **Open**.

---

## Features

- Frame-accurate scrubbing and still preview (libmpv)
- Cue list from a sidecar JSON next to the video
- Square crop overlay — drag, resize, scroll to change size
- Export crops as PNG or JPEG into a `{name}_crops/` folder
- Recents with thumbnails
- Light / Dark / System appearance
- Keyboard-first workflow

---

## Usage

1. **Open** a video (⌘O), drop a file onto the window, or pick a recent item.
2. Optionally load cues: auto-import `Movie.cues.json` beside the file, or **Import Cues…** (⌘I).
3. Scrub the timeline; enable snap-to-cue in Preferences if you want magnet seeking.
4. Show the crop overlay (⌘⇧C), place the square, **Save crop** (⌘S).
5. Find exports in `Movie_crops/` next to the source, with `metadata.json`.

### Supported formats

`.mkv` · `.mp4` · `.m4v` · `.mov` · `.webm` · `.avi`  
(and anything else libmpv can demux)

### Cues file

For `Movie.mkv`, Snapframe looks for:

```text
Movie.cues.json
```

| Field | Notes |
|-------|--------|
| `format` | `snapframe-cues` (current) or `mkv-cropper-cues` (legacy) |
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

| Key | Action |
|-----|--------|
| Space | Play / pause |
| ← / → | Seek −1s / +1s |
| ⇧← / ⇧→ | Seek −5s / +5s |
| , / . | Frame −1 / +1 |
| ⇧, / ⇧. | Frame −10 / +10 |
| 1 / 2 / 4 / 8 | Playback speed |
| m | Mute |
| n or ] | Next pending cue |
| p or [ | Previous pending cue |
| Delete | Delete active cue |
| ⌘O | Open video |
| ⌘I | Import cues |
| ⌘S | Save crop |
| ⌘R | Refresh preview |
| ⌘\\ | Toggle inspector |
| ⌘⇧C | Toggle crop overlay |
| ⌘, | Preferences |

---

## Build from source

For development you need **Xcode** and Homebrew **mpv** (`brew install mpv`).

```bash
open snapframe.xcodeproj
```

Select the **Snapframe** scheme and run (Debug or Release).

Project layout:

```text
snapframe/
  Domain/           entities + ports
  Application/      use cases
  Infrastructure/   mpv, stores, file access
  Presentation/     SwiftUI + AppKit UI
```

---

## License

Snapframe is released under the [MIT License](LICENSE).

**mpv** / **libmpv** are separate projects (typically GPL) and are not included in this repository. Install them yourself via Homebrew.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
