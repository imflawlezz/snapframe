import AppKit
import SwiftUI

enum ShortcutGlyph {
    static func keys(from shortcut: String) -> [String] {
        let trimmed = shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let lower = trimmed.lowercased()
        if lower == "space" { return ["Space"] }
        if lower == "⌫" || lower == "delete" || lower == "backspace" { return ["⌫"] }

        var keys: [String] = []
        var rest = trimmed

        func eat(_ symbol: String) {
            if rest.hasPrefix(symbol) {
                keys.append(symbol)
                rest.removeFirst(symbol.count)
            }
        }

        eat("⌘")
        eat("⇧")
        eat("⌥")
        eat("⌃")
        eat("⌃")

        rest = rest.trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty {
            if rest.count == 1 {
                keys.append(rest.uppercased())
            } else if rest.allSatisfy(\.isLetter) {
                keys.append(rest.uppercased())
            } else {
                keys.append(rest)
            }
        }
        return keys
    }
}

struct ShortcutKeycap: View {
    let title: String
    var compact: Bool = false
    var onAccent: Bool = false

    var body: some View {
        Text(title)
            .font(.system(size: compact ? 10 : 11, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.horizontal, title.count > 1 ? (compact ? 5 : 6) : (compact ? 4 : 5))
            .padding(.vertical, compact ? 2 : 3)
            .background(
                RoundedRectangle(cornerRadius: compact ? 3.5 : 4.5, style: .continuous)
                    .fill(onAccent ? Color.white.opacity(0.20) : Color(white: 0.20))
                    .overlay(
                        RoundedRectangle(cornerRadius: compact ? 3.5 : 4.5, style: .continuous)
                            .strokeBorder(
                                onAccent ? Color.white.opacity(0.38) : Color(white: 0.34),
                                lineWidth: 1
                            )
                    )
            )
            .fixedSize()
    }
}

struct ShortcutKeycapRow: View {
    let shortcut: String
    var compact: Bool = false
    var onAccent: Bool = false

    var body: some View {
        let keys = ShortcutGlyph.keys(from: shortcut)
        if !keys.isEmpty {
            HStack(spacing: compact ? 2 : 3) {
                ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                    ShortcutKeycap(title: key, compact: compact, onAccent: onAccent)
                }
            }
            .fixedSize()
        }
    }
}

// MARK: - Tooltip panel

private final class TooltipPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating + 1
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
    }
}

private final class TooltipController {
    static let shared = TooltipController()
    private let panel = TooltipPanel()
    private var showTimer: Timer?
    private var hideTimer: Timer?

    func scheduleShow(label: String, shortcut: String, near view: NSView) {
        guard !label.isEmpty else { return }
        hideTimer?.invalidate()
        showTimer?.invalidate()
        showTimer = Timer.scheduledTimer(withTimeInterval: 0.28, repeats: false) { [weak self] _ in
            self?.show(label: label, shortcut: shortcut, near: view)
        }
    }

    func show(label: String, shortcut: String, near view: NSView) {
        guard !label.isEmpty else { return }
        hideTimer?.invalidate()

        let hosting = NSHostingView(rootView: TooltipContent(label: label, shortcut: shortcut))
        hosting.wantsLayer = true
        hosting.layer?.contentsScale = view.window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        let size = hosting.fittingSize

        panel.contentView = hosting
        panel.setContentSize(size)

        guard let screen = view.window?.screen ?? NSScreen.main else { return }
        var origin = view.window?.convertPoint(toScreen: view.convert(
            CGPoint(
                x: view.bounds.midX - size.width / 2,
                y: view.bounds.minY - size.height - 8
            ),
            to: nil
        )) ?? .zero

        origin.x = max(screen.visibleFrame.minX + 6,
                       min(origin.x, screen.visibleFrame.maxX - size.width - 6))
        if origin.y < screen.visibleFrame.minY + 4 {
            origin = view.window?.convertPoint(toScreen: view.convert(
                CGPoint(
                    x: view.bounds.midX - size.width / 2,
                    y: view.bounds.maxY + 8
                ),
                to: nil
            )) ?? origin
            origin.x = max(screen.visibleFrame.minX + 6,
                           min(origin.x, screen.visibleFrame.maxX - size.width - 6))
        }
        origin.y = max(screen.visibleFrame.minY + 4, origin.y)

        panel.setFrameOrigin(origin)
        panel.orderFront(nil)
    }

    func hide() {
        showTimer?.invalidate()
        showTimer = nil
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: false) { [weak self] _ in
            self?.panel.orderOut(nil)
        }
    }
}

private struct TooltipContent: View {
    let label: String
    let shortcut: String

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(white: 0.97))
                .lineLimit(1)

            ShortcutKeycapRow(shortcut: shortcut)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.11, green: 0.12, blue: 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.40), radius: 12, y: 5)
        )
        .fixedSize()
    }
}

// MARK: - Hover tracker

private struct TooltipTrigger: NSViewRepresentable {
    let label: String
    let shortcut: String

    func makeNSView(context: Context) -> TrackingView {
        TrackingView(label: label, shortcut: shortcut)
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.label = label
        nsView.shortcut = shortcut
    }

    final class TrackingView: NSView {
        var label: String
        var shortcut: String
        private var area: NSTrackingArea?

        init(label: String, shortcut: String) {
            self.label = label
            self.shortcut = shortcut
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let a = area { removeTrackingArea(a) }
            area = NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area!)
        }

        override func mouseEntered(with event: NSEvent) {
            TooltipController.shared.scheduleShow(label: label, shortcut: shortcut, near: self)
        }
        override func mouseExited(with event: NSEvent) {
            TooltipController.shared.hide()
        }
        override func mouseDown(with event: NSEvent) {
            TooltipController.shared.hide()
            super.mouseDown(with: event)
        }
    }
}

private struct SnapTooltipModifier: ViewModifier {
    let label: String
    let shortcut: String

    func body(content: Content) -> some View {
        content.overlay {
            TooltipTrigger(label: label, shortcut: shortcut)
                .allowsHitTesting(false)
        }
    }
}

extension View {
    func snapTooltip(_ label: String, shortcut: String = "") -> some View {
        modifier(SnapTooltipModifier(label: label, shortcut: shortcut))
    }
}
