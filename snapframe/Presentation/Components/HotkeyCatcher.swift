import AppKit
import SwiftUI

private enum KeyCode {
    static let escape: UInt16 = 53
    static let space: UInt16 = 49
    static let delete: UInt16 = 51
    static let left: UInt16 = 123
    static let right: UInt16 = 124

    static let one: UInt16 = 18
    static let two: UInt16 = 19
    static let three: UInt16 = 20

    static let x: UInt16 = 7
    static let c: UInt16 = 8
    static let g: UInt16 = 5
    static let l: UInt16 = 37
    static let m: UInt16 = 46
    static let n: UInt16 = 45
    static let p: UInt16 = 35
    static let r: UInt16 = 15
    static let s: UInt16 = 1
    static let leftBracket: UInt16 = 33
    static let rightBracket: UInt16 = 30
    static let returnKey: UInt16 = 36
    static let keypadEnter: UInt16 = 76
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

    static func dismantleNSView(_ nsView: KeyView, coordinator: ()) {
        nsView.teardown()
    }

    final class KeyView: NSView {
        weak var state: AppState?
        private var clickMonitor: Any?
        private var keyMonitor: Any?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            installMonitors()
            DispatchQueue.main.async { [weak self] in
                guard let self, let window = self.window else { return }
                if !(window.firstResponder is NSTextView || window.firstResponder is NSTextField) {
                    window.makeFirstResponder(self)
                }
            }
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow == nil {
                teardown()
            }
        }

        func teardown() {
            removeMonitors()
        }

        private func installMonitors() {
            removeMonitors()
            clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                self?.resignEditingIfClickOutside(event)
                return event
            }
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                if self.performHotkey(event) { return nil }
                return event
            }
        }

        private func removeMonitors() {
            if let clickMonitor {
                NSEvent.removeMonitor(clickMonitor)
                self.clickMonitor = nil
            }
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
                self.keyMonitor = nil
            }
        }

        private func resignEditingIfClickOutside(_ event: NSEvent) {
            guard let window = event.window ?? window ?? NSApp.keyWindow, isEditingText(in: window) else { return }
            let hit = window.contentView?.hitTest(event.locationInWindow)
            if let hit, Self.isTextInputHierarchy(hit) { return }
            window.endEditing(for: nil)
            _ = window.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            if performHotkey(event) { return }
            super.keyDown(with: event)
        }

        @discardableResult
        private func performHotkey(_ event: NSEvent) -> Bool {
            guard let state else { return false }
            let targetWindow = event.window ?? window
            if targetWindow != nil, targetWindow != window, targetWindow != NSApp.keyWindow {
                return false
            }
            if isEditingText(in: targetWindow ?? NSApp.keyWindow) {
                return false
            }

            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods.contains(.command) { return false }

            let shift = mods.contains(.shift)
            let option = mods.contains(.option)

            switch event.keyCode {
            case KeyCode.escape:
                if state.cropScissorsMode || state.cropScissorsChromeVisible {
                    state.dismissCropScissors()
                } else if state.videoURL != nil {
                    state.closeVideo()
                } else {
                    return false
                }
            case KeyCode.space:
                state.player.togglePause()
            case KeyCode.left:
                if option {
                    state.seekStep(seconds: shift ? -5 : -1)
                } else {
                    state.frameStep(shift ? -10 : -1)
                }
            case KeyCode.right:
                if option {
                    state.seekStep(seconds: shift ? 5 : 1)
                } else {
                    state.frameStep(shift ? 10 : 1)
                }
            case KeyCode.delete:
                if shift, state.highlightedCropIndex != nil {
                    state.deleteActiveCrop()
                } else if !shift {
                    state.deleteActiveCue()
                } else {
                    return false
                }
            case KeyCode.m:
                state.player.toggleMute()
            case KeyCode.n:
                state.addCueAtPlayhead()
            case KeyCode.c:
                state.toggleCropOverlay()
            case KeyCode.x:
                state.toggleCropScissors()
            case KeyCode.l where state.cropOverlayVisible || state.cropScissorsMode:
                state.toggleCropRatioLock()
            case KeyCode.r where state.cropOverlayVisible || state.cropScissorsMode:
                state.toggleCropSquareLock()
            case KeyCode.p:
                state.followPlayhead.toggle()
            case KeyCode.s:
                state.toggleSnapToCues()
            case KeyCode.g:
                state.performSeek()
            case KeyCode.returnKey, KeyCode.keypadEnter:
                state.goToStart()
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
                return false
            }
            return true
        }

        private func isEditingText(in window: NSWindow?) -> Bool {
            guard let responder = window?.firstResponder else { return false }
            return responder is NSTextView || responder is NSTextField
        }

        private static func isTextInputHierarchy(_ view: NSView) -> Bool {
            var current: NSView? = view
            while let node = current {
                if node is NSTextField || node is NSTextView || node is NSComboBox {
                    return true
                }
                current = node.superview
            }
            return false
        }
    }
}
