import AppKit
import CoreGraphics
import Foundation

@MainActor
protocol VideoPlaying: AnyObject {
    var frameImage: NSImage? { get }
    var position: Double { get }
    var duration: Double { get }
    var videoSize: CGSize { get }
    var isPaused: Bool { get }
    var isMuted: Bool { get }
    var speed: Double { get }
    var fps: Double { get }
    var currentFrame: Int { get }
    var totalFrames: Int { get }
    var videoCodec: String? { get }
    var lastError: String? { get }
    var capturedCGImage: CGImage? { get }
    var capturedPTS: Double? { get }

    func beginOpen(url: URL)
    func waitUntilReady(timeout: TimeInterval) async -> Bool
    func cancelOpen()
    func shutdown()

    func togglePause()
    func pause(_ value: Bool)
    func toggleMute()
    func setMuted(_ value: Bool)
    func setSpeed(_ value: Double)

    func seek(seconds: Double, precise: Bool)
    func setScrubMode(_ enabled: Bool)
    func frameStep(_ n: Int)
    func setCaptureSuspended(_ suspended: Bool)

    @discardableResult
    func captureExactFrame() -> Bool
    @discardableResult
    func refreshFrame(preferQuality: Bool) -> Bool
    func refreshScrubPreview()
}
