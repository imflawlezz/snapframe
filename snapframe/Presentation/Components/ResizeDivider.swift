import AppKit
import SwiftUI

enum WorkspaceLayout {
    static let windowMinWidth: CGFloat = 1280
    static let windowMinHeight: CGFloat = 740
    static let mainMinWidth: CGFloat = 720
    static let inspectorMinWidth: CGFloat = 240
    static let inspectorMaxWidth: CGFloat = 480
}

struct WindowMinSizeConfigurator: NSViewRepresentable {
    var minSize: NSSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { apply(to: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { apply(to: nsView) }
    }

    private func apply(to view: NSView) {
        guard let window = view.window else { return }
        window.minSize = minSize
        if window.frame.width < minSize.width || window.frame.height < minSize.height {
            var frame = window.frame
            frame.size.width = max(frame.size.width, minSize.width)
            frame.size.height = max(frame.size.height, minSize.height)
            window.setFrame(frame, display: true)
        }
    }
}

struct ResizeDivider: View {
    enum Axis {
        case horizontal, vertical
    }

    var axis: Axis = .horizontal
    var onDragDelta: (CGFloat) -> Void
    var onDragStateChanged: ((Bool) -> Void)? = nil

    @State private var hovering = false
    @State private var dragging = false

    private var hitSize: CGFloat { 7 }
    private var gripOpacity: Double { dragging ? 1 : (hovering ? 0.9 : 0.55) }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(SnapTheme.stroke.opacity(dragging ? 0.55 : (hovering ? 0.35 : 0.22)))

            grip
                .opacity(gripOpacity)

            ResizeHandleNS(axis: axis) { delta in
                dragging = true
                onDragDelta(delta)
            } onStateChange: { active in
                dragging = active
                hovering = active
                onDragStateChanged?(active)
            }
            .onHover { hovering = $0 || dragging }
        }
        .frame(
            width: axis == .horizontal ? hitSize : nil,
            height: axis == .vertical ? hitSize : nil
        )
        .frame(maxWidth: axis == .vertical ? .infinity : nil, maxHeight: axis == .horizontal ? .infinity : nil)
    }

    @ViewBuilder
    private var grip: some View {
        Capsule()
            .fill(SnapTheme.slate)
            .frame(
                width: axis == .horizontal ? 3 : 22,
                height: axis == .horizontal ? 22 : 3
            )
    }
}

private struct ResizeHandleNS: NSViewRepresentable {
    var axis: ResizeDivider.Axis
    var onDragDelta: (CGFloat) -> Void
    var onStateChange: (Bool) -> Void

    func makeNSView(context: Context) -> ResizeHandleView {
        let view = ResizeHandleView(axis: axis)
        view.onDragDelta = onDragDelta
        view.onStateChange = onStateChange
        return view
    }

    func updateNSView(_ nsView: ResizeHandleView, context: Context) {
        nsView.axis = axis
        nsView.onDragDelta = onDragDelta
        nsView.onStateChange = onStateChange
    }
}

private final class ResizeHandleView: NSView {
    var axis: ResizeDivider.Axis
    var onDragDelta: ((CGFloat) -> Void)?
    var onStateChange: ((Bool) -> Void)?

    init(axis: ResizeDivider.Axis) {
        self.axis = axis
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var isOpaque: Bool { false }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: axis == .horizontal ? .resizeLeftRight : .resizeUpDown)
    }

    override func mouseDown(with event: NSEvent) {
        onStateChange?(true)
    }

    override func mouseDragged(with event: NSEvent) {
        let delta = axis == .horizontal ? event.deltaX : event.deltaY
        onDragDelta?(delta)
    }

    override func mouseUp(with event: NSEvent) {
        onStateChange?(false)
    }
}
