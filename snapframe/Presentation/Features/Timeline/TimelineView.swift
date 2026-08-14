import SwiftUI

struct TimelineView: View {
    var duration: Double
    var position: Double
    var fps: Double
    var isPlaying: Bool
    var markers: [TimelineMarker]
    var seekInput: Binding<String>
    var jumpMode: Binding<JumpMode>
    @Binding var followPlayhead: Bool
    @Binding var snapToCues: Bool
    var onSeek: (Double, Bool) -> Void
    var onJumpSubmit: () -> Void
    var snapSeek: (Double) -> Double = { $0 }

    @State private var dragging = false
    @State private var dragPosition: Double = 0
    @State private var zoom: Double = 1
    @State private var viewStart: Double = 0
    @State private var scrollbarDragging = false
    @State private var scrollbarDragOrigin: Double = 0
    @State private var lastScrubPreviewAt: Date = .distantPast

    private let rulerHeight: CGFloat = 24
    private let trackHeight: CGFloat = 40
    private let scrollbarHeight: CGFloat = 12
    private let followMarginFraction = 0.14

    private var shown: Double {
        dragging ? dragPosition : snapFrame(position)
    }
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
            if followPlayhead {
                keepPlayheadVisible(snapFrame(pos))
            }
        }
        .onChange(of: followPlayhead) { _, following in
            if following {
                withAnimation(SnapMotion.scroll) {
                    revealPlayhead(shown)
                }
            }
        }
    }

    // MARK: - Seek row

    private var seekRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                followPlayheadButton
                snapToCuesButton
            }

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

    private var followPlayheadButton: some View {
        Button {
            followPlayhead.toggle()
        } label: {
            Image(systemName: "guidepoint.vertical.arrowtriangle.forward")
                .font(.system(size: 11, weight: .semibold))
        }
        .buttonStyle(ToolButtonStyle(
            kind: followPlayhead ? .accent : .normal,
            width: 28,
            height: 26
        ))
        .disabled(duration <= 0 || !canPan)
        .opacity(duration <= 0 || !canPan ? 0.4 : 1)
        .snapTooltip("Follow playhead", shortcut: "P")
    }

    private var snapToCuesButton: some View {
        Button {
            snapToCues.toggle()
        } label: {
            Image(systemName: "arrowtriangle.right.and.line.vertical.and.arrowtriangle.left.fill")
                .font(.system(size: 11, weight: .semibold))
        }
        .buttonStyle(ToolButtonStyle(
            kind: snapToCues ? .accent : .normal,
            width: 28,
            height: 26
        ))
        .disabled(duration <= 0)
        .opacity(duration <= 0 ? 0.4 : 1)
        .snapTooltip("Snap to cues", shortcut: "S")
    }

    private var zoomControls: some View {
        HStack(spacing: 12) {
            Text(zoomLabel)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(SnapTheme.inkSecondary)
                .frame(width: 36, alignment: .trailing)

            HStack(spacing: 4) {
            Button {
                withAnimation(SnapMotion.scroll) { adjustZoom(by: 0.8, anchor: shown) }
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(ToolButtonStyle(width: 28, height: 26))
            .disabled(duration <= 0)
            .snapTooltip("Zoom out", shortcut: "⇧Scroll")

            Button {
                withAnimation(SnapMotion.scroll) { resetZoom() }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(ToolButtonStyle(width: 28, height: 26))
            .disabled(duration <= 0 || zoom <= 1.01)
            .snapTooltip("Fit timeline to window")

            Button {
                withAnimation(SnapMotion.scroll) { adjustZoom(by: 1.25, anchor: shown) }
            } label: {
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

                rulerTicks(track: track, fullHeight: fullHeight)
                trackLayer(track: track)
                rulerLabels(track: track, fullHeight: fullHeight)
                markerLayer(track: track)
                playheadLayer(track: track, fullHeight: fullHeight)
                ScrollWheelCapture { event in
                    handleWheel(event, trackWidth: width)
                }
            }
            .frame(width: width, height: fullHeight)
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
                    .contentShape(Rectangle())
                    .gesture(scrollbarGesture(width: width, thumbWidth: metrics.thumbWidth, jumpOnDown: true))

                RoundedRectangle(cornerRadius: 3)
                    .fill(SnapTheme.slate.opacity(scrollbarDragging ? 0.7 : 0.45))
                    .frame(width: metrics.thumbWidth, height: scrollbarHeight - 4)
                    .offset(x: metrics.thumbX, y: 2)
                    .gesture(scrollbarGesture(width: width, thumbWidth: metrics.thumbWidth, jumpOnDown: false))

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

    private func scrollbarGesture(width: CGFloat, thumbWidth: CGFloat, jumpOnDown: Bool) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard canPan else { return }
                if !scrollbarDragging {
                    scrollbarDragging = true
                    if followPlayhead { followPlayhead = false }
                    if jumpOnDown {
                        viewStart = viewStart(placingThumbAt: value.startLocation.x, width: width, thumbWidth: thumbWidth)
                    }
                    scrollbarDragOrigin = viewStart
                }
                let span = max(duration - visibleDuration, 0)
                let travel = max(1, width - thumbWidth)
                let deltaT = Double(value.translation.width / travel) * span
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    viewStart = clampStart(scrollbarDragOrigin + deltaT)
                }
            }
            .onEnded { _ in
                scrollbarDragging = false
            }
    }

    private func viewStart(placingThumbAt x: CGFloat, width: CGFloat, thumbWidth: CGFloat) -> Double {
        let travel = max(1, width - thumbWidth)
        let thumbX = min(max(0, x - thumbWidth / 2), travel)
        let span = max(duration - visibleDuration, 0)
        guard span > 0 else { return 0 }
        return clampStart(Double(thumbX / travel) * span)
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

    private func rulerTicks(track: CGRect, fullHeight: CGFloat) -> some View {
        let layout = rulerLayout(trackWidth: track.width)
        return Canvas { context, _ in
            guard duration > 0, layout.minorStep > 0 else { return }
            for k in layout.firstTick...layout.lastTick {
                let t = Double(k) * layout.minorStep
                let x = xPos(t, track: track)
                let major = k % layout.labelEveryTicks == 0
                let tickH: CGFloat = major ? 9 : 4
                var path = Path()
                path.move(to: CGPoint(x: x, y: 2))
                path.addLine(to: CGPoint(x: x, y: 2 + tickH))
                context.stroke(
                    path,
                    with: .color(major ? SnapTheme.timelineGridMajor : SnapTheme.timelineGridMinor),
                    lineWidth: major ? 1 : 0.5
                )
            }
            var baseline = Path()
            baseline.move(to: CGPoint(x: 0, y: rulerHeight - 0.5))
            baseline.addLine(to: CGPoint(x: track.width, y: rulerHeight - 0.5))
            context.stroke(baseline, with: .color(SnapTheme.stroke.opacity(0.6)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }

    private func rulerLabels(track: CGRect, fullHeight: CGFloat) -> some View {
        let layout = rulerLayout(trackWidth: track.width)
        let showFrames = jumpMode.wrappedValue == .frame
        return ZStack(alignment: .topLeading) {
            if duration > 0, layout.labelStep > 0, layout.firstLabel <= layout.lastLabel {
                ForEach(layout.firstLabel...layout.lastLabel, id: \.self) { k in
                    let t = Double(k) * layout.labelStep
                    Text(showFrames
                         ? "f\(Timecode.frameIndex(at: t, fps: fps))"
                         : Timecode.format(t))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(SnapTheme.inkSecondary)
                        .position(x: xPos(t, track: track), y: 13)
                }
            }
        }
        .frame(width: track.width, height: fullHeight)
        .animation(nil, value: viewStart)
        .allowsHitTesting(false)
    }

    private struct RulerLayout {
        var minorStep: Double
        var labelStep: Double
        var labelEveryTicks: Int
        var firstTick: Int
        var lastTick: Int
        var firstLabel: Int
        var lastLabel: Int
    }

    private func rulerLayout(trackWidth: CGFloat) -> RulerLayout {
        let minLabelPx: CGFloat = jumpMode.wrappedValue == .frame ? 52 : 84
        let minTickPx: CGFloat = 8
        func px(_ step: Double) -> CGFloat {
            CGFloat(step / max(visibleDuration, 1e-9)) * trackWidth
        }

        let labelStep = niceRulerStep(minPx: minLabelPx, px: px)
        var minorStep = labelStep
        for divisor in [10, 5, 4, 2] {
            let step = labelStep / Double(divisor)
            if step > 0, px(step) >= minTickPx {
                minorStep = step
                break
            }
        }

        let labelEveryTicks = max(1, Int((labelStep / minorStep).rounded()))
        let firstTick = max(0, Int(floor(viewStart / minorStep)) - 1)
        let lastTick = max(firstTick, Int(ceil(visibleEnd / minorStep)) + 1)
        let firstLabel = max(0, Int(floor(viewStart / labelStep)) - 1)
        let durationCap = labelStep > 0 ? Int(floor((duration + 1e-9) / labelStep)) : 0
        let lastLabel = min(durationCap, max(firstLabel, Int(ceil(visibleEnd / labelStep)) + 1))
        return RulerLayout(
            minorStep: minorStep,
            labelStep: labelStep,
            labelEveryTicks: labelEveryTicks,
            firstTick: firstTick,
            lastTick: lastTick,
            firstLabel: firstLabel,
            lastLabel: lastLabel
        )
    }

    private func niceRulerStep(minPx: CGFloat, px: (Double) -> CGFloat) -> Double {
        let frameDur = fps > 0 ? 1 / fps : 1 / 24
        if jumpMode.wrappedValue == .frame {
            for n in [1, 2, 5, 10, 25, 50, 100, 250, 500, 1000] {
                let step = Double(n) * frameDur
                if px(step) >= minPx { return step }
            }
        }
        let steps: [Double] = [
            0.001, 0.002, 0.005, 0.01, 0.02, 0.05,
            0.1, 0.2, 0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 1800, 3600
        ]
        return steps.first { px($0) >= minPx } ?? steps.last!
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
            let frameDur = fps > 0 ? 1 / fps : 0
            let ppf = frameDur > 0 ? track.width / visibleDuration * frameDur : 0
            let showFrames = ppf >= 10

            if !showFrames, timePx >= 3 {
                for k in layout.firstTick...layout.lastTick {
                    let t = Double(k) * layout.minorStep
                    let x = xPos(t, track: track)
                    let major = k % layout.labelEveryTicks == 0
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: track.minY + 2))
                    path.addLine(to: CGPoint(x: x, y: track.maxY - 2))
                    context.stroke(
                        path,
                        with: .color(major ? SnapTheme.timelineGridMajor : SnapTheme.timelineGridMinor),
                        lineWidth: major ? 1 : 0.5
                    )
                }
            }

            if showFrames {
                let startFrame = Int(ceil(viewStart * fps - 1e-9))
                let endFrame = Int(floor(visibleEnd * fps + 1e-9))
                if startFrame <= endFrame {
                    for frame in startFrame...endFrame {
                        let x = xPos(Timecode.seconds(forFrame: frame, fps: fps), track: track)
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: track.minY + 2))
                        path.addLine(to: CGPoint(x: x, y: track.maxY - 2))
                        context.stroke(path, with: .color(SnapTheme.timelineGridMinor.opacity(0.55)), lineWidth: 0.5)
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
        let x = xPos(shown, track: track)
        return Canvas { context, _ in
            guard duration > 0 else { return }
            var stem = Path()
            stem.move(to: CGPoint(x: x, y: 2))
            stem.addLine(to: CGPoint(x: x, y: fullHeight - 1))
            context.stroke(stem, with: .color(SnapTheme.timelinePlayheadStem), lineWidth: 1)

            var head = Path()
            head.move(to: CGPoint(x: x - 5, y: 2))
            head.addLine(to: CGPoint(x: x + 5, y: 2))
            head.addLine(to: CGPoint(x: x, y: 9))
            head.closeSubpath()
            context.fill(head, with: .color(SnapTheme.accent))
        }
        .frame(height: fullHeight)
        .allowsHitTesting(false)
    }

    // MARK: - Interaction

    private func scrubGesture(track: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard duration > 0 else { return }
                let t = snapSeek(snapFrame(time(at: value.location.x, track: track)))
                if !dragging {
                    dragging = true
                    dragPosition = t
                    onSeek(t, false)
                    return
                }
                dragPosition = t
                let now = Date()
                if now.timeIntervalSince(lastScrubPreviewAt) >= (1.0 / 60.0) {
                    lastScrubPreviewAt = now
                    onSeek(t, false)
                }
            }
            .onEnded { value in
                guard duration > 0 else { return }
                defer { dragging = false }
                let t = snapSeek(snapFrame(time(at: value.location.x, track: track)))
                dragPosition = t
                onSeek(t, true)
            }
    }

    private func handleWheel(_ event: WheelScrollEvent, trackWidth: CGFloat) {
        guard duration > 0 else { return }
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            if event.shiftHeld {
                zoomAtCursor(
                    delta: event.delta,
                    cursorX: event.localX,
                    trackWidth: trackWidth
                )
            } else if canPan {
                if followPlayhead { followPlayhead = false }
                let panAmount = visibleDuration * Double(event.delta) / Double(max(trackWidth, 1))
                viewStart = clampStart(viewStart - panAmount)
            }
        }
    }

    private func zoomAtCursor(delta: CGFloat, cursorX: CGFloat, trackWidth: CGFloat) {
        let anchorFrac = Double(min(1, max(0, cursorX / trackWidth)))
        let anchorTime = viewStart + anchorFrac * visibleDuration
        let factor = exp(Double(delta) * 0.0035)
        adjustZoom(
            to: min(512, max(1, zoom * factor)),
            anchor: anchorTime,
            anchorFrac: anchorFrac
        )
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
        guard followPlayhead, canPan, !dragging, !scrollbarDragging else { return }
        let margin = visibleDuration * followMarginFraction
        let target: Double?
        if pos < viewStart + margin {
            target = clampStart(pos - margin)
        } else if pos > visibleEnd - margin {
            target = clampStart(pos - visibleDuration + margin)
        } else {
            target = nil
        }
        guard let target, abs(target - viewStart) > 1e-4 else { return }
        var transaction = Transaction()
        transaction.animation = isPlaying ? nil : SnapMotion.scroll
        withTransaction(transaction) {
            viewStart = target
        }
    }

    private func revealPlayhead(_ pos: Double) {
        guard canPan else { return }
        viewStart = clampStart(pos - visibleDuration * 0.35)
    }

    // MARK: - Geometry

    private func time(at x: CGFloat, track: CGRect) -> Double {
        let frac = Double(min(1, max(0, (x - track.minX) / track.width)))
        return viewStart + frac * visibleDuration
    }

    private func xPos(_ t: Double, track: CGRect) -> CGFloat {
        guard visibleDuration > 0 else { return track.minX }
        let frac = (t - viewStart) / visibleDuration
        return track.minX + track.width * CGFloat(frac)
    }

    private func snapFrame(_ t: Double) -> Double {
        guard fps > 0 else { return t }
        return Timecode.snapped(seconds: t, fps: fps, duration: duration)
    }

    private func clampStart(_ start: Double) -> Double {
        let maxStart = max(0, duration - visibleDuration)
        return min(max(0, start), maxStart)
    }

    @ViewBuilder
    private func markerView(_ m: TimelineMarker, track: CGRect) -> some View {
        let x = xPos(m.t, track: track)
        let color: Color = switch m.kind {
        case .crop, .cropActive: SnapTheme.crop
        case .cueDone: SnapTheme.good
        case .cueActive: SnapTheme.cue
        case .cuePending: SnapTheme.cuePending
        }
        let thick = m.kind == .cueActive || m.kind == .cropActive
        VStack(spacing: 0) {
            Rectangle()
                .fill(color.opacity(0.9))
                .frame(width: thick ? 2 : 1.5, height: track.height - 4)
        }
        .position(x: x, y: track.midY)
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
