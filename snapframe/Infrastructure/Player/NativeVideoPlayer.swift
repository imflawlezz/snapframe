import AppKit
import AVFoundation
import CoreGraphics
import Foundation
import Observation

@Observable
@MainActor
final class NativeVideoPlayer: VideoPlaying {
    private(set) var frameImage: NSImage?
    private(set) var position: Double = 0
    private(set) var duration: Double = 0
    private(set) var videoSize: CGSize = .zero
    private(set) var isPaused: Bool = true
    private(set) var isMuted: Bool = false
    private(set) var volume: Double = 100
    private(set) var speed: Double = 1
    private(set) var statusText: String = "Drop a video to start"
    private(set) var lastError: String?

    private(set) var capturedCGImage: CGImage?
    private(set) var capturedPTS: Double?
    private(set) var holdsFramePreview = false
    private(set) var displayEpoch: UInt64 = 0

    let avPlayer = AVPlayer()

    var fps: Double { fpsValue > 0 ? fpsValue : 30 }
    var currentFrame: Int { Timecode.frameIndex(at: position, fps: fps) }
    var totalFrames: Int { duration > 0 ? Timecode.frameIndex(at: duration, fps: fps) : 0 }

    var videoCodec: String? { videoCodecName }

    private var asset: AVURLAsset?
    private var imageGenerator: AVAssetImageGenerator?
    private var timeObserver: Any?
    private var openToken: UInt64 = 0
    private var fpsValue: Double = 30
    private var videoCodecName: String?
    private var hasCapture = false
    private var endObserver: NSObjectProtocol?

    init() {
        avPlayer.actionAtItemEnd = .pause
        avPlayer.automaticallyWaitsToMinimizeStalling = false
        avPlayer.volume = Float(UserPreferences.shared.volume / 100)
        volume = UserPreferences.shared.volume
        installTimeObserver()
    }

    func shutdown() {
        if let timeObserver {
            avPlayer.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        cancelOpen()
        avPlayer.pause()
        avPlayer.replaceCurrentItem(with: nil)
    }

    func beginOpen(url: URL) {
        openToken &+= 1
        let token = openToken
        lastError = nil
        statusText = url.lastPathComponent
        isPaused = true
        frameImage = nil
        capturedCGImage = nil
        capturedPTS = nil
        hasCapture = false
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
            if let err = lastError, token == openToken { return false }
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
        hasCapture = false
        position = 0
        duration = 0
        videoSize = .zero
        videoCodecName = nil
        isPaused = true
        holdsFramePreview = false
        statusText = "Drop a video to start"
        lastError = nil
        displayEpoch &+= 1
    }

    func togglePause() { pause(!isPaused) }

    func pause(_ value: Bool) {
        if value {
            avPlayer.pause()
            isPaused = true
        } else {
            holdsFramePreview = false
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

    func setScrubMode(_ enabled: Bool) {}

    func setCaptureSuspended(_ suspended: Bool) {}

    func setPlaybackCaptureSuppressed(_ suspended: Bool) {}

    func applyPlaybackPreferences() {}

    func seek(seconds: Double, precise: Bool) {
        guard avPlayer.currentItem != nil else { return }
        var t = max(0, seconds)
        if duration > 0 { t = min(t, max(0, duration - 0.001)) }
        position = t

        let time = CMTime(seconds: t, preferredTimescale: 600)
        if precise {
            avPlayer.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                guard finished else { return }
                Task { @MainActor in
                    self?.syncPositionFromPlayer()
                }
            }
        } else {
            avPlayer.seek(to: time)
        }
    }

    func refreshScrubPreview() {}

    @discardableResult
    func captureExactFrame() -> Bool {
        captureFrame(at: position, updatePreview: false)
    }

    @discardableResult
    func refreshFrame(preferQuality: Bool = true) -> Bool {
        captureFrame(at: position, updatePreview: true)
    }

    func frameStep(_ n: Int) {
        guard n != 0, let item = avPlayer.currentItem else { return }
        pause(true)
        holdsFramePreview = false

        if n > 0, item.canStepForward {
            item.step(byCount: n)
            syncPositionFromPlayer()
            return
        }
        if n < 0, item.canStepBackward {
            item.step(byCount: n)
            syncPositionFromPlayer()
            return
        }

        let maxFrame = max(0, totalFrames - 1)
        let targetFrame = max(0, min(maxFrame, currentFrame + n))
        let target = Timecode.seconds(forFrame: targetFrame, fps: fps)
        seek(seconds: target, precise: true)
    }

    func snapshotImage(at seconds: Double) async -> NSImage? {
        guard let generator = makeExportGenerator() else { return nil }
        var t = max(0, seconds)
        if duration > 0 { t = min(t, max(0, duration - 0.001)) }
        let time = CMTime(seconds: t, preferredTimescale: 600)
        return await withCheckedContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { cg, _, error in
                if let cg {
                    let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                    continuation.resume(returning: img)
                } else {
                    continuation.resume(returning: nil)
                }
                if error != nil { /* thumbnail best-effort */ }
            }
        }
    }

    // MARK: - Private

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

            if let preview = await snapshotImage(at: 0) {
                guard token == openToken else { return }
                frameImage = preview
                displayEpoch &+= 1
            }
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

    @discardableResult
    private func captureFrame(at seconds: Double, updatePreview: Bool) -> Bool {
        guard let generator = imageGenerator else {
            lastError = "No video loaded"
            return false
        }
        var t = max(0, seconds)
        if duration > 0 { t = min(t, max(0, duration - 0.001)) }
        let time = CMTime(seconds: t, preferredTimescale: 600)

        do {
            var actualTime = CMTime.zero
            let cg = try generator.copyCGImage(at: time, actualTime: &actualTime)
            capturedCGImage = cg
            capturedPTS = actualTime.seconds.isFinite ? actualTime.seconds : t
            hasCapture = true
            lastError = nil
            if updatePreview {
                frameImage = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                displayEpoch &+= 1
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
        let codec = CMFormatDescriptionGetMediaSubType(desc as! CMFormatDescription)
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
        let wallInterval = 0.05 / min(max(speed, 0.5), 8)
        let interval = CMTime(seconds: wallInterval, preferredTimescale: 600)
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self, !self.isPaused else { return }
                self.position = max(0, time.seconds)
            }
        }
    }

    private func applyPlaybackRate(_ rate: Double) {
        guard avPlayer.currentItem != nil else { return }
        let target = Float(rate)
        avPlayer.playImmediately(atRate: target)
    }

    private func syncPositionFromPlayer() {
        let t = avPlayer.currentTime()
        if t.isValid && !t.isIndefinite {
            position = max(0, t.seconds)
        }
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
            Task { @MainActor in
                self?.pause(true)
            }
        }
    }
}
