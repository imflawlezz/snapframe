import AppKit
import SwiftUI

struct ScrollWheelCapture: NSViewRepresentable {
    var onScroll: (_ delta: CGFloat, _ shiftHeld: Bool, _ localX: CGFloat) -> Void

    func makeNSView(context: Context) -> WheelView {
        let view = WheelView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: WheelView, context: Context) {
        nsView.onScroll = onScroll
    }

    final class WheelView: NSView {
        var onScroll: ((_ delta: CGFloat, _ shiftHeld: Bool, _ localX: CGFloat) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func scrollWheel(with event: NSEvent) {
            let deltaY: CGFloat
            let deltaX: CGFloat
            if event.hasPreciseScrollingDeltas {
                deltaY = event.scrollingDeltaY
                deltaX = event.scrollingDeltaX
            } else {
                deltaY = event.scrollingDeltaY * 10
                deltaX = event.scrollingDeltaX * 10
            }
            let delta = abs(deltaX) > abs(deltaY) ? deltaX : deltaY
            guard abs(delta) > 0.01 else { return }
            let local = convert(event.locationInWindow, from: nil)
            onScroll?(delta, event.modifierFlags.contains(.shift), local.x)
        }
    }
}
