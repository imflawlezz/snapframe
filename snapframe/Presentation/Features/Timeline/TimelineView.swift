import SwiftUI

struct TimelineView: View {
    var duration: Double
    var position: Double
    var fps: Double
    var isPlaying: Bool
    var markers: [TimelineMarker]
    var seekInput: Binding<String>
    var jumpMode: Binding<JumpMode>
    var onSeek: (Double, Bool) -> Void
    var onMarker: (String) -> Void
    var onJumpSubmit: () -> Void

    @State private var dragging = false
    @State private var dragPosition: Double = 0
    @State private var jumpedToMarker = false
    @State private var zoom: Double = 1
    @State private var viewStart: Double = 0
    @State private var scrollbarDragging = false
    @State private var scrollbarDragOrigin: Double = 0

    private let rulerHeight: CGFloat = 24
    private let trackHeight: CGFloat = 40
    private let scrollbarHeight: CGFloat = 12

    private var shown: Double { dragging ? dragPosition : position }
    private var visibleDuration: Double {
        guard duration > 0 else { return 1 }
        return max(duration / max(zoom, 1), 1 / max(fps, 1))
    }
    private var visibleEnd: Double { min(duration, viewStart + visibleDuration) }
    private var canPan: Bool { duration > 0 && visibleDuration < duration - 0.001 }

    var body: some View {
        VStack(spacing: 6) {
            seekRow
            timelineBody
            if duration > 0 {
                timelineScrollbar
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .onChange(of: duration) { _, _ in
            zoom = 1
            viewStart = 0
        }
        .onChange(of: position) { _, pos in
            if !isPlaying { keepPlayheadVisible(pos) }
        }
    }

    // MARK: - Seek row

    private var seekRow: some View {
        HStack(spacing: 8) {
            SegmentToggle(selection: jumpMode)

            DigitsTextField(
                text: seekInput,
                placeholder: jumpMode.wrappedValue == .time ? "00:00:00.000" : "frame #",
                allowsTimecodeChars: jumpMode.wrappedValue == .time,
                font: .monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                textColor: NSColor(SnapTheme.fieldText),
                alignment: .left,
                onCommit: onJumpSubmit
            )
            .padding(.horizontal, 8)
            .frame(height: 28)
            .frame(maxWidth: 160)
            .background(SnapTheme.fieldBg)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(SnapTheme.stroke, lineWidth: 1)
            )

            Button(action: onJumpSubmit) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(SnapTheme.accent)
            }
            .buttonStyle(.plain)
            .snapTooltip("Go to timecode", shortcut: "G")

            Spacer()

            HStack(spacing: 16) {
                zoomControls

                HStack(spacing: 4) {
                    Text(jumpMode.wrappedValue == .time
                         ? Timecode.format(shown)
                         : "f\(Timecode.frameIndex(at: shown, fps: fps))")
                        .font(SnapTheme.mono)
                        .foregroundStyle(SnapTheme.ink)

                    Text("/")
                        .foregroundStyle(SnapTheme.inkSecondary.opacity(0.4))

                    Text(jumpMode.wrappedValue == .time
                         ? Timecode.format(duration)
                         : "f\(Timecode.frameIndex(at: duration, fps: fps))")
                        .font(SnapTheme.mono)
                        .foregroundStyle(SnapTheme.inkSecondary.opacity(0.6))
                }
            }
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 12) {
            Text(zoomLabel)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(SnapTheme.inkSecondary)
                .frame(width: 36, alignment: .trailing)

            HStack(spacing: 4) {
            Button { adjustZoom(by: 0.8, anchor: shown) } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(ToolButtonStyle(width: 28, height: 26))
            .disabled(duration <= 0)
            .snapTooltip("Zoom out", shortcut: "⇧Scroll")

            Button { resetZoom() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(ToolButtonStyle(width: 28, height: 26))
            .disabled(duration <= 0 || zoom <= 1.01)
            .snapTooltip("Fit timeline to window")

            Button { adjustZoom(by: 1.25, anchor: shown) } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(ToolButtonStyle(width: 28, height: 26))
            .disabled(duration <= 0)
            .snapTooltip("Zoom in", shortcut: "⇧Scroll")
            }
        }
        .opacity(duration <= 0 ? 0.4 : 1)
    }

    private func resetZoom() {
        zoom = 1
        viewStart = 0
    }

    private var zoomLabel: String {
        zoom <= 1.01 ? "Fit" : String(format: "%.0f×", zoom)
    }

    // MARK: - Timeline body

    private var timelineBody: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            let track = CGRect(x: 0, y: rulerHeight, width: width, height: trackHeight)
            let fullHeight = rulerHeight + trackHeight

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(SnapTheme.timelineSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(SnapTheme.stroke, lineWidth: 1)
                    )
                    .frame(height: fullHeight)

                rulerLayer(track: track, fullHeight: fullHeight)
                trackLayer(track: track)
                markerLayer(track: track)
                playheadLayer(track: track, fullHeight: fullHeight)

                ScrollWheelCapture { delta, shift, localX in
                    handleWheel(delta: delta, shift: shift, localX: localX, trackWidth: width)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .gesture(scrubGesture(track: track))
            .onTapGesture(count: 2) {
                resetZoom()
            }
        }
        .frame(height: rulerHeight + trackHeight)
    }

    private var timelineScrollbar: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            let metrics = scrollbarMetrics(width: width)
            let playheadX = metrics.playheadX

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(SnapTheme.chip)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(SnapTheme.stroke.opacity(0.45), lineWidth: 0.5)
                    )

                RoundedRectangle(cornerRadius: 3)
                    .fill(SnapTheme.slate.opacity(scrollbarDragging ? 0.7 : 0.45))
                    .frame(width: metrics.thumbWidth, height: scrollbarHeight - 4)
                    .offset(x: metrics.thumbX, y: 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !scrollbarDragging {
                                    scrollbarDragging = true
                                    scrollbarDragOrigin = viewStart
                                }
                                let span = max(duration - visibleDuration, 0)
                                let travel = max(1, width - metrics.thumbWidth)
                                let deltaT = Double(value.translation.width / travel) * span
                                viewStart = clampStart(scrollbarDragOrigin + deltaT)
                            }
                            .onEnded { _ in
                                scrollbarDragging = false
                            }
                    )

                RoundedRectangle(cornerRadius: 1)
                    .fill(SnapTheme.timelinePlayheadStem)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1)
                            .strokeBorder(SnapTheme.ink.opacity(0.35), lineWidth: 0.5)
                    )
                    .frame(width: 2, height: scrollbarHeight)
                    .offset(x: max(0, min(width - 2, playheadX - 1)))
                    .allowsHitTesting(false)
            }
        }
        .frame(height: scrollbarHeight)
        .padding(.top, 2)
    }

    private struct ScrollbarMetrics {
        var thumbX: CGFloat
        var thumbWidth: CGFloat
        var playheadX: CGFloat
    }

    private func scrollbarMetrics(width: CGFloat) -> ScrollbarMetrics {
        guard duration > 0 else {
            return ScrollbarMetrics(thumbX: 0, thumbWidth: width, playheadX: 0)
        }
        let viewportFrac = min(1, visibleDuration / duration)
        let thumbW = max(2, width * viewportFrac)
        let maxThumbX = max(0, width - thumbW)
        let thumbX = canPan
            ? CGFloat(viewStart / max(duration - visibleDuration, 0.001)) * maxThumbX
            : 0
        let playheadX = CGFloat(shown / duration) * width
        return ScrollbarMetrics(
            thumbX: min(maxThumbX, max(0, thumbX)),
            thumbWidth: canPan ? thumbW : width,
            playheadX: playheadX
        )
    }

    // MARK: - Layers

    private func rulerLayer(track: CGRect, fullHeight: CGFloat) -> some View {
        let layout = rulerLayout(trackWidth: track.width)
        return Canvas { context, _ in
            guard duration > 0 else { return }

            var t = layout.start
            var labelIndex = 0
            var lastLabelX: CGFloat = -1000
            while t <= visibleEnd + layout.minorStep * 0.5 {
                let x = xPos(t, track: track)
                let major = labelIndex % layout.majorEvery == 0
                let tickH: CGFloat = major ? 9 : 4
                var path = Path()
                path.move(to: CGPoint(x: x, y: 2))
                path.addLine(to: CGPoint(x: x, y: 2 + tickH))
                context.stroke(
                    path,
                    with: .color(major ? SnapTheme.timelineGridMajor : SnapTheme.timelineGridMinor),
                    lineWidth: major ? 1 : 0.5
                )

                if major, layout.showLabels, x > 28, x < track.width - 28,
                   x - lastLabelX >= layout.minLabelPx {
                    context.draw(
                        Text(Timecode.format(t))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(SnapTheme.inkSecondary),
                        at: CGPoint(x: x, y: 13),
                        anchor: .center
                    )
                    lastLabelX = x
                }

                t += layout.minorStep
                labelIndex += 1
            }

            var baseline = Path()
            baseline.move(to: CGPoint(x: 0, y: rulerHeight - 0.5))
            baseline.addLine(to: CGPoint(x: track.width, y: rulerHeight - 0.5))
            context.stroke(baseline, with: .color(SnapTheme.stroke.opacity(0.6)), lineWidth: 1)
        }
        .frame(height: fullHeight)
        .allowsHitTesting(false)
    }

    private struct RulerLayout {
        var minorStep: Double
        var majorEvery: Int
        var showLabels: Bool
        var minLabelPx: CGFloat
        var start: Double
    }

    private func rulerLayout(trackWidth: CGFloat) -> RulerLayout {
        let minLabelPx: CGFloat = 96
        let minMajorPx: CGFloat = 28
        let frameDur = 1 / max(fps, 24)
        var candidates: [Double] = [
            frameDur, frameDur * 2, frameDur * 5, frameDur * 10,
            0.25, 0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600
        ].uniqued().sorted()

        var minorStep = max(duration / 10, frameDur)
        for step in candidates {
            let px = CGFloat(step / visibleDuration) * trackWidth
            if px >= minMajorPx {
                minorStep = step
                break
            }
        }

        let majorPx = CGFloat(minorStep / visibleDuration) * trackWidth
        let majorEvery = max(1, Int(ceil(minLabelPx / max(majorPx, 1))))
        let start = floor(viewStart / minorStep) * minorStep
        return RulerLayout(
            minorStep: minorStep,
            majorEvery: majorEvery,
            showLabels: duration > 0,
            minLabelPx: minLabelPx,
            start: start
        )
    }

    private func trackLayer(track: CGRect) -> some View {
        let layout = rulerLayout(trackWidth: track.width)
        return Canvas { context, _ in
            guard duration > 0 else { return }
            let band = CGRect(x: 0, y: track.minY, width: track.width, height: track.height)
            context.fill(
                Path(roundedRect: band, cornerRadius: 0),
                with: .color(SnapTheme.timelineTrack)
            )

            let timePx = CGFloat(layout.minorStep / visibleDuration) * track.width
            if timePx >= 3 {
                var t = layout.start
                var tickIndex = 0
                while t <= visibleEnd + layout.minorStep * 0.5 {
                    let x = xPos(t, track: track)
                    let major = tickIndex % layout.majorEvery == 0
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: track.minY + 2))
                    path.addLine(to: CGPoint(x: x, y: track.maxY - 2))
                    context.stroke(
                        path,
                        with: .color(major ? SnapTheme.timelineGridMajor : SnapTheme.timelineGridMinor),
                        lineWidth: major ? 1 : 0.5
                    )
                    t += layout.minorStep
                    tickIndex += 1
                }
            }

            if fps > 0 {
                let frameDur = 1 / fps
                let ppf = track.width / visibleDuration * frameDur
                if ppf >= 10 {
                    var t = ceil(viewStart / frameDur) * frameDur
                    while t <= visibleEnd {
                        let x = xPos(t, track: track)
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: track.minY + 2))
                        path.addLine(to: CGPoint(x: x, y: track.maxY - 2))
                        context.stroke(path, with: .color(SnapTheme.timelineGridMinor.opacity(0.55)), lineWidth: 0.5)
                        t += frameDur
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func markerLayer(track: CGRect) -> some View {
        ZStack {
            ForEach(markers) { m in
                markerView(m, track: track)
            }
        }
        .allowsHitTesting(false)
    }

    private func playheadLayer(track: CGRect, fullHeight: CGFloat) -> some View {
        Group {
            if duration > 0 {
                let x = xPos(shown, track: track)
                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: x - 5, y: 2))
                        path.addLine(to: CGPoint(x: x + 5, y: 2))
                        path.addLine(to: CGPoint(x: x, y: 9))
                        path.closeSubpath()
                    }
                    .fill(SnapTheme.accent)

                    Rectangle()
                        .fill(SnapTheme.timelinePlayheadStem)
                        .frame(width: 2, height: fullHeight - 2)
                        .position(x: x, y: fullHeight / 2 + 1)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Interaction

    private func scrubGesture(track: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard duration > 0 else { return }
                let t = snapFrame(time(at: value.location.x, track: track))
                if !dragging {
                    if let m = hitMarker(at: value.location.x, track: track), let cid = m.cueID {
                        onMarker(cid)
                        dragging = true
                        jumpedToMarker = true
                        dragPosition = t
                        return
                    }
                    dragging = true
                    jumpedToMarker = false
                    dragPosition = t
                    onSeek(t, false)
                    return
                }
                if jumpedToMarker { return }
                dragPosition = t
                onSeek(t, false)
            }
            .onEnded { value in
                guard duration > 0 else { return }
                defer {
                    dragging = false
                    jumpedToMarker = false
                }
                if jumpedToMarker { return }
                let t = snapFrame(time(at: value.location.x, track: track))
                dragPosition = t
                onSeek(t, true)
            }
    }

    private func handleWheel(delta: CGFloat, shift: Bool, localX: CGFloat, trackWidth: CGFloat) {
        guard duration > 0 else { return }
        if shift {
            zoomAtCursor(delta: delta, cursorX: localX, trackWidth: trackWidth)
        } else if canPan {
            let panAmount = visibleDuration * 0.08 * Double(delta)
            viewStart = clampStart(viewStart - panAmount)
        }
    }

    private func zoomAtCursor(delta: CGFloat, cursorX: CGFloat, trackWidth: CGFloat) {
        let anchorFrac = Double(min(1, max(0, cursorX / trackWidth)))
        let anchorTime = viewStart + anchorFrac * visibleDuration
        let factor = delta > 0 ? 1.12 : 0.89
        adjustZoom(to: min(512, max(1, zoom * factor)), anchor: anchorTime, anchorFrac: anchorFrac)
    }

    private func adjustZoom(by factor: Double, anchor: Double) {
        adjustZoom(to: min(512, max(1, zoom * factor)), anchor: anchor)
    }

    private func adjustZoom(to newZoom: Double, anchor: Double, anchorFrac: Double? = nil) {
        guard duration > 0 else { return }
        let oldVisible = visibleDuration
        let frac = anchorFrac ?? (oldVisible > 0 ? (anchor - viewStart) / oldVisible : 0.5)
        zoom = newZoom
        let newVisible = max(duration / zoom, 1 / max(fps, 1))
        if newVisible >= duration - 0.001 {
            viewStart = 0
        } else {
            viewStart = clampStart(anchor - frac * newVisible)
        }
    }

    private func keepPlayheadVisible(_ pos: Double) {
        guard canPan, !dragging else { return }
        let margin = visibleDuration * 0.08
        if pos < viewStart + margin {
            viewStart = clampStart(pos - margin)
        } else if pos > visibleEnd - margin {
            viewStart = clampStart(pos - visibleDuration + margin)
        }
    }

    // MARK: - Geometry

    private func time(at x: CGFloat, track: CGRect) -> Double {
        let frac = Double(min(1, max(0, (x - track.minX) / track.width)))
        return viewStart + frac * visibleDuration
    }

    private func xPos(_ t: Double, track: CGRect) -> CGFloat {
        guard visibleDuration > 0 else { return track.minX }
        let frac = (t - viewStart) / visibleDuration
        return track.minX + track.width * CGFloat(min(1, max(0, frac)))
    }

    private func snapFrame(_ t: Double) -> Double {
        guard fps > 0 else { return t }
        let frame = round(t * fps)
        return min(max(0, frame / fps), max(0, duration - 1 / fps))
    }

    private func clampStart(_ start: Double) -> Double {
        let maxStart = max(0, duration - visibleDuration)
        return min(max(0, start), maxStart)
    }

    private func hitMarker(at x: CGFloat, track: CGRect) -> TimelineMarker? {
        markers.min(by: { abs(xPos($0.t, track: track) - x) < abs(xPos($1.t, track: track) - x) })
            .flatMap { abs(xPos($0.t, track: track) - x) < 10 ? $0 : nil }
    }

    @ViewBuilder
    private func markerView(_ m: TimelineMarker, track: CGRect) -> some View {
        let x = xPos(m.t, track: track)
        let color: Color = switch m.kind {
        case .crop: SnapTheme.warn
        case .cueDone: SnapTheme.good
        case .cueActive: SnapTheme.ink
        case .cuePending: SnapTheme.warn.opacity(0.55)
        }
        VStack(spacing: 0) {
            Rectangle()
                .fill(color.opacity(0.9))
                .frame(width: m.kind == .cueActive ? 2 : 1.5, height: track.height - 4)
        }
        .position(x: x, y: track.midY)
    }
}

private extension Array where Element == Double {
    func uniqued() -> [Double] {
        var seen = Set<Double>()
        return filter { seen.insert($0).inserted }
    }
}

struct SegmentToggle: View {
    @Binding var selection: JumpMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(JumpMode.allCases) { mode in
                Button {
                    withAnimation(SnapMotion.fast) { selection = mode }
                } label: {
                    Text(mode.label)
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 48, height: 26)
                }
                .buttonStyle(SegmentButtonStyle(active: selection == mode))
            }
        }
        .background(SnapTheme.chip)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(SnapTheme.stroke, lineWidth: 1))
    }
}

private struct SegmentButtonStyle: ButtonStyle {
    var active: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(active ? Color.white : SnapTheme.ink)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(active ? SnapTheme.accent : Color.clear)
                    .padding(2)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(SnapMotion.fast, value: configuration.isPressed)
    }
}
