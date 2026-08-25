import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var openVideo: ((URL) -> Void)?
    var onQuit: (() -> Void)?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        onQuit?()
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let items = RecentVideosStore.shared.items
        guard !items.isEmpty else { return nil }

        let menu = NSMenu(title: "Recent")
        for item in items.prefix(10) {
            let mi = NSMenuItem(
                title: item.displayName,
                action: #selector(openRecentFromDock(_:)),
                keyEquivalent: ""
            )
            mi.target = self
            mi.representedObject = item.videoPath
            menu.addItem(mi)
        }
        menu.addItem(.separator())
        let clear = NSMenuItem(
            title: "Clear Menu",
            action: #selector(clearRecents),
            keyEquivalent: ""
        )
        clear.target = self
        menu.addItem(clear)
        return menu
    }

    @objc private func openRecentFromDock(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        openVideo?(URL(fileURLWithPath: path))
    }

    @objc private func clearRecents() {
        Task { @MainActor in
            withAnimation(SnapMotion.spring) {
                RecentVideosStore.shared.clearAll()
            }
        }
    }
}
