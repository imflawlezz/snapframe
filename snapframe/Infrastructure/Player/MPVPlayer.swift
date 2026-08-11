import AppKit
import CoreGraphics
import Darwin
import Foundation
import Observation

private final class MPVCore: @unchecked Sendable {
    var mpv: OpaquePointer?
}

@Observable
@MainActor
final class MPVPlayer: VideoPlaying {
    private(set) var frameImage: NSImage?
    private(set) var position: Double = 0
    private(set) var duration: Double = 0
    private(set) var videoSize: CGSize = .zero
    private(set) var isPaused: Bool = true
    private(set) var isMuted: Bool = false
    private(set) var speed: Double = 1
    private(set) var statusText: String = "Drop a video to start"
    private(set) var hasCapture: Bool = false
    private(set) var lastError: String?

    private(set) var isOpening = false
    private(set) var openProgress: String?
    private(set) var isRenderReady = true
    private(set) var hasDisplayFrame = false
    private(set) var displayEpoch: UInt64 = 0

    private(set) var capturedCGImage: CGImage?
    private(set) var capturedPTS: Double?

    var fps: Double { fpsValue > 0 ? fpsValue : 24 }
    var currentFrame: Int { Timecode.frameIndex(at: position, fps: fps) }
    var totalFrames: Int { duration > 0 ? Timecode.frameIndex(at: duration, fps: fps) : 0 }

    var videoCodec: String? {
        getString("video-codec") ?? getString("video-format")
    }

    private let core = MPVCore()
    private var pollTimer: Timer?
    private var playTimer: Timer?
    private var scrubMode = false
    private var fpsValue: Double = 24
    private var lastPos: Double = -1
    private var seekGeneration: UInt64 = 0
    private var openToken: UInt64 = 0
    private var lastPlayCaptureAt = Date.distantPast
    private var playCaptureBusy = false
    private var playPreviewScaled = false
    private var captureSuspended = false

    init() {
        setlocale(LC_NUMERIC, "C")
        guard let h = mpv_create() else {
            statusText = "Failed to create mpv"
            lastError = statusText
            return
        }
        core.mpv = h

        _ = setOption("vo", "null")
        // `ao=auto` can select a silent device when embedded in an app.
        _ = setOption("ao", "coreaudio")
        _ = setOption("audio-client-name", "Snapframe")
        _ = setOption("volume", "100")
        _ = setOption("audio-pitch-correction", "yes")
        // VT for H.264/HEVC; software codecs listed in hwdec-codecs stay off VT.
        _ = setOption("hwdec", "videotoolbox-copy")
        _ = setOption("hwdec-codecs", "h264,hevc,prores,mpeg2video")
        _ = setOption("hr-seek", "yes")
        _ = setOption("hr-seek-framedrop", "yes")
        _ = setOption("keep-open", "yes")
        _ = setOption("idle", "yes")
        _ = setOption("osc", "no")
        _ = setOption("osd-level", "0")
        _ = setOption("input-default-bindings", "no")
        _ = setOption("input-vo-keyboard", "no")
        _ = setOption("quiet", "yes")
        _ = setOption("msg-level", "all=error")
        _ = setOption("video-sync", "audio")
        _ = setOption("framedrop", "decoder")
        _ = setOption("vd-lavc-threads", "0")

        let err = mpv_initialize(h)
        if err < 0 {
            statusText = "mpv init failed: \(errorString(err))"
            lastError = statusText
            return
        }
        startPolling()
    }

    deinit {
        if let h = core.mpv {
            mpv_terminate_destroy(h)
            core.mpv = nil
        }
    }

    func shutdown() {
        pollTimer?.invalidate()
        playTimer?.invalidate()
        pollTimer = nil
        playTimer = nil
        if let h = core.mpv {
            mpv_terminate_destroy(h)
            core.mpv = nil
        }
    }

    // MARK: - Compatibility shims

    func waitUntilRenderReady(timeout: TimeInterval = 2) async -> Bool { true }
    func notifyRenderReady() { isRenderReady = true }
    func noteRenderContextDestroyed() {}
    func reportRenderError(_ message: String) {
        lastError = message
        statusText = message
    }
    func pumpRender() {}
    func renderSoftwareFrame(width: Int, height: Int, stride: Int, into buffer: UnsafeMutableRawPointer) -> Bool {
        false
    }

    // MARK: - Open / playback

    func beginOpen(url: URL) {
        guard core.mpv != nil else { return }
        openToken &+= 1
        isOpening = true
        openProgress = "Opening file…"
        hasDisplayFrame = false

        capturedCGImage = nil
        capturedPTS = nil
        hasCapture = false
        frameImage = nil
        videoSize = .zero
        position = 0
        duration = 0
        lastPos = -1
        lastError = nil
        isPaused = true
        statusText = url.lastPathComponent

        playTimer?.invalidate()
        playTimer = nil
        playPreviewScaled = false
        playCaptureBusy = false
        captureSuspended = false

        _ = setProperty("vf", "")
        _ = setProperty("pause", "yes")
        command(["loadfile", url.path, "replace"])
        _ = setProperty("pause", "yes")
        speed = 1
        _ = setProperty("speed", "1")
        isMuted = false
        _ = setProperty("mute", "no")
        _ = setProperty("volume", "100")
    }

    func waitUntilReady(timeout: TimeInterval = 20) async -> Bool {
        let token = openToken
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if Task.isCancelled || token != openToken { return false }

            if let w = getDouble("width"), let h = getDouble("height"), w > 0, h > 0 {
                videoSize = CGSize(width: w, height: h)
                if let d = getDouble("duration"), d > 0 { duration = d }
                isOpening = false
                openProgress = nil
                configureHwdecForCurrentCodec()
                for _ in 0..<12 {
                    if captureScreenshot() { break }
                    try? await Task.sleep(nanoseconds: 40_000_000)
                    if Task.isCancelled || token != openToken { return false }
                }
                hasDisplayFrame = frameImage != nil
                displayEpoch &+= 1
                return true
            }
            openProgress = "Reading metadata…"
            try? await Task.sleep(nanoseconds: 30_000_000)
        }

        isOpening = false
        openProgress = nil
        lastError = "Timed out opening video"
        return false
    }

    private func configureHwdecForCurrentCodec() {
        let fmt = (
            (getString("video-format") ?? "") + " " +
            (getString("video-codec") ?? "") + " " +
            (getString("current-demuxer") ?? "")
        ).lowercased()

        let software = ["vp8", "vp9", "av1", "av01", "theora"].contains { fmt.contains($0) }
            || fmt.contains("webm")
        if software {
            _ = setProperty("hwdec", "no")
        } else {
            _ = setProperty("hwdec", "videotoolbox-copy")
        }
    }

    func cancelOpen() {
        openToken &+= 1
        isOpening = false
        openProgress = nil
    }

    func togglePause() { pause(!isPaused) }

    func pause(_ value: Bool) {
        if value {
            setPlayPreviewScaling(false)
            _ = setProperty("pause", "yes")
            isPaused = true
            playTimer?.invalidate()
            playTimer = nil
            _ = captureScreenshot()
        } else {
            _ = setProperty("mute", isMuted ? "yes" : "no")
            _ = setProperty("volume", "100")
            setPlayPreviewScaling(true)
            _ = setProperty("pause", "no")
            isPaused = false
            startPlayTimer()
        }
    }

    func setMuted(_ value: Bool) {
        _ = setProperty("mute", value ? "yes" : "no")
        isMuted = value
    }

    func toggleMute() { setMuted(!isMuted) }

    func setSpeed(_ value: Double) {
        speed = value
        _ = setProperty("speed", String(value))
    }

    func setScrubMode(_ enabled: Bool) {
        scrubMode = enabled
        if enabled { setPlayPreviewScaling(true) }
    }

    func setCaptureSuspended(_ suspended: Bool) {
        captureSuspended = suspended
    }

    private func setPlayPreviewScaling(_ enabled: Bool) {
        if enabled == playPreviewScaled { return }
        if enabled {
            _ = setProperty("vf", "lavfi=[scale='min(1280,iw)':-2:flags=fast_bilinear]")
            playPreviewScaled = true
        } else {
            _ = setProperty("vf", "")
            playPreviewScaled = false
        }
    }

    func seek(seconds: Double, precise: Bool) {
        guard core.mpv != nil else { return }
        var t = max(0, seconds)
        if duration > 0 { t = min(t, max(0, duration - 0.001)) }

        position = t
        lastPos = t

        if precise {
            scrubMode = false
            command(["seek", String(t), "absolute+exact"])
            seekGeneration &+= 1
            let gen = seekGeneration
            Task { @MainActor in
                await self.waitSeekSettled(target: t, timeout: 0.35)
                guard gen == self.seekGeneration else { return }
                if let pos = self.getDouble("time-pos") {
                    self.position = pos
                    self.lastPos = pos
                }
                _ = self.captureScreenshot()
            }
        } else {
            scrubMode = true
            command(["seek", String(t), "absolute+keyframes"])
        }
    }

    func refreshScrubPreview() {
        _ = captureScreenshot()
    }

    @discardableResult
    func captureExactFrame() -> Bool {
        scrubMode = false
        setPlayPreviewScaling(false)
        return captureScreenshot()
    }

    @discardableResult
    func refreshFrame(preferQuality: Bool = true) -> Bool {
        if preferQuality { setPlayPreviewScaling(false) }
        return captureScreenshot()
    }

    func seekToFrame(_ frame: Int, precise: Bool = true) {
        seek(seconds: Timecode.seconds(forFrame: frame, fps: fps), precise: precise)
    }

    func frameStep(_ n: Int) {
        pause(true)
        scrubMode = false
        guard n != 0 else { return }

        if abs(n) == 1 {
            let before = getDouble("time-pos") ?? position
            command([n > 0 ? "frame-step" : "frame-back-step"])
            Task { @MainActor in
                await self.waitUntilPositionMoves(from: before, timeout: 0.14)
                if let pos = self.getDouble("time-pos") {
                    self.position = pos
                    self.lastPos = pos
                }
                _ = self.captureScreenshot()
            }
            return
        }

        let base = capturedPTS ?? position
        seek(seconds: base + Double(n) / fps, precise: true)
    }

    // MARK: - Capture

    @discardableResult
    private func captureScreenshot() -> Bool {
        guard core.mpv != nil, getString("path") != nil else { return false }

        var result = mpv_node()
        var code = commandRet(["screenshot-raw", "video"], result: &result)
        if code < 0 {
            configureHwdecForCurrentCodec()
            _ = setProperty("hwdec", "no")
            code = commandRet(["screenshot-raw", "video"], result: &result)
            if code < 0 {
                lastError = "Frame capture failed: \(errorString(code))"
                return false
            }
        }
        defer { mpv_free_node_contents(&result) }

        guard let parsed = parseScreenshotNode(result) else {
            lastError = "Could not decode frame buffer"
            return false
        }

        let pts = getDouble("time-pos")
        lastError = nil
        capturedCGImage = parsed.image
        capturedPTS = pts
        hasCapture = true

        let display: CGImage
        if (parsed.width > 1280 || parsed.height > 720),
           let small = scaledImage(parsed.image, maxSide: 960, quality: .low) {
            display = small
        } else {
            display = parsed.image
        }
        frameImage = NSImage(cgImage: display, size: NSSize(width: display.width, height: display.height))
        hasDisplayFrame = true
        displayEpoch &+= 1

        if let pts {
            position = pts
            lastPos = pts
        }
        return true
    }

    // MARK: - Timers

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.poll() }
        }
    }

    private func startPlayTimer() {
        playTimer?.invalidate()
        let interval = 1.0 / 24.0
        playTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.playCaptureTick()
            }
        }
    }

    private func playCaptureTick() {
        guard !isPaused, !playCaptureBusy, !captureSuspended else { return }
        let now = Date()
        guard now.timeIntervalSince(lastPlayCaptureAt) >= 0.032 else { return }
        playCaptureBusy = true
        lastPlayCaptureAt = now
        _ = captureScreenshot()
        playCaptureBusy = false
    }

    private func poll() {
        if isOpening {
            if let w = getDouble("width"), let h = getDouble("height"), w > 0, h > 0 {
                let size = CGSize(width: w, height: h)
                if videoSize != size { videoSize = size }
            }
            if let d = getDouble("duration"), d > 0, abs(d - duration) > 0.01 { duration = d }
            return
        }

        if let d = getDouble("duration"), abs(d - duration) > 0.01 { duration = d }
        if let w = getDouble("width"), let h = getDouble("height"), w > 0, h > 0 {
            // Ignore scaled preview dimensions from the play-preview vf.
            if !playPreviewScaled {
                let size = CGSize(width: w, height: h)
                if videoSize != size { videoSize = size }
            }
        }
        if let paused = getFlag("pause"), paused != isPaused {
            isPaused = paused
            if paused {
                playTimer?.invalidate()
                playTimer = nil
                setPlayPreviewScaling(false)
            } else if playTimer == nil {
                setPlayPreviewScaling(true)
                startPlayTimer()
            }
        }
        if !isPaused, !scrubMode, let pos = getDouble("time-pos"), abs(pos - lastPos) >= 0.04 {
            lastPos = pos
            position = pos
        }
        if let fps = getDouble("container-fps") ?? getDouble("estimated-vf-fps"), fps > 0 {
            fpsValue = fps
        }
    }

    private func waitSeekSettled(target: Double?, timeout: Double) async {
        let deadline = Date().addingTimeInterval(timeout)
        let frame = 1.0 / max(fps, 1)
        let tol = max(0.04, frame * 1.2)
        try? await Task.sleep(nanoseconds: 12_000_000)
        while Date() < deadline {
            guard !Task.isCancelled else { return }
            if getFlag("seeking") != true,
               let pos = getDouble("time-pos"),
               target == nil || abs(pos - target!) <= tol {
                return
            }
            try? await Task.sleep(nanoseconds: 6_000_000)
        }
    }

    private func waitUntilPositionMoves(from before: Double, timeout: Double) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            guard !Task.isCancelled else { return }
            if let pos = getDouble("time-pos"), abs(pos - before) > 1e-4 { return }
            try? await Task.sleep(nanoseconds: 6_000_000)
        }
    }

    // MARK: - mpv helpers

    private struct ParsedFrame {
        var image: CGImage
        var width: Int
        var height: Int
    }

    private func parseScreenshotNode(_ result: mpv_node) -> ParsedFrame? {
        guard result.format == MPV_FORMAT_NODE_MAP,
              let list = result.u.list,
              list.pointee.num > 0 else { return nil }

        var w = 0, imgH = 0, stride = 0
        var format = "bgr0"
        var dataPtr: UnsafeRawPointer?

        let num = Int(list.pointee.num)
        for i in 0..<num {
            let key = String(cString: list.pointee.keys[i]!)
            let node = list.pointee.values[i]
            switch key {
            case "w", "width":
                if node.format == MPV_FORMAT_INT64 { w = Int(node.u.int64) }
            case "h", "height":
                if node.format == MPV_FORMAT_INT64 { imgH = Int(node.u.int64) }
            case "stride":
                if node.format == MPV_FORMAT_INT64 { stride = Int(node.u.int64) }
            case "format":
                if node.format == MPV_FORMAT_STRING, let s = node.u.string {
                    format = String(cString: s)
                }
            case "data":
                if node.format == MPV_FORMAT_BYTE_ARRAY, let ba = node.u.ba {
                    dataPtr = UnsafeRawPointer(ba.pointee.data)
                }
            default: break
            }
        }

        guard w > 0, imgH > 0, let dataPtr else { return nil }
        if stride == 0 { stride = w * 4 }
        guard let image = makeCGImage(width: w, height: imgH, stride: stride, format: format, data: dataPtr) else {
            return nil
        }
        return ParsedFrame(image: image, width: w, height: imgH)
    }

    private func setOption(_ name: String, _ value: String) -> Int32 {
        guard let h = core.mpv else { return -1 }
        return name.withCString { n in value.withCString { v in mpv_set_option_string(h, n, v) } }
    }

    @discardableResult
    private func setProperty(_ name: String, _ value: String) -> Int32 {
        guard let h = core.mpv else { return -1 }
        return name.withCString { n in value.withCString { v in mpv_set_property_string(h, n, v) } }
    }

    private func command(_ args: [String]) {
        guard let h = core.mpv else { return }
        var cStrings = args.map { strdup($0) }
        cStrings.append(nil)
        defer { cStrings.forEach { free($0) } }
        _ = cStrings.withUnsafeMutableBufferPointer { buf in
            buf.baseAddress!.withMemoryRebound(to: UnsafePointer<CChar>?.self, capacity: buf.count) { ptr in
                mpv_command(h, ptr)
            }
        }
    }

    @discardableResult
    private func commandRet(_ args: [String], result: inout mpv_node) -> Int32 {
        guard let h = core.mpv else { return -1 }
        var cStrings = args.map { strdup($0) }
        cStrings.append(nil)
        defer { cStrings.forEach { free($0) } }
        return cStrings.withUnsafeMutableBufferPointer { buf in
            buf.baseAddress!.withMemoryRebound(to: UnsafePointer<CChar>?.self, capacity: buf.count) { ptr in
                mpv_command_ret(h, ptr, &result)
            }
        }
    }

    private func getString(_ name: String) -> String? {
        guard let h = core.mpv else { return nil }
        return name.withCString { n in
            guard let c = mpv_get_property_string(h, n) else { return nil }
            defer { mpv_free(c) }
            return String(cString: c)
        }
    }

    private func getDouble(_ name: String) -> Double? {
        guard let h = core.mpv else { return nil }
        var value: Double = 0
        let err = name.withCString { n in mpv_get_property(h, n, MPV_FORMAT_DOUBLE, &value) }
        return err >= 0 ? value : nil
    }

    private func getFlag(_ name: String) -> Bool? {
        guard let h = core.mpv else { return nil }
        var value: Int64 = 0
        let err = name.withCString { n in mpv_get_property(h, n, MPV_FORMAT_FLAG, &value) }
        return err >= 0 ? value != 0 : nil
    }

    private func errorString(_ err: Int32) -> String {
        String(cString: mpv_error_string(err))
    }

    private func makeCGImage(width: Int, height: Int, stride: Int, format: String, data: UnsafeRawPointer) -> CGImage? {
        let fmt = format.lowercased()
        let byteOrder: CGBitmapInfo
        let alpha: CGImageAlphaInfo
        switch fmt {
        case "bgr0", "bgra":
            byteOrder = .byteOrder32Little
            alpha = fmt == "bgra" ? .premultipliedFirst : .noneSkipFirst
        case "rgb0", "rgba":
            byteOrder = .byteOrder32Big
            alpha = fmt == "rgba" ? .premultipliedLast : .noneSkipLast
        default:
            byteOrder = .byteOrder32Little
            alpha = .noneSkipFirst
        }

        let bufferSize = stride * height
        let copy = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: 16)
        copy.copyMemory(from: data, byteCount: bufferSize)

        let release: CGDataProviderReleaseDataCallback = { _, data, _ in
            UnsafeMutableRawPointer(mutating: data)?.deallocate()
        }
        guard let provider = CGDataProvider(dataInfo: nil, data: copy, size: bufferSize, releaseData: release) else {
            copy.deallocate()
            return nil
        }

        let bitmapInfo = CGBitmapInfo(rawValue: alpha.rawValue).union(byteOrder)
        return CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: stride,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo,
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

    private func scaledImage(_ image: CGImage, maxSide: Int, quality: CGInterpolationQuality) -> CGImage? {
        let w = image.width
        let h = image.height
        let scale = min(CGFloat(maxSide) / CGFloat(max(w, h)), 1)
        if scale >= 0.999 { return image }
        let nw = max(1, Int(CGFloat(w) * scale))
        let nh = max(1, Int(CGFloat(h) * scale))
        guard let ctx = CGContext(
            data: nil, width: nw, height: nh,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = quality
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: nw, height: nh))
        return ctx.makeImage()
    }
}
