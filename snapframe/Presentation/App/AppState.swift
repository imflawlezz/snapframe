import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    let player = MPVPlayer()

    var videoURL: URL?
    var cropStore: CropStore?
    var cueStore: CueStore?
    var crop = CropRect.default
    var seekInput = ""
    var jumpMode: JumpMode = .time
    var status = "Drop a video or press ⌘O"
    var lastDirectory: URL? = FileManager.default.homeDirectoryForCurrentUser
    var errorMessage: String?
    var inspectorVisible = true
    var cropOverlayVisible = true
    var cropSizeText = "320"
    var cropOffsetXText = "0"
    var cropOffsetYText = "0"

    var isLoadingVideo = false
    var loadProgressMessage = ""
    var cropsRevision: Int = 0

    private var loadTask: Task<Void, Never>?
    private var didCenterCrop = false
    private var lastScrubPreviewAt: Date = .distantPast

    static let supportedFormats = ["MKV", "MP4", "WebM", "MOV", "AVI", "M4V"]

    var outputFolderURL: URL? { cropStore?.cropsFolder }

    var outputFolderExists: Bool {
        guard let url = outputFolderURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    var timelineMarkers: [TimelineMarker] {
        var markers: [TimelineMarker] = []
        if let cues = cueStore {
            for c in cues.cues {
                let kind: TimelineMarker.Kind
                if c.id == cues.activeID { kind = .cueActive }
                else if c.done { kind = .cueDone }
                else { kind = .cuePending }
                markers.append(TimelineMarker(id: "cue-\(c.id)", t: c.t, kind: kind, cueID: c.id))
            }
        }
        if let crops = cropStore {
            for (i, e) in crops.entries.enumerated() {
                markers.append(TimelineMarker(
                    id: "crop-\(i)-\(e.file)",
                    t: e.timecodeSeconds,
                    kind: .crop,
                    cueID: nil
                ))
            }
        }
        return markers
    }

    var pendingCueCount: Int { cueStore?.pending.count ?? 0 }
    var doneCueCount: Int { cueStore?.cues.filter(\.done).count ?? 0 }
    var hasCues: Bool { !(cueStore?.cues.isEmpty ?? true) }

    var mediaInfoLine: String {
        guard videoURL != nil else { return "" }
        var parts: [String] = []
        let w = Int(player.videoSize.width)
        let h = Int(player.videoSize.height)
        if w > 0, h > 0 { parts.append("\(w)×\(h)") }
        if player.fps > 0 { parts.append(String(format: "%.3f fps", player.fps)) }
        if player.duration > 0 { parts.append(Timecode.format(player.duration)) }
        if player.totalFrames > 0 { parts.append("\(player.totalFrames) frames") }
        if let codec = player.videoCodec, !codec.isEmpty { parts.append(codec.uppercased()) }
        return parts.joined(separator: "  ·  ")
    }

    var positionLabel: String {
        switch jumpMode {
        case .time: return Timecode.format(player.position)
        case .frame: return "\(player.currentFrame)"
        }
    }

    init() {
        if let path = UserDefaults.standard.string(forKey: "lastDirectory"), !path.isEmpty {
            lastDirectory = URL(fileURLWithPath: path)
        }
    }

    func revealOutputFolder() {
        guard let url = outputFolderURL,
              FileManager.default.fileExists(atPath: url.path) else { return }
        NSWorkspace.shared.open(url)
    }

    func setCropInteracting(_ active: Bool) {
        player.setCaptureSuspended(active)
        if !active { syncCropFieldsFromRect() }
    }

    func refreshPreview() {
        guard videoURL != nil, !isLoadingVideo else { return }
        player.setCaptureSuspended(false)
        _ = player.refreshFrame(preferQuality: true)
        syncSeekInputFromPlayer()
        status = "Preview refreshed"
    }

    func openVideo() {
        if let url = FileAccess.openVideoPanel(startURL: lastDirectory ?? videoURL?.deletingLastPathComponent()) {
            loadVideo(url)
        }
    }

    func loadVideo(_ url: URL) {
        loadTask?.cancel()
        player.cancelOpen()

        isLoadingVideo = true
        loadProgressMessage = "Preparing…"
        videoURL = url
        lastDirectory = url.deletingLastPathComponent()
        UserDefaults.standard.set(lastDirectory?.path, forKey: "lastDirectory")

        cropStore = CropStore(videoURL: url)
        cueStore = CueStore(sourceFilename: url.lastPathComponent)
        didCenterCrop = false
        crop = .default
        seekInput = ""
        status = url.lastPathComponent

        loadTask = Task {
            loadProgressMessage = "Opening…"
            player.beginOpen(url: url)

            let ready = await player.waitUntilReady(timeout: 20)
            guard !Task.isCancelled else {
                isLoadingVideo = false
                return
            }

            if !ready {
                isLoadingVideo = false
                errorMessage = player.lastError ?? "Could not open video"
                videoURL = nil
                return
            }

            loadProgressMessage = "Loading cues…"
            await loadSidecarCues(for: url, jumpToFirstPending: false)
            guard !Task.isCancelled else {
                isLoadingVideo = false
                return
            }

            ensureCenteredCrop()
            isLoadingVideo = false
            loadProgressMessage = ""
            syncSeekInputFromPlayer()

            let thumbURL = url
            let jumpToPending = cueStore?.pending.isEmpty == false
            Task { @MainActor in
                await self.captureMidpointThumbnail(for: thumbURL)
                if jumpToPending {
                    self.nextCue()
                }
            }
        }
    }

    func ensureCenteredCrop() {
        let size = player.videoSize
        guard size.width > 0, size.height > 0 else { return }
        if !didCenterCrop {
            crop.center(in: size)
            didCenterCrop = true
        } else {
            crop.clamp(in: size)
        }
        syncCropFieldsFromRect()
    }

    func syncCropFieldsFromRect() {
        cropSizeText = "\(crop.size)"
        let off = crop.centerOffset(in: player.videoSize)
        cropOffsetXText = "\(off.dx)"
        cropOffsetYText = "\(off.dy)"
    }

    func applyCropFields() {
        let vs = player.videoSize
        guard vs.width > 0, vs.height > 0 else { return }
        guard let size = Int(cropSizeText.trimmingCharacters(in: .whitespaces)),
              let dx = Int(cropOffsetXText.trimmingCharacters(in: .whitespaces)),
              let dy = Int(cropOffsetYText.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = "Crop fields must be integers."
            syncCropFieldsFromRect()
            return
        }
        var next = crop
        next.setSize(size, in: vs)
        next.setCenterOffset(dx: dx, dy: dy, in: vs)
        crop = next
        syncCropFieldsFromRect()
    }

    func importCues() {
        guard let videoURL, let cueStore else {
            errorMessage = "Open a video first."
            return
        }
        let suggested = FileAccess.sidecarCuesURL(for: videoURL)
        let start = FileManager.default.fileExists(atPath: suggested.path)
            ? suggested.deletingLastPathComponent()
            : lastDirectory
        guard let url = FileAccess.openCuesPanel(startURL: start) else { return }
        do {
            try cueStore.load(from: url)
            status = "\(cueStore.cues.count) cues · \(cueStore.pending.count) pending"
            if !cueStore.pending.isEmpty { nextCue() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func syncSeekInputFromPlayer() {
        switch jumpMode {
        case .time:
            seekInput = Timecode.format(player.position)
        case .frame:
            seekInput = "\(player.currentFrame)"
        }
    }

    func performSeek() {
        switch jumpMode {
        case .time:
            guard let seconds = Timecode.parse(seekInput) else {
                errorMessage = "Use HH:MM:SS.mmm or seconds."
                return
            }
            seekTo(seconds: seconds, precise: true)
        case .frame:
            guard let frame = Timecode.parseFrame(seekInput) else {
                errorMessage = "Enter a frame number."
                return
            }
            seekTo(seconds: Timecode.seconds(forFrame: frame, fps: player.fps), precise: true)
        }
    }

    func frameStep(_ n: Int) {
        player.frameStep(n)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 160_000_000)
            guard !Task.isCancelled else { return }
            let snapped = snapTimeToCueIfNeeded(player.position)
            if abs(snapped - player.position) > 1e-4 {
                player.seek(seconds: snapped, precise: true)
            }
            if let near = cueStore?.nearest(to: player.position) {
                cueStore?.activeID = near.id
            }
            syncSeekInputFromPlayer()
        }
    }

    func gotoCue(_ id: String) {
        guard let cue = cueStore?.cue(id: id) else { return }
        cueStore?.activeID = id
        player.pause(true)
        player.setScrubMode(false)
        player.seek(seconds: cue.t, precise: true)
        syncSeekInputFromPlayer()
        status = cue.label.isEmpty ? cue.timecode : "\(cue.timecode) — \(cue.label)"
    }

    func nextCue() {
        guard let store = cueStore else { return }
        guard let cue = store.nextPending(after: store.activeID) else {
            status = "No pending cues"
            return
        }
        gotoCue(cue.id)
    }

    func prevCue() {
        guard let store = cueStore else { return }
        guard let cue = store.prevPending(before: store.activeID) else {
            status = "No pending cues"
            return
        }
        gotoCue(cue.id)
    }

    func deleteActiveCue() {
        guard let store = cueStore else { return }
        let id = store.activeID ?? store.cues.first?.id
        guard let id else { return }
        var next: Cue?
        var seen = false
        for c in store.cues {
            if c.id == id { seen = true; continue }
            if seen && !c.done { next = c; break }
        }
        if next == nil {
            next = store.cues.first { $0.id != id && !$0.done }
        }
        do {
            try store.remove(id)
            if let next { gotoCue(next.id) }
            else { status = "Cue deleted" }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func seekCrop(at index: Int) {
        guard let entries = cropStore?.entries, entries.indices.contains(index) else { return }
        let entry = entries[index]
        player.pause(true)
        player.seek(seconds: entry.timecodeSeconds, precise: true)
        crop = CropRect(x: entry.x, y: entry.y, size: entry.size)
        syncCropFieldsFromRect()
        syncSeekInputFromPlayer()
    }

    func deleteCrop(at index: Int) {
        do {
            try cropStore?.remove(at: index)
            cropsRevision &+= 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveCrop() {
        guard cropOverlayVisible else {
            errorMessage = "Enable crop overlay to save."
            return
        }
        guard let cropStore else { return }
        ensureCenteredCrop()

        player.pause(true)
        player.setScrubMode(false)
        // Scrub/preview captures can be stale — re-grab the playhead frame before encode.
        guard player.captureExactFrame(), let cg = player.capturedCGImage else {
            errorMessage = player.lastError ?? "No frame captured yet."
            return
        }

        let prefs = UserPreferences.shared
        do {
            let result = try SaveCropUseCase.execute(
                request: SaveCropRequest(
                    crop: crop,
                    videoSize: player.videoSize,
                    frame: cg,
                    pts: player.capturedPTS ?? player.position,
                    format: prefs.exportFormat,
                    jpegQuality: prefs.jpegQuality,
                    markCueDone: prefs.markCueDoneOnSave,
                    advanceAfterSave: prefs.advanceToNextCueAfterSave
                ),
                crops: cropStore,
                cues: cueStore
            )
            cropsRevision &+= 1

            if let marked = result.markedCue {
                status = "Saved \(result.filename) · cue \(marked.timecode) done"
                if let nextID = result.nextCueID {
                    DispatchQueue.main.async { [weak self] in self?.gotoCue(nextID) }
                }
            } else {
                status = "Saved \(result.filename) @ \(result.entry.timecode)"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func onTimelineSeek(seconds: Double, precise: Bool) {
        player.pause(true)
        if precise {
            let target = snapTimeToCueIfNeeded(seconds)
            player.setScrubMode(false)
            player.seek(seconds: target, precise: true)
            if let near = cueStore?.nearest(to: target, maxDelta: snapToleranceSeconds()) {
                cueStore?.activeID = near.id
            }
            syncSeekInputFromPlayer()
        } else {
            player.setScrubMode(true)
            player.seek(seconds: seconds, precise: false)
            let now = Date()
            if now.timeIntervalSince(lastScrubPreviewAt) >= 0.14 {
                lastScrubPreviewAt = now
                player.refreshScrubPreview()
            }
        }
    }

    private func snapToleranceSeconds() -> Double {
        CueSnapper.toleranceSeconds(
            fps: player.fps,
            frames: UserPreferences.shared.cueSnapToleranceFrames
        )
    }

    private func snapTimeToCueIfNeeded(_ seconds: Double) -> Double {
        CueSnapper.snap(
            seconds,
            cues: cueStore,
            enabled: UserPreferences.shared.snapToCuesOnSeek,
            tolerance: snapToleranceSeconds()
        )
    }

    private func seekTo(seconds: Double, precise: Bool) {
        let target = precise ? snapTimeToCueIfNeeded(seconds) : seconds
        player.pause(true)
        player.setScrubMode(false)
        player.seek(seconds: target, precise: precise)
        if let near = cueStore?.nearest(to: player.position) {
            cueStore?.activeID = near.id
        }
        syncSeekInputFromPlayer()
    }

    private func captureMidpointThumbnail(for url: URL) async {
        let duration = player.duration
        if duration <= 2 {
            RecentVideosStore.shared.record(videoURL: url, preview: player.frameImage)
            return
        }

        let preview = await player.snapshotImage(at: duration * 0.5)
        RecentVideosStore.shared.record(videoURL: url, preview: preview ?? player.frameImage)
        syncSeekInputFromPlayer()
    }

    private func loadSidecarCues(for url: URL, jumpToFirstPending: Bool) async {
        guard UserPreferences.shared.autoImportSidecarCues else { return }
        let sidecar = FileAccess.sidecarCuesURL(for: url)
        guard FileManager.default.fileExists(atPath: sidecar.path) else { return }
        do {
            try cueStore?.load(from: sidecar)
            let pending = cueStore?.pending.count ?? 0
            status = "\(url.lastPathComponent)  ·  \(pending) cues pending"
            if jumpToFirstPending, pending > 0 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                nextCue()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
