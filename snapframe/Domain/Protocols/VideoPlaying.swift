import AppKit
import AVFoundation
import CoreGraphics
import Foundation

@MainActor
protocol VideoPlaying: AnyObject {
    var avPlayer: AVPlayer { get }
    var frameImage: NSImage? { get }
    var displayEpoch: UInt64 { get }
    var position: Double { get }
    var duration: Double { get }
    var videoSize: CGSize { get }
    var isPaused: Bool { get }
    var isMuted: Bool { get }
    var volume: Double { get }
    var speed: Double { get }
    var fps: Double { get }
    var currentFrame: Int { get }
    var totalFrames: Int { get }
    var videoCodec: String? { get }
    var lastError: String? { get }
    var capturedCGImage: CGImage? { get }
    var capturedPTS: Double? { get }
    var holdsFramePreview: Bool { get }

    func beginOpen(url: URL)
    func waitUntilReady(timeout: TimeInterval) async -> Bool
    func cancelOpen()
    func shutdown()

    func togglePause()
    func pause(_ value: Bool)
    func toggleMute()
    func setMuted(_ value: Bool)
    func setVolume(_ value: Double)
    func commitVolume()
    func setSpeed(_ value: Double)

    func seek(seconds: Double, precise: Bool)
    func setScrubMode(_ enabled: Bool)
    func frameStep(_ n: Int)
    func setCaptureSuspended(_ suspended: Bool)
    func setPlaybackCaptureSuppressed(_ suspended: Bool)
    func applyPlaybackPreferences()

    @discardableResult
    func captureExactFrame() -> Bool
    @discardableResult
    func refreshFrame(preferQuality: Bool) -> Bool
    func refreshScrubPreview()
    func snapshotImage(at seconds: Double) async -> NSImage?
}
