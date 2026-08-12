import AppKit
import SwiftUI

struct CropOverlayView: NSViewRepresentable {
    var videoSize: CGSize
    @Binding var crop: CropRect
    var accent: NSColor = NSColor(red: 0.12, green: 0.72, blue: 0.68, alpha: 1)
    var onInteractionChange: ((Bool) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(crop: $crop, onInteractionChange: onInteractionChange)
    }

    func makeNSView(context: Context) -> CropCanvasView {
        let view = CropCanvasView()
        view.coordinator = context.coordinator
        view.accent = accent
        view.videoSize = videoSize
        view.crop = crop
        return view
    }

    func updateNSView(_ nsView: CropCanvasView, context: Context) {
        context.coordinator.crop = $crop
        context.coordinator.onInteractionChange = onInteractionChange
        nsView.accent = accent
        nsView.videoSize = videoSize
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
        init(crop: Binding<CropRect>, onInteractionChange: ((Bool) -> Void)?) {
            self.crop = crop
            self.onInteractionChange = onInteractionChange
        }
        func commit(_ value: CropRect) {
            if crop.wrappedValue != value {
                crop.wrappedValue = value
            }
        }
        func setInteracting(_ active: Bool) {
            onInteractionChange?(active)
        }
    }
}

final class CropCanvasView: NSView {
    weak var coordinator: CropOverlayView.Coordinator?
    var accent: NSColor = .systemTeal
    var videoSize: CGSize = .zero {
        didSet { if oldValue != videoSize { needsDisplay = true } }
    }
    var crop = CropRect.default {
        didSet { needsDisplay = true }
    }

    private enum Mode { case none, move, nw, ne, sw, se, place }
    private var mode: Mode = .none
    private var origin = CropRect.default
    private var anchor = CGPoint.zero
    private var startPoint = CGPoint.zero
    private let handleRadius: CGFloat = 6
    private let minCrop = 16
    private var scrollCommitWork: DispatchWorkItem?

    var isInteracting: Bool { mode != .none }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }

    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        needsDisplay = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        needsDisplay = true
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
        let letter = letterbox(in: bounds.size)
        let scale = letter.width / videoSize.width
        let r = viewRect(letter: letter, scale: scale)

        let dim = NSColor.black.withAlphaComponent(0.48)
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

        accent.setFill()
        NSColor.white.setStroke()
        for p in [CGPoint(x: r.minX, y: r.minY),
                  CGPoint(x: r.maxX, y: r.minY),
                  CGPoint(x: r.minX, y: r.maxY),
                  CGPoint(x: r.maxX, y: r.maxY)] {
            let hr = NSRect(x: p.x - handleRadius, y: p.y - handleRadius,
                            width: handleRadius * 2, height: handleRadius * 2)
            let h = NSBezierPath(ovalIn: hr)
            h.fill()
            h.lineWidth = 1.5
            h.stroke()
        }

        let off = crop.centerOffset(in: videoSize)
        let label = "\(crop.size)×\(crop.size)  ·  Δ\(off.dx),\(off.dy)" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = label.size(withAttributes: attrs)
        let labelOrigin = CGPoint(x: r.minX, y: max(4, r.minY - size.height - 6))
        let bg = NSRect(x: labelOrigin.x - 4, y: labelOrigin.y - 2,
                        width: size.width + 8, height: size.height + 4)
        NSColor.black.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: bg, xRadius: 4, yRadius: 4).fill()
        label.draw(at: labelOrigin, withAttributes: attrs)
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

        if hitHandle(.nw, in: r, point: p) { beginResize(.nw); return }
        if hitHandle(.ne, in: r, point: p) { beginResize(.ne); return }
        if hitHandle(.sw, in: r, point: p) { beginResize(.sw); return }
        if hitHandle(.se, in: r, point: p) { beginResize(.se); return }

        if r.insetBy(dx: -4, dy: -4).contains(p) {
            mode = .move
            coordinator?.setInteracting(true)
            return
        }

        mode = .place
        coordinator?.setInteracting(true)
        let vx = Int((p.x - letter.minX) / scale) - crop.size / 2
        let vy = Int((p.y - letter.minY) / scale) - crop.size / 2
        var next = crop
        next.x = vx
        next.y = vy
        apply(clamp(next), commit: true)
    }

    override func mouseDragged(with event: NSEvent) {
        guard videoSize.width > 0, mode != .none, mode != .place else { return }
        let p = convert(event.locationInWindow, from: nil)
        let letter = letterbox(in: bounds.size)
        let scale = letter.width / videoSize.width
        guard scale > 0 else { return }

        if mode == .move {
            let dx = (p.x - startPoint.x) / scale
            let dy = (p.y - startPoint.y) / scale
            var next = origin
            next.x = Int((Double(origin.x) + dx).rounded())
            next.y = Int((Double(origin.y) + dy).rounded())
            apply(clamp(next), commit: false)
            return
        }

        let mx = (p.x - letter.minX) / scale
        let my = (p.y - letter.minY) / scale
        apply(resize(mode: mode, mouse: CGPoint(x: mx, y: my)), commit: false)
    }

    override func mouseUp(with event: NSEvent) {
        if mode == .move || mode == .nw || mode == .ne || mode == .sw || mode == .se {
            coordinator?.commit(crop)
        }
        mode = .none
        coordinator?.setInteracting(false)
    }

    override func scrollWheel(with event: NSEvent) {
        guard videoSize.width > 0 else { return }
        let delta = event.scrollingDeltaY
        guard abs(delta) > 0.1 else { return }
        coordinator?.setInteracting(true)
        let step = abs(delta) >= 1 ? 24 : 8
        let cx = crop.x + crop.size / 2
        let cy = crop.y + crop.size / 2
        var next = crop
        next.size += delta > 0 ? step : -step
        next = clamp(next)
        next.x = cx - next.size / 2
        next.y = cy - next.size / 2
        apply(clamp(next), commit: false)

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
        let scale = letter.width / videoSize.width
        let r = viewRect(letter: letter, scale: scale)
        addCursorRect(r, cursor: .openHand)
        for (m, _) in handlePoints(r) {
            let cursor: NSCursor
            switch m {
            case .nw, .se: cursor = .crosshair
            case .ne, .sw: cursor = .crosshair
            default: cursor = .arrow
            }
            let hr = handleRect(m, in: r)
            addCursorRect(hr, cursor: cursor)
        }
    }

    // MARK: - Geometry

    private func letterbox(in size: CGSize) -> CGRect {
        CropGeometry.letterbox(videoSize: videoSize, in: size)
    }

    private func viewRect(letter: CGRect, scale: CGFloat) -> CGRect {
        CropGeometry.viewRect(crop: crop, letter: letter, videoSize: videoSize)
    }

    private func handlePoints(_ r: CGRect) -> [(Mode, CGPoint)] {
        [(.nw, CGPoint(x: r.minX, y: r.minY)),
         (.ne, CGPoint(x: r.maxX, y: r.minY)),
         (.sw, CGPoint(x: r.minX, y: r.maxY)),
         (.se, CGPoint(x: r.maxX, y: r.maxY))]
    }

    private func handleRect(_ m: Mode, in r: CGRect) -> CGRect {
        let p = handlePoints(r).first { $0.0 == m }?.1 ?? .zero
        let pad: CGFloat = 10
        return CGRect(x: p.x - pad, y: p.y - pad, width: pad * 2, height: pad * 2)
    }

    private func hitHandle(_ m: Mode, in r: CGRect, point: CGPoint) -> Bool {
        handleRect(m, in: r).contains(point)
    }

    private func beginResize(_ m: Mode) {
        mode = m
        coordinator?.setInteracting(true)
        let ox = CGFloat(crop.x), oy = CGFloat(crop.y), osz = CGFloat(crop.size)
        switch m {
        case .se: anchor = CGPoint(x: ox, y: oy)
        case .nw: anchor = CGPoint(x: ox + osz, y: oy + osz)
        case .ne: anchor = CGPoint(x: ox, y: oy + osz)
        case .sw: anchor = CGPoint(x: ox + osz, y: oy)
        default: break
        }
    }

    private func resize(mode: Mode, mouse: CGPoint) -> CropRect {
        let ax = anchor.x, ay = anchor.y
        var next = origin
        var newSize: CGFloat = 0
        switch mode {
        case .se:
            newSize = max(mouse.x - ax, mouse.y - ay)
            next.x = Int(ax.rounded()); next.y = Int(ay.rounded())
        case .nw:
            newSize = max(ax - mouse.x, ay - mouse.y)
            next.x = Int((ax - newSize).rounded()); next.y = Int((ay - newSize).rounded())
        case .ne:
            newSize = max(mouse.x - ax, ay - mouse.y)
            next.x = Int(ax.rounded()); next.y = Int((ay - newSize).rounded())
        case .sw:
            newSize = max(ax - mouse.x, mouse.y - ay)
            next.x = Int((ax - newSize).rounded()); next.y = Int(ay.rounded())
        default:
            return crop
        }
        next.size = Int(newSize.rounded())
        return clampResize(next, mode: mode)
    }

    private var maxSize: Int {
        Int(min(videoSize.width, videoSize.height))
    }

    private func clamp(_ c: CropRect) -> CropRect {
        var c = c
        guard videoSize.width > 0 else { return c }
        c.size = max(minCrop, min(c.size, maxSize))
        c.x = max(0, min(c.x, Int(videoSize.width) - c.size))
        c.y = max(0, min(c.y, Int(videoSize.height) - c.size))
        return c
    }

    private func clampResize(_ c: CropRect, mode: Mode) -> CropRect {
        var c = c
        guard videoSize.width > 0 else { return c }
        let ax = anchor.x, ay = anchor.y
        let maxS = CGFloat(maxSize)
        switch mode {
        case .se:
            let maxHere = min(maxS, videoSize.width - ax, videoSize.height - ay)
            c.size = max(minCrop, min(c.size, Int(maxHere)))
            c.x = Int(ax.rounded()); c.y = Int(ay.rounded())
        case .nw:
            let maxHere = min(maxS, ax, ay)
            c.size = max(minCrop, min(c.size, Int(maxHere)))
            c.x = Int(ax.rounded()) - c.size
            c.y = Int(ay.rounded()) - c.size
        case .ne:
            let maxHere = min(maxS, videoSize.width - ax, ay)
            c.size = max(minCrop, min(c.size, Int(maxHere)))
            c.x = Int(ax.rounded())
            c.y = Int(ay.rounded()) - c.size
        case .sw:
            let maxHere = min(maxS, ax, videoSize.height - ay)
            c.size = max(minCrop, min(c.size, Int(maxHere)))
            c.x = Int(ax.rounded()) - c.size
            c.y = Int(ay.rounded())
        default:
            return clamp(c)
        }
        c.x = max(0, min(c.x, Int(videoSize.width) - c.size))
        c.y = max(0, min(c.y, Int(videoSize.height) - c.size))
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
