import AppKit
import SwiftUI

struct HotkeyCatcher: NSViewRepresentable {
    var state: AppState
    @Binding var showingAbout: Bool

    func makeNSView(context: Context) -> KeyView {
        let v = KeyView()
        v.state = state
        v.showAbout = { showingAbout = true }
        return v
    }

    func updateNSView(_ nsView: KeyView, context: Context) {
        nsView.state = state
        nsView.showAbout = { showingAbout = true }
    }

    final class KeyView: NSView {
        weak var state: AppState?
        var showAbout: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() {
            DispatchQueue.main.async { [weak self] in self?.window?.makeFirstResponder(self) }
        }
        override func keyDown(with event: NSEvent) {
            guard let state else { super.keyDown(with: event); return }
            if window?.firstResponder is NSTextView { super.keyDown(with: event); return }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let chars = event.charactersIgnoringModifiers ?? ""
            switch event.keyCode {
            case 49: state.player.togglePause(); return
            case 123:
                state.player.seek(seconds: state.player.position - (mods.contains(.shift) ? 5 : 1), precise: true); return
            case 124:
                state.player.seek(seconds: state.player.position + (mods.contains(.shift) ? 5 : 1), precise: true); return
            case 51: state.deleteActiveCue(); return
            default: break
            }
            switch chars.lowercased() {
            case "o" where !mods.contains(.command): state.openVideo()
            case "i" where !mods.contains(.command): state.importCues()
            case "m": state.player.toggleMute()
            case "c" where !mods.contains(.command): state.cropOverlayVisible.toggle()
            case "s" where !mods.contains(.command): state.saveCrop()
            case "g": state.performSeek()
            case "," where mods.contains(.command):
                showAbout?()
            case "," where !mods.contains(.command):
                state.frameStep(mods.contains(.shift) ? -10 : -1)
            case "." where !mods.contains(.command):
                state.frameStep(mods.contains(.shift) ? 10 : 1)
            case "1": state.player.setSpeed(1)
            case "2": state.player.setSpeed(2)
            case "4": state.player.setSpeed(4)
            case "8": state.player.setSpeed(8)
            case "n", "]": state.nextCue()
            case "p", "[": state.prevCue()
            default: super.keyDown(with: event)
            }
        }
    }
}
