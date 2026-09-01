import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    let player = NativeVideoPlayer()

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
    var cropOverlayVisible = false
    var cropScissorsMode = false
    var cropFrameChromeVisible = false
    var cropScissorsChromeVisible = false
    var cropSquareLocked = false
    var cropRatioLocked = false
    var cropLockedRatioW = 16
    var cropLockedRatioH = 9
    var cropWidthText = "320"
    var cropResizeLock: CropResizeLock {
        if cropSquareLocked { return .square }
        if cropRatioLocked {
            return .ratio(width: max(1, cropLockedRatioW), height: max(1, cropLockedRatioH))
        }
        return .free
    }

    var cropHeightText = "320"
    var cropOffsetXText = "0"
    var cropOffsetYText = "0"
    var followPlayhead = true

    var isLoadingVideo = false
    var loadProgressMessage = ""

    var isOpeningVideo: Bool { isLoadingVideo && videoURL == nil }
    var cropsRevision: Int = 0
    private var pinnedCueID: String?
    private var pinnedCropIndex: Int?

    private var loadTask: Task<Void, Never>?
    private var cropTransitionTask: Task<Void, Never>?
    private var didCenterCrop = false

    static let supportedFormats = ["MP4", "MOV", "M4V"]

    var outputFolderURL: URL? { cropStore?.cropsFolder }

    var outputFolderExists: Bool {
        guard let url = outputFolderURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    var timelineMarkers: [TimelineMarker] {
        var markers: [TimelineMarker] = []
        let highlightedCue = highlightedCueID
        let highlightedCrop = highlightedCropIndex
        if let cues = cueStore {
            for c in cues.cues {
                let kind: TimelineMarker.Kind
                if c.id == highlightedCue { kind = .cueActive }
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
                    kind: i == highlightedCrop ? .cropActive : .crop,
                    cropIndex: i
                ))
            }
        }
        return markers
    }

    var highlightedCueID: String? {
        guard let cues = cueStore?.cues else { return nil }
        if let id = pinnedCueID, let cue = cues.first(where: { $0.id == id }), isAtPlayhead(cue.t) {
            return id
        }
        return cues.first { isAtPlayhead($0.t) }?.id
    }

    var highlightedCropIndex: Int? {
        guard let entries = cropStore?.entries else { return nil }
        if let pinned = pinnedCropIndex,
           entries.indices.contains(pinned),
           isAtPlayhead(entries[pinned].timecodeSeconds) {
            return pinned
        }
        return entries.indices.last { isAtPlayhead(entries[$0].timecodeSeconds) }
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
        if !active { syncCropFieldsFromRect() }
    }

    func refreshPreview() {
        guard videoURL != nil, !isLoadingVideo else { return }
        Task {
            guard await player.refreshFrame() else { return }
            syncSeekInputFromPlayer()
            status = "Preview refreshed"
        }
    }

    func openVideo() {
        if let url = FileAccess.openVideoPanel(startURL: lastDirectory ?? videoURL?.deletingLastPathComponent()) {
            loadVideo(url)
        }
    }

    func closeVideo() {
        loadTask?.cancel()
        loadTask = nil
        player.closeMedia()
        isLoadingVideo = false
        loadProgressMessage = ""
        videoURL = nil
        cropStore = nil
        cueStore = nil
        crop = .default
        cancelCropTransition()
        cropScissorsMode = false
        cropFrameChromeVisible = false
        cropScissorsChromeVisible = false
        seekInput = ""
        pinnedCueID = nil
        pinnedCropIndex = nil
        didCenterCrop = false
        status = "Drop a video or press ⌘O"
        errorMessage = nil
    }

    func loadVideo(_ url: URL) {
        loadTask?.cancel()
        player.cancelOpen()

        let openingFresh = videoURL == nil
        isLoadingVideo = true
        loadProgressMessage = "Preparing…"
        lastDirectory = url.deletingLastPathComponent()
        UserDefaults.standard.set(lastDirectory?.path, forKey: "lastDirectory")

        if !openingFresh {
            videoURL = url
            cropStore = CropStore(videoURL: url)
            cueStore = CueStore(sourceFilename: url.lastPathComponent)
            didCenterCrop = false
            crop = .default
            seekInput = ""
            pinnedCueID = nil
            pinnedCropIndex = nil
            status = url.lastPathComponent
        }

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
                if openingFresh {
                    videoURL = nil
                }
                return
            }

            if openingFresh {
                cropStore = CropStore(videoURL: url)
                cueStore = CueStore(sourceFilename: url.lastPathComponent)
                didCenterCrop = false
                crop = .default
                seekInput = ""
                pinnedCueID = nil
                pinnedCropIndex = nil
            }

            loadProgressMessage = "Loading cues…"
            await loadSidecarCues(for: url, jumpToFirstPending: false)
            guard !Task.isCancelled else {
                isLoadingVideo = false
                return
            }

            ensureCenteredCrop()
            _ = await player.refreshFrame()

            if openingFresh {
                isLoadingVideo = false
                videoURL = url
                status = url.lastPathComponent
            } else {
                isLoadingVideo = false
            }
            loadProgressMessage = ""
            syncSeekInputFromPlayer()
            restoreCropChromeIfNeeded()

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
            let w = max(1, crop.width)
            let h = max(1, crop.height)
            var a = w, b = h
            while b != 0 { (a, b) = (b, a % b) }
            let g = max(a, 1)
            cropLockedRatioW = w / g
            cropLockedRatioH = h / g
            didCenterCrop = true
        } else {
            crop.clamp(in: size)
        }
        syncCropFieldsFromRect()
    }

    func syncCropFieldsFromRect() {
        cropWidthText = "\(crop.width)"
        cropHeightText = "\(crop.height)"
        let off = crop.centerOffset(in: player.videoSize)
        cropOffsetXText = "\(off.dx)"
        cropOffsetYText = "\(off.dy)"
    }

    func applyCropFields() {
        let vs = player.videoSize
        guard vs.width > 0, vs.height > 0 else { return }
        guard let width = Int(cropWidthText.trimmingCharacters(in: .whitespaces)),
              let height = Int(cropHeightText.trimmingCharacters(in: .whitespaces)),
              let dx = Int(cropOffsetXText.trimmingCharacters(in: .whitespaces)),
              let dy = Int(cropOffsetYText.trimmingCharacters(in: .whitespaces)) else {
            errorMessage = "Crop fields must be integers."
            syncCropFieldsFromRect()
            return
        }
        var next = crop
        let lock = cropResizeLock
        let wChanged = width != crop.width
        let hChanged = height != crop.height
        if lock != .free {
            if hChanged && !wChanged {
                next.setHeight(height, in: vs, lock: lock)
            } else {
                next.setWidth(width, in: vs, lock: lock)
            }
        } else {
            next.setWidth(width, in: vs, lock: .free)
            next.setHeight(height, in: vs, lock: .free)
        }
        next.setCenterOffset(dx: dx, dy: dy, in: vs)
        crop = next
        syncCropFieldsFromRect()
    }

    func toggleCropOverlay() {
        cancelCropTransition()
        if cropOverlayVisible {
            cropFrameChromeVisible = false
            cropOverlayVisible = false
        } else {
            cropScissorsChromeVisible = false
            cropScissorsMode = false
            cropFrameChromeVisible = false
            cropOverlayVisible = true
            scheduleFrameChrome(afterToolbar: true)
        }
    }

    func toggleCropScissors() {
        cancelCropTransition()
        if cropScissorsMode || cropScissorsChromeVisible {
            cropScissorsChromeVisible = false
            cropScissorsMode = false
        } else {
            cropFrameChromeVisible = false
            if cropOverlayVisible {
                cropOverlayVisible = false
                scheduleScissorsChrome(afterToolbarHide: true)
            } else {
                scheduleScissorsChrome(afterToolbarHide: false)
            }
        }
    }

    func dismissCropScissors() {
        cancelCropTransition()
        cropScissorsChromeVisible = false
        cropScissorsMode = false
    }

    private func cancelCropTransition() {
        cropTransitionTask?.cancel()
        cropTransitionTask = nil
    }

    private func scheduleFrameChrome(afterToolbar: Bool) {
        guard afterToolbar else {
            cropFrameChromeVisible = true
            return
        }
        cropTransitionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: SnapMotion.cropBarDelayNs)
            guard !Task.isCancelled else { return }
            cropFrameChromeVisible = true
        }
    }

    private func scheduleScissorsChrome(afterToolbarHide: Bool) {
        guard afterToolbarHide else {
            cropScissorsMode = true
            cropScissorsChromeVisible = true
            return
        }
        cropTransitionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: SnapMotion.cropBarDelayNs)
            guard !Task.isCancelled else { return }
            cropScissorsMode = true
            cropScissorsChromeVisible = true
        }
    }

    private func restoreCropChromeIfNeeded() {
        cancelCropTransition()
        if cropOverlayVisible {
            scheduleFrameChrome(afterToolbar: false)
        } else if cropScissorsMode {
            scheduleScissorsChrome(afterToolbarHide: false)
        }
    }

    func toggleCropRatioLock() {
        cropRatioLocked.toggle()
        if cropRatioLocked {
            cropSquareLocked = false
            let w = max(1, crop.width)
            let h = max(1, crop.height)
            var a = w, b = h
            while b != 0 { (a, b) = (b, a % b) }
            let g = max(a, 1)
            cropLockedRatioW = w / g
            cropLockedRatioH = h / g
        }
    }

    func toggleCropSquareLock() {
        cropSquareLocked.toggle()
        if cropSquareLocked {
            cropRatioLocked = false
            var next = crop
            let side = max(16, min(next.width, next.height))
            next.setWidth(side, in: player.videoSize, lock: .square)
            crop = next
            syncCropFieldsFromRect()
        }
    }

    func displayTime(_ seconds: Double) -> String {
        Timecode.display(seconds: seconds, mode: jumpMode, fps: player.fps)
    }

    func addCueAtPlayhead() {
        guard let videoURL, let cueStore else {
            errorMessage = "Open a video first."
            return
        }
        cueStore.bindFileURL(FileAccess.sidecarCuesURL(for: videoURL))
        Task {
            await player.waitForSeekIdle()
            guard await player.captureExactFrame() else {
                errorMessage = player.lastError ?? "No frame captured yet."
                return
            }
            let t = player.savedFrameSeconds
            let frameWindow = player.fps > 0 ? (1 / player.fps) : 0.04
            if let near = cueStore.nearest(to: t, maxDelta: frameWindow) {
                pinnedCueID = near.id
                status = "Cue already here"
                return
            }
            do {
                let cue = try cueStore.add(at: t)
                pinnedCueID = cue.id
                status = "Cue \(displayTime(cue.t))"
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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
                errorMessage = "Use HH:MM:SS.mmm, MM:SS, seconds, or compact digits (1234 → 12:34)."
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
        Task {
            await player.waitForSeekIdle()
            syncSeekInputFromPlayer()
        }
    }

    func seekStep(seconds delta: Double) {
        guard player.duration > 0 else { return }
        let target = min(max(0, player.position + delta), max(0, player.duration - 0.001))
        seekTo(seconds: target, precise: true)
    }

    func goToStart() {
        guard videoURL != nil, !isLoadingVideo else { return }
        seekTo(seconds: 0, precise: true)
    }

    func toggleSnapToCues() {
        UserPreferences.shared.snapToCues.toggle()
    }

    func snappedSeekTime(_ seconds: Double) -> Double {
        guard UserPreferences.shared.snapToCues else { return seconds }
        let tol = cueSnapWindow
        guard let near = cueStore?.nearest(to: seconds, maxDelta: tol) else { return seconds }
        return near.t
    }

    func gotoCue(_ id: String) {
        guard let cue = cueStore?.cue(id: id) else { return }
        pinnedCueID = id
        player.pause(true)
        player.setScrubMode(false)
        Task {
            guard await player.seekPrecise(to: cue.t) else { return }
            syncSeekInputFromPlayer()
            status = cue.label.isEmpty ? displayTime(cue.t) : "\(displayTime(cue.t)) — \(cue.label)"
        }
    }

    func nextCue() {
        guard let store = cueStore else { return }
        let frame = Timecode.frameIndex(at: player.position, fps: player.fps)
        let next = store.pending.first { Timecode.frameIndex(at: $0.t, fps: player.fps) > frame }
            ?? store.pending.first
        guard let next else {
            status = "No pending cues"
            return
        }
        gotoCue(next.id)
    }

    func prevCue() {
        guard let store = cueStore else { return }
        let frame = Timecode.frameIndex(at: player.position, fps: player.fps)
        let prev = store.pending.last { Timecode.frameIndex(at: $0.t, fps: player.fps) < frame }
            ?? store.pending.last
        guard let prev else {
            status = "No pending cues"
            return
        }
        gotoCue(prev.id)
    }

    func deleteActiveCue() {
        guard let id = highlightedCueID else { return }
        deleteCue(id)
    }

    func deleteCue(_ id: String) {
        guard let store = cueStore else { return }
        do {
            try store.remove(id)
            if pinnedCueID == id { pinnedCueID = nil }
            status = "Cue deleted"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleCueDone(_ id: String) {
        guard let cue = cueStore?.cue(id: id) else { return }
        do {
            try cueStore?.setDone(id, done: !cue.done)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateCueLabel(_ id: String, label: String) {
        do {
            try cueStore?.updateLabel(id, label: label)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateCueTime(_ id: String, text: String) {
        let seconds: Double?
        switch jumpMode {
        case .time:
            seconds = Timecode.parse(text)
        case .frame:
            guard let frame = Timecode.parseFrame(text) else {
                seconds = nil
                break
            }
            seconds = Timecode.seconds(forFrame: frame, fps: player.fps)
        }
        guard let seconds else {
            errorMessage = jumpMode == .time
                ? "Use HH:MM:SS.mmm, MM:SS, seconds, or compact digits (1234 → 12:34)."
                : "Enter a frame number."
            return
        }
        let clamped = min(max(0, seconds), max(0, player.duration - 0.001))
        do {
            try cueStore?.updateTime(id, seconds: clamped)
            gotoCue(id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func seekCrop(at index: Int) {
        guard let entries = cropStore?.entries, entries.indices.contains(index) else { return }
        let entry = entries[index]
        pinnedCropIndex = index
        player.pause(true)
        player.setScrubMode(false)
        Task {
            guard await player.seekPrecise(to: entry.timecodeSeconds) else { return }
            crop = CropRect(x: entry.x, y: entry.y, width: entry.width, height: entry.height)
            syncCropFieldsFromRect()
            syncSeekInputFromPlayer()
        }
    }

    func revealCrop(at index: Int) {
        guard let store = cropStore,
              store.entries.indices.contains(index) else { return }
        let url = store.cropsFolder.appendingPathComponent(store.entries[index].file)
        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "Crop file not found."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func deleteCrop(at index: Int) {
        do {
            try cropStore?.remove(at: index)
            cropsRevision &+= 1
            if let pinned = pinnedCropIndex {
                if index == pinned {
                    pinnedCropIndex = nextPinnedCropIndex(afterDeleting: index)
                } else if index < pinned {
                    pinnedCropIndex = pinned - 1
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteActiveCrop() {
        guard let index = highlightedCropIndex else { return }
        deleteCrop(at: index)
    }

    private func nextPinnedCropIndex(afterDeleting index: Int) -> Int? {
        guard let entries = cropStore?.entries, !entries.isEmpty else { return nil }
        if entries.indices.contains(index), isAtPlayhead(entries[index].timecodeSeconds) {
            return index
        }
        let previous = index - 1
        if entries.indices.contains(previous), isAtPlayhead(entries[previous].timecodeSeconds) {
            return previous
        }
        return entries.indices.last { isAtPlayhead(entries[$0].timecodeSeconds) }
    }

    func saveCrop() {
        guard cropOverlayVisible || cropScissorsMode else {
            errorMessage = "Enable Frame Crop or Scissors to save."
            return
        }
        guard let cropStore else { return }
        ensureCenteredCrop()

        player.pause(true)
        player.setScrubMode(false)

        Task {
            await player.waitForSeekIdle()
            guard await player.captureExactFrame(), let cg = player.capturedCGImage else {
                errorMessage = player.lastError ?? "No frame captured yet."
                return
            }

            let prefs = UserPreferences.shared
            let pts = player.savedFrameSeconds
            do {
                let result = try SaveCropUseCase.execute(
                    request: SaveCropRequest(
                        crop: crop,
                        videoSize: player.videoSize,
                        frame: cg,
                        pts: pts,
                        fps: player.fps,
                        format: prefs.exportFormat,
                        jpegQuality: prefs.jpegQuality,
                        markCueDone: prefs.markCueDoneOnSave,
                        advanceAfterSave: prefs.advanceToNextCueAfterSave,
                        cueMatchWindow: frameMatchWindow
                    ),
                    crops: cropStore,
                    cues: cueStore,
                    imageEncoder: FrameImageEncoder()
                )
                cropsRevision &+= 1
                pinnedCropIndex = cropStore.entries.indices.last

                if let marked = result.markedCue {
                    status = "Saved \(result.filename) · cue \(displayTime(marked.t)) done"
                    if let nextID = result.nextCueID {
                        gotoCue(nextID)
                    }
                } else {
                    status = "Saved \(result.filename) @ \(displayTime(result.entry.timecodeSeconds))"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func onTimelineSeek(seconds: Double, precise: Bool) {
        let t = snappedSeekTime(seconds)
        if precise {
            player.setScrubMode(false)
            player.pause(true)
            player.seek(seconds: t, precise: true)
            Task {
                await player.waitForSeekIdle()
                syncSeekInputFromPlayer()
            }
        } else {
            if !player.isPaused {
                player.pause(true)
            }
            player.setScrubMode(true)
            player.seek(seconds: t, precise: false)
        }
    }

    private func seekTo(seconds: Double, precise: Bool) {
        player.pause(true)
        player.setScrubMode(false)
        player.seek(seconds: seconds, precise: precise)
        if precise {
            Task {
                await player.waitForSeekIdle()
                syncSeekInputFromPlayer()
            }
        } else {
            syncSeekInputFromPlayer()
        }
    }

    private func isAtPlayhead(_ seconds: Double) -> Bool {
        Timecode.frameIndex(at: seconds, fps: player.fps) == player.currentFrame
    }

    private var frameMatchWindow: Double {
        0.51 / max(player.fps, 1)
    }

    private var cueSnapWindow: Double {
        let prefs = UserPreferences.shared
        switch jumpMode {
        case .time:
            return prefs.cueSnapToleranceSeconds
        case .frame:
            return Double(prefs.cueSnapToleranceFrames) / max(player.fps, 1)
        }
    }

    private func captureMidpointThumbnail(for url: URL) async {
        let duration = player.duration
        let mediaInfo = recentMediaInfo()
        if duration <= 2 {
            RecentVideosStore.shared.record(videoURL: url, preview: player.frameImage, mediaInfo: mediaInfo)
            return
        }

        let preview = await player.snapshotImage(at: duration * 0.5)
        RecentVideosStore.shared.record(
            videoURL: url,
            preview: preview ?? player.frameImage,
            mediaInfo: mediaInfo
        )
        syncSeekInputFromPlayer()
    }

    private func recentMediaInfo() -> RecentVideoMediaInfo? {
        let w = Int(player.videoSize.width)
        let h = Int(player.videoSize.height)
        guard w > 0, h > 0 else { return nil }
        return RecentVideoMediaInfo(
            width: w,
            height: h,
            fps: player.fps,
            duration: player.duration,
            codec: player.videoCodec
        )
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
