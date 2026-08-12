import AppKit
import SwiftUI

/// Hardware key codes (US QWERTY positions). Layout-independent.
private enum KeyCode {
    static let escape: UInt16 = 53
    static let space: UInt16 = 49
    static let delete: UInt16 = 51
    static let left: UInt16 = 123
    static let right: UInt16 = 124

    static let one: UInt16 = 18
    static let two: UInt16 = 19
    static let three: UInt16 = 20

    static let c: UInt16 = 8
    static let g: UInt16 = 5
    static let m: UInt16 = 46
    static let leftBracket: UInt16 = 33
    static let rightBracket: UInt16 = 30
}

struct HotkeyCatcher: NSViewRepresentable {
    var state: AppState

    func makeNSView(context: Context) -> KeyView {
        let v = KeyView()
        v.state = state
        return v
    }

    func updateNSView(_ nsView: KeyView, context: Context) {
        nsView.state = state
    }

    final class KeyView: NSView {
        weak var state: AppState?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            DispatchQueue.main.async { [weak self] in
                self?.window?.makeFirstResponder(self)
            }
        }

        override func keyDown(with event: NSEvent) {
            guard let state else {
                super.keyDown(with: event)
                return
            }
            if isEditingText {
                super.keyDown(with: event)
                return
            }

            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods.contains(.command) {
                super.keyDown(with: event)
                return
            }

            let shift = mods.contains(.shift)
            let option = mods.contains(.option)

            switch event.keyCode {
            case KeyCode.escape where state.videoURL != nil:
                state.closeVideo()
            case KeyCode.space:
                state.player.togglePause()
            case KeyCode.left:
                if option {
                    state.player.seek(
                        seconds: state.player.position - (shift ? 5 : 1),
                        precise: true
                    )
                } else {
                    state.frameStep(shift ? -10 : -1)
                }
            case KeyCode.right:
                if option {
                    state.player.seek(
                        seconds: state.player.position + (shift ? 5 : 1),
                        precise: true
                    )
                } else {
                    state.frameStep(shift ? 10 : 1)
                }
            case KeyCode.delete:
                if shift, state.activeCropIndex != nil {
                    state.deleteActiveCrop()
                } else if !shift {
                    state.deleteActiveCue()
                }
            case KeyCode.m:
                state.player.toggleMute()
            case KeyCode.c:
                state.cropOverlayVisible.toggle()
            case KeyCode.g:
                state.performSeek()
            case KeyCode.one:
                state.player.setSpeed(0.5)
            case KeyCode.two:
                state.player.setSpeed(1)
            case KeyCode.three:
                state.player.setSpeed(2)
            case KeyCode.leftBracket:
                state.prevCue()
            case KeyCode.rightBracket:
                state.nextCue()
            default:
                super.keyDown(with: event)
            }
        }

        private var isEditingText: Bool {
            guard let responder = window?.firstResponder else { return false }
            return responder is NSTextView || responder is NSTextField
        }
    }
}
