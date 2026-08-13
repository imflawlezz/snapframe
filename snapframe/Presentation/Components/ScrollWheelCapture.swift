import AppKit
import SwiftUI

struct ScrollWheelCapture: NSViewRepresentable {
    var onScroll: (_ event: WheelScrollEvent) -> Void

    func makeNSView(context: Context) -> WheelView {
        let view = WheelView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: WheelView, context: Context) {
        nsView.onScroll = onScroll
    }

    final class WheelView: NSView {
        var onScroll: ((_ event: WheelScrollEvent) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func scrollWheel(with event: NSEvent) {
            let precise = event.hasPreciseScrollingDeltas
            let scale: CGFloat = precise ? 1 : 10
            let deltaY = event.scrollingDeltaY * scale
            let deltaX = event.scrollingDeltaX * scale
            let primary = abs(deltaX) > abs(deltaY) ? deltaX : deltaY
            guard abs(primary) > 0.01 else { return }

            let local = convert(event.locationInWindow, from: nil)
            let momentum = !event.momentumPhase.isEmpty
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            onScroll?(
                WheelScrollEvent(
                    delta: primary,
                    shiftHeld: mods.contains(.shift),
                    optionHeld: mods.contains(.option),
                    localX: local.x,
                    isPrecise: precise,
                    isMomentum: momentum
                )
            )
        }
    }
}

struct WheelScrollEvent {
    var delta: CGFloat
    var shiftHeld: Bool
    var optionHeld: Bool
    var localX: CGFloat
    var isPrecise: Bool
    var isMomentum: Bool
}
