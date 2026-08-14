import AppKit
import SwiftUI

struct CropOverlayView: NSViewRepresentable {
    var videoSize: CGSize
    @Binding var crop: CropRect
    var resizeLock: CropResizeLock = .free
    var scissorsMode = false
    var accent: NSColor = NSColor(red: 0.12, green: 0.72, blue: 0.68, alpha: 1)
    var onInteractionChange: ((Bool) -> Void)?
    var onScissorsComplete: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            crop: $crop,
            onInteractionChange: onInteractionChange,
            onScissorsComplete: onScissorsComplete
        )
    }

    func makeNSView(context: Context) -> CropCanvasView {
        let view = CropCanvasView()
        view.coordinator = context.coordinator
        view.accent = accent
        view.videoSize = videoSize
        view.crop = crop
        view.resizeLock = resizeLock
        view.scissorsMode = scissorsMode
        return view
    }

    func updateNSView(_ nsView: CropCanvasView, context: Context) {
        context.coordinator.crop = $crop
        context.coordinator.onInteractionChange = onInteractionChange
        context.coordinator.onScissorsComplete = onScissorsComplete
        nsView.accent = accent
        nsView.videoSize = videoSize
        nsView.resizeLock = resizeLock
        nsView.scissorsMode = scissorsMode
        nsView.needsDisplay = true
        guard !nsView.isInteracting else { return }
        if nsView.crop != crop {
            nsView.crop = crop
            nsView.needsDisplay = true
        }
    }

    final class Coordinator {
        var crop: Binding<CropRect>
        var onInteractionChange: ((Bool) -> Void)?
        var onScissorsComplete: (() -> Void)?
        init(
            crop: Binding<CropRect>,
            onInteractionChange: ((Bool) -> Void)?,
            onScissorsComplete: (() -> Void)?
        ) {
            self.crop = crop
            self.onInteractionChange = onInteractionChange
            self.onScissorsComplete = onScissorsComplete
        }
        func commit(_ value: CropRect) {
            if crop.wrappedValue != value {
                crop.wrappedValue = value
            }
        }
        func setInteracting(_ active: Bool) {
            onInteractionChange?(active)
        }
        func scissorsComplete() {
            onScissorsComplete?()
        }
    }
}

final class CropCanvasView: NSView {
    weak var coordinator: CropOverlayView.Coordinator?
    var accent: NSColor = .systemTeal
    var resizeLock: CropResizeLock = .free
    var scissorsMode = false {
        didSet {
            guard oldValue != scissorsMode else { return }
            if !scissorsMode { cancelScissorsDrag() }
            scissorsLive = false
            window?.invalidateCursorRects(for: self)
            needsDisplay = true
        }
    }
    var videoSize: CGSize = .zero {
        didSet { if oldValue != videoSize { needsDisplay = true } }
    }
    var crop = CropRect.default {
        didSet { needsDisplay = true }
    }

    private enum Mode {
        case none, move, place
        case nw, ne, sw, se
        case n, e, s, w
    }

    private var mode: Mode = .none
    private var origin = CropRect.default
    private var anchor = CGPoint.zero
    private var startPoint = CGPoint.zero
    private let handleRadius: CGFloat = 5
    private let edgeHit: CGFloat = 8
    private let minCrop = 16
    private var scrollCommitWork: DispatchWorkItem?
    private var dimAlpha: CGFloat = 0.48
    private var layoutAnimating = false
    private var presentedLetter = CGRect.zero
    private var presentedCrop = CGRect.zero
    private var layoutTimer: Timer?
    private var scissorsLive = false
    private var preDragCrop = CropRect.default

    var isInteracting: Bool { mode != .none }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }

    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        animateLayoutIfNeeded()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        animateLayoutIfNeeded()
    }

    override func layout() {
        super.layout()
        if !layoutAnimating {
            needsDisplay = true
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            dimAlpha = 0.48
            needsDisplay = true
        }
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if superview == nil {
            layoutTimer?.invalidate()
        }
    }

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func draw(_ dirtyRect: NSRect) {
        guard videoSize.width > 0, videoSize.height > 0 else { return }
        let letterTarget = letterbox(in: bounds.size)
        let scale = letterTarget.width / videoSize.width
        let cropTarget = viewRect(letter: letterTarget, scale: scale)
        let letter = layoutAnimating ? presentedLetter : letterTarget
        let r = layoutAnimating ? presentedCrop : cropTarget
        if !layoutAnimating {
            presentedLetter = letterTarget
            presentedCrop = cropTarget
        }

        if scissorsMode && !scissorsLive { return }

        let dim = NSColor.black.withAlphaComponent(dimAlpha)
        dim.setFill()
        let path = NSBezierPath(rect: letter)
        path.append(NSBezierPath(rect: r))
        path.windingRule = .evenOdd
        path.fill()

        accent.setStroke()
        let frame = NSBezierPath(rect: r.insetBy(dx: 0.5, dy: 0.5))
        frame.lineWidth = 2
        frame.stroke()

        NSColor.white.withAlphaComponent(0.28).setStroke()
        let thirds = NSBezierPath()
        for i in 1...2 {
            let x = r.minX + r.width * CGFloat(i) / 3
            let y = r.minY + r.height * CGFloat(i) / 3
            thirds.move(to: CGPoint(x: x, y: r.minY))
            thirds.line(to: CGPoint(x: x, y: r.maxY))
            thirds.move(to: CGPoint(x: r.minX, y: y))
            thirds.line(to: CGPoint(x: r.maxX, y: y))
        }
        thirds.lineWidth = 1
        thirds.stroke()

        if !scissorsMode {
            accent.setFill()
            NSColor.white.setStroke()
            for p in cornerPoints(r) {
                let hr = NSRect(x: p.x - handleRadius, y: p.y - handleRadius,
                                width: handleRadius * 2, height: handleRadius * 2)
                let h = NSBezierPath(ovalIn: hr)
                h.fill()
                h.lineWidth = 1.5
                h.stroke()
            }

            accent.withAlphaComponent(0.9).setFill()
            NSColor.white.setStroke()
            for p in edgeMidpoints(r) {
                let hr = NSRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)
                let h = NSBezierPath(ovalIn: hr)
                h.fill()
                h.lineWidth = 1
                h.stroke()
            }
        }

        let off = crop.centerOffset(in: videoSize)
        drawCropBadge(at: r, offset: off)
    }

    private func drawCropBadge(at r: CGRect, offset: (dx: Int, dy: Int)) {
        let dimFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        let metaFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        let dim = "\(crop.width) × \(crop.height)" as NSString
        let meta = String(format: "%+d, %+d", offset.dx, offset.dy) as NSString

        let dimAttrs: [NSAttributedString.Key: Any] = [
            .font: dimFont,
            .foregroundColor: NSColor.white,
        ]
        let metaAttrs: [NSAttributedString.Key: Any] = [
            .font: metaFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.62),
        ]
        let dimSize = dim.size(withAttributes: dimAttrs)
        let metaSize = meta.size(withAttributes: metaAttrs)
        let padX: CGFloat = 10
        let padY: CGFloat = 6
        let gap: CGFloat = 6
        let dividerH: CGFloat = max(dimSize.height, metaSize.height)
        let contentW = dimSize.width + gap + 1 + gap + metaSize.width
        let contentH = max(dimSize.height, metaSize.height)
        let badgeW = contentW + padX * 2
        let badgeH = contentH + padY * 2

        var origin = CGPoint(x: r.minX, y: r.minY - badgeH - 8)
        if origin.y < 4 {
            origin.y = min(bounds.maxY - badgeH - 4, r.maxY + 8)
        }
        origin.x = min(max(4, origin.x), bounds.maxX - badgeW - 4)

        let bg = NSRect(x: origin.x, y: origin.y, width: badgeW, height: badgeH)
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: bg, xRadius: 7, yRadius: 7).fill()
        accent.withAlphaComponent(0.55).setStroke()
        let stroke = NSBezierPath(roundedRect: bg.insetBy(dx: 0.5, dy: 0.5), xRadius: 7, yRadius: 7)
        stroke.lineWidth = 1
        stroke.stroke()

        let textY = origin.y + (badgeH - contentH) / 2
        var x = origin.x + padX
        dim.draw(at: CGPoint(x: x, y: textY + (contentH - dimSize.height) / 2), withAttributes: dimAttrs)
        x += dimSize.width + gap

        NSColor.white.withAlphaComponent(0.22).setFill()
        NSBezierPath(rect: NSRect(x: x, y: origin.y + (badgeH - dividerH) / 2, width: 1, height: dividerH)).fill()
        x += 1 + gap

        meta.draw(at: CGPoint(x: x, y: textY + (contentH - metaSize.height) / 2), withAttributes: metaAttrs)
    }

    // MARK: - Interaction

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard videoSize.width > 0 else { return }
        let p = convert(event.locationInWindow, from: nil)
        let letter = letterbox(in: bounds.size)
        guard letter.contains(p) else { return }
        let scale = letter.width / videoSize.width
        let r = viewRect(letter: letter, scale: scale)

        origin = crop
        startPoint = p

        if scissorsMode {
            beginScissors(at: p, letter: letter, scale: scale)
            return
        }

        for m in [Mode.nw, .ne, .sw, .se] where hitCorner(m, in: r, point: p) {
            beginResize(m)
            return
        }
        for m in [Mode.n, .e, .s, .w] where hitEdge(m, in: r, point: p) {
            beginResize(m)
            return
        }

        if r.insetBy(dx: -4, dy: -4).contains(p) {
            mode = .move
            coordinator?.setInteracting(true)
            return
        }

        mode = .place
        coordinator?.setInteracting(true)
        let vx = Int((p.x - letter.minX) / scale) - crop.width / 2
        let vy = Int((p.y - letter.minY) / scale) - crop.height / 2
        var next = crop
        next.x = vx
        next.y = vy
        apply(clamp(next), commit: true)
    }

    override func mouseDragged(with event: NSEvent) {
        guard videoSize.width > 0, mode != .none else { return }
        let p = convert(event.locationInWindow, from: nil)
        let letter = letterbox(in: bounds.size)
        let scale = letter.width / videoSize.width
        guard scale > 0 else { return }

        if scissorsMode, mode == .place {
            scissorsLive = true
            apply(scissorsCrop(to: p, letter: letter, scale: scale), commit: false)
            return
        }
        if mode == .place { return }

        if mode == .move {
            let dx = (p.x - startPoint.x) / scale
            let dy = (p.y - startPoint.y) / scale
            var next = origin
            next.x = Int((Double(origin.x) + dx).rounded())
            next.y = Int((Double(origin.y) + dy).rounded())
            apply(clamp(next), commit: false)
            return
        }

        let mx = min(max(0, (p.x - letter.minX) / scale), videoSize.width)
        let my = min(max(0, (p.y - letter.minY) / scale), videoSize.height)
        apply(resize(mode: mode, mouse: CGPoint(x: mx, y: my)), commit: false)
    }

    override func mouseUp(with event: NSEvent) {
        if scissorsMode, mode == .place {
            let didDrag = scissorsLive
            scissorsLive = false
            let valid = didDrag && crop.width >= minCrop && crop.height >= minCrop
            if valid {
                coordinator?.commit(crop)
            } else {
                apply(preDragCrop, commit: true)
            }
            mode = .none
            coordinator?.setInteracting(false)
            window?.invalidateCursorRects(for: self)
            if valid {
                DispatchQueue.main.async { [weak self] in
                    self?.coordinator?.scissorsComplete()
                }
            }
            return
        }
        switch mode {
        case .move, .nw, .ne, .sw, .se, .n, .e, .s, .w:
            coordinator?.commit(crop)
        default:
            break
        }
        mode = .none
        coordinator?.setInteracting(false)
    }

    override func scrollWheel(with event: NSEvent) {
        guard videoSize.width > 0, !scissorsMode else {
            nextResponder?.scrollWheel(with: event)
            return
        }
        let scale: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 8
        let dy = event.scrollingDeltaY * scale
        let dx = event.scrollingDeltaX * scale
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let shift = mods.contains(.shift)
        let raw = shift ? (abs(dx) >= abs(dy) ? dx : dy) : dy
        guard abs(raw) > 0.05 else { return }
        coordinator?.setInteracting(true)
        let step = max(1, Int((abs(raw) * 0.75).rounded()))
        let signed = raw > 0 ? step : -step
        var next = crop
        if shift {
            next.setWidth(next.width + signed, in: videoSize, lock: resizeLock)
        } else {
            next.setHeight(next.height + signed, in: videoSize, lock: resizeLock)
        }
        apply(next, commit: false)

        scrollCommitWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.coordinator?.commit(self.crop)
            self.coordinator?.setInteracting(false)
        }
        scrollCommitWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
    }

    override func resetCursorRects() {
        guard videoSize.width > 0 else { return }
        let letter = letterbox(in: bounds.size)
        if scissorsMode {
            addCursorRect(letter, cursor: .crosshair)
            return
        }
        let scale = letter.width / videoSize.width
        let r = viewRect(letter: letter, scale: scale)
        addCursorRect(r, cursor: .openHand)
        for m in [Mode.nw, .ne, .sw, .se] {
            addCursorRect(cornerHitRect(m, in: r), cursor: .crosshair)
        }
        addCursorRect(edgeHitRect(.n, in: r), cursor: .resizeUpDown)
        addCursorRect(edgeHitRect(.s, in: r), cursor: .resizeUpDown)
        addCursorRect(edgeHitRect(.e, in: r), cursor: .resizeLeftRight)
        addCursorRect(edgeHitRect(.w, in: r), cursor: .resizeLeftRight)
    }

    // MARK: - Layout animation

    private func animateLayoutIfNeeded() {
        guard videoSize.width > 0, window != nil, !isInteracting else {
            needsDisplay = true
            return
        }
        let letter = letterbox(in: bounds.size)
        let scale = letter.width / max(videoSize.width, 1)
        let cropRect = viewRect(letter: letter, scale: scale)
        if presentedLetter == .zero {
            presentedLetter = letter
            presentedCrop = cropRect
            needsDisplay = true
            return
        }
        if hypot(letter.midX - presentedLetter.midX, letter.midY - presentedLetter.midY) < 0.5,
           abs(letter.width - presentedLetter.width) < 0.5 {
            needsDisplay = true
            return
        }
        let fromLetter = presentedLetter
        let fromCrop = presentedCrop
        layoutTimer?.invalidate()
        layoutAnimating = true
        let start = Date()
        let duration: TimeInterval = 0.12
        layoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let p = min(1, Date().timeIntervalSince(start) / duration)
            let e = 1 - pow(1 - p, 3)
            self.presentedLetter = Self.lerp(fromLetter, letter, e)
            self.presentedCrop = Self.lerp(fromCrop, cropRect, e)
            self.needsDisplay = true
            if p >= 1 {
                timer.invalidate()
                self.layoutAnimating = false
                self.presentedLetter = letter
                self.presentedCrop = cropRect
            }
        }
        RunLoop.main.add(layoutTimer!, forMode: .common)
    }

    private static func lerp(_ a: CGRect, _ b: CGRect, _ t: CGFloat) -> CGRect {
        CGRect(
            x: a.origin.x + (b.origin.x - a.origin.x) * t,
            y: a.origin.y + (b.origin.y - a.origin.y) * t,
            width: a.width + (b.width - a.width) * t,
            height: a.height + (b.height - a.height) * t
        )
    }

    // MARK: - Geometry

    private func letterbox(in size: CGSize) -> CGRect {
        CropGeometry.letterbox(videoSize: videoSize, in: size)
    }

    private func viewRect(letter: CGRect, scale: CGFloat) -> CGRect {
        CropGeometry.viewRect(crop: crop, letter: letter, videoSize: videoSize)
    }

    private func cornerPoints(_ r: CGRect) -> [CGPoint] {
        [CGPoint(x: r.minX, y: r.minY),
         CGPoint(x: r.maxX, y: r.minY),
         CGPoint(x: r.minX, y: r.maxY),
         CGPoint(x: r.maxX, y: r.maxY)]
    }

    private func edgeMidpoints(_ r: CGRect) -> [CGPoint] {
        [CGPoint(x: r.midX, y: r.minY),
         CGPoint(x: r.maxX, y: r.midY),
         CGPoint(x: r.midX, y: r.maxY),
         CGPoint(x: r.minX, y: r.midY)]
    }

    private func cornerHitRect(_ m: Mode, in r: CGRect) -> CGRect {
        let p: CGPoint = switch m {
        case .nw: CGPoint(x: r.minX, y: r.minY)
        case .ne: CGPoint(x: r.maxX, y: r.minY)
        case .sw: CGPoint(x: r.minX, y: r.maxY)
        case .se: CGPoint(x: r.maxX, y: r.maxY)
        default: .zero
        }
        let pad: CGFloat = 10
        return CGRect(x: p.x - pad, y: p.y - pad, width: pad * 2, height: pad * 2)
    }

    private func edgeHitRect(_ m: Mode, in r: CGRect) -> CGRect {
        switch m {
        case .n: return CGRect(x: r.minX + 10, y: r.minY - edgeHit, width: max(0, r.width - 20), height: edgeHit * 2)
        case .s: return CGRect(x: r.minX + 10, y: r.maxY - edgeHit, width: max(0, r.width - 20), height: edgeHit * 2)
        case .w: return CGRect(x: r.minX - edgeHit, y: r.minY + 10, width: edgeHit * 2, height: max(0, r.height - 20))
        case .e: return CGRect(x: r.maxX - edgeHit, y: r.minY + 10, width: edgeHit * 2, height: max(0, r.height - 20))
        default: return .zero
        }
    }

    private func hitCorner(_ m: Mode, in r: CGRect, point: CGPoint) -> Bool {
        cornerHitRect(m, in: r).contains(point)
    }

    private func hitEdge(_ m: Mode, in r: CGRect, point: CGPoint) -> Bool {
        edgeHitRect(m, in: r).contains(point)
    }

    private func beginScissors(at p: CGPoint, letter: CGRect, scale: CGFloat) {
        preDragCrop = crop
        scissorsLive = false
        let vx = min(max(0, (p.x - letter.minX) / scale), videoSize.width)
        let vy = min(max(0, (p.y - letter.minY) / scale), videoSize.height)
        anchor = CGPoint(x: vx, y: vy)
        origin = CropRect(x: Int(vx.rounded()), y: Int(vy.rounded()), width: minCrop, height: minCrop)
        mode = .place
        coordinator?.setInteracting(true)
        needsDisplay = true
    }

    private func scissorsCrop(to p: CGPoint, letter: CGRect, scale: CGFloat) -> CropRect {
        let mx = min(max(0, (p.x - letter.minX) / scale), videoSize.width)
        let my = min(max(0, (p.y - letter.minY) / scale), videoSize.height)
        let corner: Mode
        if mx >= anchor.x && my >= anchor.y {
            corner = .se
        } else if mx < anchor.x && my >= anchor.y {
            corner = .sw
        } else if mx >= anchor.x && my < anchor.y {
            corner = .ne
        } else {
            corner = .nw
        }
        return resizeCorner(mode: corner, mouse: CGPoint(x: mx, y: my))
    }

    private func cancelScissorsDrag() {
        guard mode == .place else { return }
        apply(preDragCrop, commit: false)
        mode = .none
        scissorsLive = false
        coordinator?.setInteracting(false)
    }

    private func beginResize(_ m: Mode) {
        mode = m
        coordinator?.setInteracting(true)
        let ox = CGFloat(crop.x), oy = CGFloat(crop.y)
        let ow = CGFloat(crop.width), oh = CGFloat(crop.height)
        switch m {
        case .se, .s, .e: anchor = CGPoint(x: ox, y: oy)
        case .nw, .n, .w: anchor = CGPoint(x: ox + ow, y: oy + oh)
        case .ne: anchor = CGPoint(x: ox, y: oy + oh)
        case .sw: anchor = CGPoint(x: ox + ow, y: oy)
        default: break
        }
    }

    private func resize(mode: Mode, mouse: CGPoint) -> CropRect {
        switch mode {
        case .n, .e, .s, .w:
            return resizeEdge(mode: mode, mouse: mouse)
        case .nw, .ne, .sw, .se:
            return resizeCorner(mode: mode, mouse: mouse)
        default:
            return crop
        }
    }

    private func resizeCorner(mode: Mode, mouse: CGPoint) -> CropRect {
        let ax = anchor.x, ay = anchor.y
        var next = origin

        switch resizeLock {
        case .square:
            var side: CGFloat = 0
            switch mode {
            case .se: side = max(mouse.x - ax, mouse.y - ay)
            case .nw: side = max(ax - mouse.x, ay - mouse.y)
            case .ne: side = max(mouse.x - ax, ay - mouse.y)
            case .sw: side = max(ax - mouse.x, mouse.y - ay)
            default: return crop
            }
            next.width = Int(side.rounded())
            next.height = next.width
            placeCorner(mode: mode, next: &next, ax: ax, ay: ay, w: side, h: side)
            return clampResize(next, mode: mode)

        case .ratio(let rw, let rh):
            let ratio = Double(rw) / Double(rh)
            var w: CGFloat = 0
            var h: CGFloat = 0
            switch mode {
            case .se: w = mouse.x - ax; h = mouse.y - ay
            case .nw: w = ax - mouse.x; h = ay - mouse.y
            case .ne: w = mouse.x - ax; h = ay - mouse.y
            case .sw: w = ax - mouse.x; h = mouse.y - ay
            default: return crop
            }
            if abs(w) / ratio > abs(h) {
                h = w / ratio
            } else {
                w = h * ratio
            }
            next.width = max(minCrop, Int(w.rounded()))
            next.height = max(minCrop, Int(h.rounded()))
            placeCorner(mode: mode, next: &next, ax: ax, ay: ay, w: w, h: h)
            return clampResize(next, mode: mode)

        case .free:
            switch mode {
            case .se:
                next.width = Int((mouse.x - ax).rounded())
                next.height = Int((mouse.y - ay).rounded())
                next.x = Int(ax.rounded()); next.y = Int(ay.rounded())
            case .nw:
                next.width = Int((ax - mouse.x).rounded())
                next.height = Int((ay - mouse.y).rounded())
                next.x = Int((ax - CGFloat(next.width)).rounded())
                next.y = Int((ay - CGFloat(next.height)).rounded())
            case .ne:
                next.width = Int((mouse.x - ax).rounded())
                next.height = Int((ay - mouse.y).rounded())
                next.x = Int(ax.rounded())
                next.y = Int((ay - CGFloat(next.height)).rounded())
            case .sw:
                next.width = Int((ax - mouse.x).rounded())
                next.height = Int((mouse.y - ay).rounded())
                next.x = Int((ax - CGFloat(next.width)).rounded())
                next.y = Int(ay.rounded())
            default:
                return crop
            }
            return clampResize(next, mode: mode)
        }
    }

    private func placeCorner(mode: Mode, next: inout CropRect, ax: CGFloat, ay: CGFloat, w: CGFloat, h: CGFloat) {
        switch mode {
        case .se:
            next.x = Int(ax.rounded()); next.y = Int(ay.rounded())
        case .nw:
            next.x = Int((ax - w).rounded()); next.y = Int((ay - h).rounded())
        case .ne:
            next.x = Int(ax.rounded()); next.y = Int((ay - h).rounded())
        case .sw:
            next.x = Int((ax - w).rounded()); next.y = Int(ay.rounded())
        default: break
        }
    }

    private func resizeEdge(mode: Mode, mouse: CGPoint) -> CropRect {
        switch resizeLock {
        case .free:
            var next = origin
            let ax = anchor.x, ay = anchor.y
            switch mode {
            case .e:
                next.width = Int((mouse.x - ax).rounded())
                next.x = Int(ax.rounded())
            case .w:
                next.width = Int((ax - mouse.x).rounded())
                next.x = Int((ax - CGFloat(next.width)).rounded())
            case .s:
                next.height = Int((mouse.y - ay).rounded())
                next.y = Int(ay.rounded())
            case .n:
                next.height = Int((ay - mouse.y).rounded())
                next.y = Int((ay - CGFloat(next.height)).rounded())
            default: return crop
            }
            return clampResize(next, mode: mode)

        case .square, .ratio:
            return resizeEdgeLocked(mode: mode, mouse: mouse)
        }
    }

    private func lockedRatio() -> Double {
        if case .ratio(let rw, let rh) = resizeLock { return Double(rw) / Double(rh) }
        return 1
    }

    private func resizeEdgeLocked(mode: Mode, mouse: CGPoint) -> CropRect {
        let ratio = lockedRatio()
        let maxW = videoSize.width
        let maxH = videoSize.height
        let cx = CGFloat(origin.centerX)
        let cy = CGFloat(origin.centerY)
        let left = CGFloat(origin.x)
        let top = CGFloat(origin.y)
        let right = left + CGFloat(origin.width)
        let bottom = top + CGFloat(origin.height)
        let minW = max(CGFloat(minCrop), CGFloat(minCrop) * ratio)
        let minH = max(CGFloat(minCrop), CGFloat(minCrop) / ratio)

        var w: CGFloat
        var h: CGFloat
        var x: CGFloat
        var y: CGFloat

        switch mode {
        case .e, .w:
            w = mode == .e ? mouse.x - left : right - mouse.x
            let maxHCentered = max(minH, 2 * min(cy, maxH - cy))
            let maxWFit = min(mode == .e ? maxW - left : right, maxHCentered * ratio)
            w = min(max(minW, w), maxWFit)
            h = w / ratio
            x = mode == .e ? left : right - w
            y = cy - h / 2
        case .n, .s:
            h = mode == .s ? mouse.y - top : bottom - mouse.y
            let maxWCentered = max(minW, 2 * min(cx, maxW - cx))
            let maxHFit = min(mode == .s ? maxH - top : bottom, maxWCentered / ratio)
            h = min(max(minH, h), maxHFit)
            w = h * ratio
            y = mode == .s ? top : bottom - h
            x = cx - w / 2
        default:
            return crop
        }

        var next = origin
        next.width = max(minCrop, Int(w.rounded()))
        next.height = max(minCrop, Int(h.rounded()))
        next.x = Int(x.rounded())
        next.y = Int(y.rounded())
        next.x = max(0, min(next.x, Int(maxW) - next.width))
        next.y = max(0, min(next.y, Int(maxH) - next.height))
        return next
    }

    private func clamp(_ c: CropRect) -> CropRect {
        var c = c
        c.clamp(in: videoSize)
        return c
    }

    private func clampResize(_ c: CropRect, mode: Mode) -> CropRect {
        var c = c
        guard videoSize.width > 0 else { return c }
        let ax = anchor.x, ay = anchor.y
        let maxW = videoSize.width
        let maxH = videoSize.height

        c.width = max(minCrop, c.width)
        c.height = max(minCrop, c.height)

        let maxWHere: CGFloat
        let maxHHere: CGFloat
        switch mode {
        case .se, .e, .s: maxWHere = maxW - ax; maxHHere = maxH - ay
        case .nw, .n, .w: maxWHere = ax; maxHHere = ay
        case .ne: maxWHere = maxW - ax; maxHHere = ay
        case .sw: maxWHere = ax; maxHHere = maxH - ay
        default: maxWHere = maxW; maxHHere = maxH
        }

        switch resizeLock {
        case .square:
            var side = CGFloat(min(c.width, c.height))
            side = min(side, min(maxWHere, maxHHere))
            side = max(CGFloat(minCrop), side)
            c.width = Int(side.rounded())
            c.height = c.width
        case .ratio(let rw, let rh):
            let ratio = Double(rw) / Double(rh)
            var w = Double(c.width)
            var h = Double(c.height)
            if w / max(h, 1) > ratio {
                h = w / ratio
            } else {
                w = h * ratio
            }
            if w > Double(maxWHere) { w = Double(maxWHere); h = w / ratio }
            if h > Double(maxHHere) { h = Double(maxHHere); w = h * ratio }
            c.width = max(minCrop, Int(w.rounded()))
            c.height = max(minCrop, Int(h.rounded()))
        case .free:
            c.width = min(c.width, max(minCrop, Int(maxWHere)))
            c.height = min(c.height, max(minCrop, Int(maxHHere)))
        }

        switch mode {
        case .se:
            c.x = Int(ax.rounded()); c.y = Int(ay.rounded())
        case .e:
            c.x = Int(ax.rounded())
        case .s:
            c.y = Int(ay.rounded())
        case .nw:
            c.x = Int(ax.rounded()) - c.width
            c.y = Int(ay.rounded()) - c.height
        case .w:
            c.x = Int(ax.rounded()) - c.width
        case .n:
            c.y = Int(ay.rounded()) - c.height
        case .ne:
            c.x = Int(ax.rounded())
            c.y = Int(ay.rounded()) - c.height
        case .sw:
            c.x = Int(ax.rounded()) - c.width
            c.y = Int(ay.rounded())
        default:
            return clamp(c)
        }

        c.x = max(0, min(c.x, Int(maxW) - c.width))
        c.y = max(0, min(c.y, Int(maxH) - c.height))
        return c
    }

    private func apply(_ next: CropRect, commit: Bool) {
        guard next != crop else {
            if commit { coordinator?.commit(next) }
            return
        }
        crop = next
        needsDisplay = true
        if commit {
            coordinator?.commit(next)
        }
    }
}
