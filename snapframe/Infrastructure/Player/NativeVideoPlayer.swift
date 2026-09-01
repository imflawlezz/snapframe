import AppKit
import AVFoundation
import CoreGraphics
import Foundation
import Observation

@Observable
@MainActor
final class NativeVideoPlayer {
    private(set) var frameImage: NSImage?
    private(set) var position: Double = 0
    private(set) var duration: Double = 0
    private(set) var videoSize: CGSize = .zero
    private(set) var isPaused: Bool = true
    private(set) var isMuted: Bool = false
    private(set) var volume: Double = 100
    private(set) var speed: Double = 1
    private(set) var lastError: String?
    private(set) var isSyncingFrame = false

    private(set) var capturedCGImage: CGImage?
    private(set) var capturedPTS: Double?
    private(set) var displayFrame: Int = 0

    let avPlayer = AVPlayer()

    var fps: Double { fpsValue > 0 ? fpsValue : 30 }
    var currentFrame: Int {
        if isPaused, frameImage != nil { return displayFrame }
        return Timecode.frameIndex(at: position, fps: fps)
    }
    var totalFrames: Int { duration > 0 ? Timecode.frameIndex(at: duration, fps: fps) : 0 }

    var exactFrameSeconds: Double {
        Timecode.seconds(forFrame: currentFrame, fps: fps)
    }

    var savedFrameSeconds: Double {
        Timecode.seconds(forFrame: displayFrame, fps: fps)
    }

    var videoCodec: String? { videoCodecName }

    private var asset: AVURLAsset?
    private var imageGenerator: AVAssetImageGenerator?
    private var timeObserver: Any?
    private var openToken: UInt64 = 0
    private var syncToken: UInt64 = 0
    private var preciseSeekTask: Task<Bool, Never>?
    private var fpsValue: Double = 30
    private var videoCodecName: String?
    private var endObserver: NSObjectProtocol?
    private var isScrubbing = false

    init() {
        avPlayer.actionAtItemEnd = .pause
        avPlayer.automaticallyWaitsToMinimizeStalling = false
        avPlayer.volume = Float(UserPreferences.shared.volume / 100)
        volume = UserPreferences.shared.volume
        installTimeObserver()
    }

    func beginOpen(url: URL) {
        openToken &+= 1
        let token = openToken
        lastError = nil
        isPaused = true
        isSyncingFrame = false
        frameImage = nil
        capturedCGImage = nil
        capturedPTS = nil
        displayFrame = 0
        position = 0
        duration = 0
        videoSize = .zero
        videoCodecName = nil

        avPlayer.pause()
        avPlayer.replaceCurrentItem(with: nil)
        asset = nil
        imageGenerator = nil

        let asset = AVURLAsset(url: url)
        self.asset = asset

        Task {
            await loadAsset(asset, token: token)
        }
    }

    func waitUntilReady(timeout: TimeInterval = 20) async -> Bool {
        let token = openToken
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if Task.isCancelled || token != openToken { return false }
            if videoSize.width > 0,
               avPlayer.currentItem?.status == .readyToPlay {
                return true
            }
            if lastError != nil, token == openToken { return false }
            try? await Task.sleep(nanoseconds: 30_000_000)
        }
        lastError = lastError ?? "Timed out opening video"
        return false
    }

    func cancelOpen() {
        openToken &+= 1
    }

    func closeMedia() {
        openToken &+= 1
        syncToken &+= 1
        preciseSeekTask?.cancel()
        preciseSeekTask = nil
        isSyncingFrame = false
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        avPlayer.pause()
        avPlayer.replaceCurrentItem(with: nil)
        asset = nil
        imageGenerator = nil
        frameImage = nil
        capturedCGImage = nil
        capturedPTS = nil
        displayFrame = 0
        position = 0
        duration = 0
        videoSize = .zero
        videoCodecName = nil
        isPaused = true
        lastError = nil
    }

    func togglePause() { pause(!isPaused) }

    func pause(_ value: Bool) {
        if value {
            avPlayer.pause()
            isPaused = true
        } else {
            avPlayer.isMuted = isMuted
            avPlayer.volume = Float(volume / 100)
            applyPlaybackRate(speed)
            isPaused = false
        }
    }

    func setVolume(_ value: Double) {
        volume = min(100, max(0, value))
        avPlayer.volume = Float(volume / 100)
    }

    func commitVolume() {
        UserPreferences.shared.volume = volume
    }

    func setMuted(_ value: Bool) {
        isMuted = value
        avPlayer.isMuted = value
    }

    func toggleMute() { setMuted(!isMuted) }

    func setSpeed(_ value: Double) {
        speed = min(2, max(0.5, value))
        refreshTimeObserverInterval()
        if !isPaused {
            applyPlaybackRate(speed)
        }
    }

    func setScrubMode(_ enabled: Bool) {
        isScrubbing = enabled
    }

    func seek(seconds: Double, precise: Bool) {
        guard avPlayer.currentItem != nil else { return }
        if precise {
            Task { await seekPrecise(to: seconds) }
            return
        }

        let t = clampedTime(seconds)
        position = t
        let time = CMTime(seconds: t, preferredTimescale: 60_000)
        let frameDur = 1 / max(fps, 24)
        let tol = CMTime(seconds: frameDur * 2, preferredTimescale: 60_000)
        avPlayer.currentItem?.cancelPendingSeeks()
        avPlayer.seek(to: time, toleranceBefore: tol, toleranceAfter: tol)
    }

    func waitForSeekIdle() async {
        if let task = preciseSeekTask {
            _ = await task.value
        }
    }

    @discardableResult
    func seekPrecise(to seconds: Double) async -> Bool {
        guard avPlayer.currentItem != nil else {
            lastError = "No video loaded"
            return false
        }

        syncToken &+= 1
        let token = syncToken

        let task = Task { @MainActor in
            await self.runPreciseSeek(to: seconds, token: token)
        }
        preciseSeekTask = task
        return await task.value
    }

    @discardableResult
    func syncExactFrame(at seconds: Double? = nil) async -> Bool {
        await seekPrecise(to: seconds ?? position)
    }

    @discardableResult
    func captureExactFrame() async -> Bool {
        await waitForSeekIdle()
        guard avPlayer.currentItem != nil else {
            lastError = "No video loaded"
            return false
        }
        let frame = activeFrameIndex()
        return await seekPrecise(to: Timecode.seconds(forFrame: frame, fps: fps))
    }

    @discardableResult
    func refreshFrame() async -> Bool {
        await captureExactFrame()
    }

    private func activeFrameIndex() -> Int {
        if isPaused, frameImage != nil { return displayFrame }
        return Timecode.frameIndex(at: position, fps: fps)
    }

    func frameStep(_ n: Int) {
        guard n != 0 else { return }
        pause(true)
        setScrubMode(false)

        let maxFrame = max(0, totalFrames - 1)
        let targetFrame = max(0, min(maxFrame, currentFrame + n))
        let target = Timecode.seconds(forFrame: targetFrame, fps: fps)
        seek(seconds: target, precise: true)
    }

    private func clampedTime(_ seconds: Double) -> Double {
        var t = max(0, seconds)
        if fps > 0 {
            t = Timecode.snapped(seconds: t, fps: fps, duration: duration)
        } else if duration > 0 {
            t = min(t, max(0, duration - 0.001))
        }
        return t
    }

    func snapshotImage(at seconds: Double) async -> NSImage? {
        guard let generator = makeExportGenerator() else { return nil }
        var t = max(0, seconds)
        if duration > 0 { t = min(t, max(0, duration - 0.001)) }
        let time = CMTime(seconds: t, preferredTimescale: 600)
        return await withCheckedContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { cg, _, _ in
                if let cg {
                    let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                    continuation.resume(returning: img)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadAsset(_ asset: AVURLAsset, token: UInt64) async {
        do {
            let playable = try await asset.load(.isPlayable)
            guard token == openToken else { return }
            guard playable else {
                lastError = "Unsupported format. Open an MP4, MOV, or M4V file."
                return
            }

            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard token == openToken else { return }
            guard let track = tracks.first else {
                lastError = "No video track found."
                return
            }

            let naturalSize = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let transformed = naturalSize.applying(transform)
            let size = CGSize(width: abs(transformed.width), height: abs(transformed.height))

            let nominalFPS = try await track.load(.nominalFrameRate)
            let loadedDuration = try await asset.load(.duration)
            let dur = loadedDuration.seconds
            let codec = await codecName(for: track)

            guard token == openToken else { return }

            videoSize = size
            duration = dur.isFinite && dur > 0 ? dur : 0
            fpsValue = nominalFPS > 0 ? Double(nominalFPS) : 30
            videoCodecName = codec

            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            imageGenerator = generator

            let item = AVPlayerItem(asset: asset)
            item.audioTimePitchAlgorithm = .spectral
            item.preferredForwardBufferDuration = 2
            avPlayer.replaceCurrentItem(with: item)
            avPlayer.pause()
            isPaused = true

            observeEnd(of: item)

            _ = await seekPrecise(to: 0)
        } catch {
            guard token == openToken else { return }
            lastError = error.localizedDescription
        }
    }

    private func makeExportGenerator() -> AVAssetImageGenerator? {
        guard let asset else { return nil }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        return generator
    }

    private func runPreciseSeek(to seconds: Double, token: UInt64) async -> Bool {
        isSyncingFrame = true
        defer {
            if token == syncToken {
                isSyncingFrame = false
            }
        }

        let target = clampedTime(seconds)

        let time = CMTime(seconds: target, preferredTimescale: 60_000)
        let finished = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            avPlayer.currentItem?.cancelPendingSeeks()
            avPlayer.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { ok in
                continuation.resume(returning: ok)
            }
        }

        guard token == syncToken, finished, !Task.isCancelled else { return false }
        let frame = Timecode.frameIndex(at: target, fps: fps)
        return applyExactFrame(frame: frame, updatePreview: true, token: token)
    }

    @discardableResult
    private func applyExactFrame(frame: Int, updatePreview: Bool, token: UInt64) -> Bool {
        guard token == syncToken else { return false }

        let maxFrame = totalFrames > 0 ? max(0, totalFrames - 1) : frame
        let clampedFrame = min(max(0, frame), maxFrame)
        let pinned = Timecode.seconds(forFrame: clampedFrame, fps: fps)

        guard captureFrame(at: pinned, updatePreview: updatePreview) else { return false }

        displayFrame = clampedFrame
        position = pinned
        capturedPTS = pinned

        let time = CMTime(seconds: pinned, preferredTimescale: 60_000)
        avPlayer.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { _ in }
        return true
    }

    @discardableResult
    private func captureFrame(at seconds: Double, updatePreview: Bool) -> Bool {
        guard let generator = imageGenerator else {
            lastError = "No video loaded"
            return false
        }
        var t = max(0, seconds)
        if fps > 0 {
            t = Timecode.snapped(seconds: t, fps: fps, duration: duration)
        } else if duration > 0 {
            t = min(t, max(0, duration - 0.001))
        }
        let time = CMTime(seconds: t, preferredTimescale: 60_000)

        do {
            var actualTime = CMTime.zero
            let cg = try generator.copyCGImage(at: time, actualTime: &actualTime)
            capturedCGImage = cg
            capturedPTS = actualTime.seconds.isFinite ? actualTime.seconds : t
            lastError = nil
            if updatePreview {
                frameImage = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            }
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func codecName(for track: AVAssetTrack) async -> String? {
        guard let formatDescriptions = try? await track.load(.formatDescriptions),
              let desc = formatDescriptions.first else { return nil }
        let codec = CMFormatDescriptionGetMediaSubType(desc)
        return fourCCString(codec)
    }

    private func fourCCString(_ code: FourCharCode) -> String {
        let chars: [UInt8] = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF),
        ]
        return String(bytes: chars, encoding: .macOSRoman) ?? "VIDEO"
    }

    private func installTimeObserver() {
        refreshTimeObserverInterval()
    }

    private func refreshTimeObserverInterval() {
        if let timeObserver {
            avPlayer.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        let hz = min(max(fpsValue, 24), 60)
        let interval = CMTime(seconds: 1 / hz, preferredTimescale: 60_000)
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self, !self.isPaused, !self.isScrubbing else { return }
                self.position = max(0, time.seconds)
            }
        }
    }

    private func applyPlaybackRate(_ rate: Double) {
        guard avPlayer.currentItem != nil else { return }
        let target = Float(rate)
        avPlayer.playImmediately(atRate: target)
    }

    private func observeEnd(of item: AVPlayerItem) {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pause(true)
            }
        }
    }
}
