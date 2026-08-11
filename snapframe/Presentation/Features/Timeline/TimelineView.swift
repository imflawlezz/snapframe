import SwiftUI

struct TimelineView: View {
    var duration: Double
    var position: Double
    var fps: Double
    var markers: [TimelineMarker]
    var seekInput: Binding<String>
    var jumpMode: Binding<JumpMode>
    var onSeek: (Double, Bool) -> Void
    var onMarker: (String) -> Void
    var onJumpSubmit: () -> Void

    @State private var dragging = false
    @State private var dragPosition: Double = 0
    @State private var scrubArmed = false
    @State private var jumpedToMarker = false

    private var shown: Double { dragging ? dragPosition : position }

    var body: some View {
        VStack(spacing: 6) {
            seekRow
            trackRow
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var seekRow: some View {
        HStack(spacing: 8) {
            SegmentToggle(selection: jumpMode)

            TextField(
                jumpMode.wrappedValue == .time ? "00:00:00.000" : "frame #",
                text: seekInput
            )
            .textFieldStyle(.plain)
            .font(SnapTheme.mono)
            .foregroundStyle(SnapTheme.fieldText)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .frame(maxWidth: 160)
            .background(SnapTheme.fieldBg)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(SnapTheme.stroke, lineWidth: 1)
            )
            .onSubmit(onJumpSubmit)

            Button(action: onJumpSubmit) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(SnapTheme.accent)
            }
            .buttonStyle(.plain)
            .snapTooltip("Go to timecode", shortcut: "G")

            Spacer()

            Text(jumpMode.wrappedValue == .time
                 ? Timecode.format(shown)
                 : "f\(Timecode.frameIndex(at: shown, fps: fps))")
                .font(SnapTheme.mono)
                .foregroundStyle(SnapTheme.inkSecondary)

            Text("/")
                .foregroundStyle(SnapTheme.inkSecondary.opacity(0.4))

            Text(jumpMode.wrappedValue == .time
                 ? Timecode.format(duration)
                 : "f\(Timecode.frameIndex(at: duration, fps: fps))")
                .font(SnapTheme.mono)
                .foregroundStyle(SnapTheme.inkSecondary.opacity(0.6))
        }
    }

    private var trackRow: some View {
        GeometryReader { geo in
            let track = CGRect(x: 0, y: 10, width: max(1, geo.size.width), height: 6)
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(SnapTheme.slate.opacity(0.45))
                    .frame(width: track.width, height: track.height)
                    .position(x: track.midX, y: track.midY)

                if duration > 0 {
                    let played = track.width * CGFloat(shown / duration)
                    Capsule()
                        .fill(SnapTheme.accent)
                        .frame(width: max(0, played), height: track.height)
                        .position(x: track.minX + max(0, played) / 2, y: track.midY)
                }

                ForEach(markers) { m in
                    markerView(m, track: track)
                }

                if duration > 0 {
                    let x = track.width * CGFloat(shown / max(duration, 0.0001))
                    Circle()
                        .fill(SnapTheme.ink)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .position(x: x, y: track.midY)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard duration > 0 else { return }
                        let t = time(at: value.location.x, track: track)
                        if !dragging {
                            if let m = hitMarker(at: value.location.x, track: track), let cid = m.cueID {
                                onMarker(cid)
                                dragging = true
                                jumpedToMarker = true
                                scrubArmed = false
                                dragPosition = t
                                return
                            }
                            dragging = true
                            jumpedToMarker = false
                            scrubArmed = false
                            dragPosition = t
                            return
                        }
                        if jumpedToMarker { return }
                        dragPosition = t
                        let moved = hypot(value.translation.width, value.translation.height)
                        if moved > 4 {
                            scrubArmed = true
                            onSeek(t, false)
                        }
                    }
                    .onEnded { value in
                        guard duration > 0 else { return }
                        defer {
                            dragging = false
                            scrubArmed = false
                            jumpedToMarker = false
                        }
                        if jumpedToMarker { return }
                        let t = time(at: value.location.x, track: track)
                        dragPosition = t
                        onSeek(t, true)
                    }
            )
        }
        .frame(height: 28)
    }

    private func time(at x: CGFloat, track: CGRect) -> Double {
        Double(min(1, max(0, x / track.width))) * duration
    }

    private func xPos(_ t: Double, track: CGRect) -> CGFloat {
        track.width * CGFloat(t / max(duration, 0.0001))
    }

    private func hitMarker(at x: CGFloat, track: CGRect) -> TimelineMarker? {
        markers.min(by: { abs(xPos($0.t, track: track) - x) < abs(xPos($1.t, track: track) - x) })
            .flatMap { abs(xPos($0.t, track: track) - x) < 10 ? $0 : nil }
    }

    @ViewBuilder
    private func markerView(_ m: TimelineMarker, track: CGRect) -> some View {
        let x = xPos(m.t, track: track)
        let color: Color = switch m.kind {
        case .crop: SnapTheme.accent
        case .cueDone: SnapTheme.good
        case .cueActive: SnapTheme.ink
        case .cuePending: SnapTheme.warn
        }
        Capsule()
            .fill(color)
            .frame(width: m.kind == .cueActive ? 3 : 2, height: 16)
            .position(x: x, y: track.midY)
    }
}

// MARK: - Segment toggle

struct SegmentToggle: View {
    @Binding var selection: JumpMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(JumpMode.allCases) { mode in
                Button {
                    selection = mode
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
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
