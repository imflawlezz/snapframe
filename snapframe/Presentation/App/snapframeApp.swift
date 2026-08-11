import AppKit
import SwiftUI

@main
struct snapframeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState()
    @State private var showingAbout = false
    @State private var recents = RecentVideosStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView(state: state, showingAbout: $showingAbout)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                    AppTheme.shared.applyToWindows()
                    NSApp.keyWindow?.title = AppInfo.windowTitle
                    appDelegate.openVideo = { [state] url in
                        state.loadVideo(url)
                    }
                    openLaunchArgumentIfPresent()
                }
                .onOpenURL { url in
                    openVideoIfSupported(url)
                }
                .onChange(of: state.videoURL) { _, _ in
                    NSApp.keyWindow?.title = AppInfo.windowTitle
                }
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Video…") { state.openVideo() }
                    .keyboardShortcut("o", modifiers: [.command])
                Button("Import Cues…") { state.importCues() }
                    .keyboardShortcut("i", modifiers: [.command])

                Divider()

                if recents.items.isEmpty {
                    Button("Open Recent") {}
                        .disabled(true)
                } else {
                    Menu("Open Recent") {
                        ForEach(recents.items.prefix(12)) { item in
                            Button(item.displayName) {
                                state.loadVideo(item.videoURL)
                            }
                        }
                        Divider()
                        Button("Clear Menu") { recents.clearAll() }
                    }
                }
            }
            CommandGroup(after: .saveItem) {
                Button("Save Crop") { state.saveCrop() }
                    .keyboardShortcut("s", modifiers: [.command])
            }
            CommandGroup(after: .sidebar) {
                Button("Refresh Preview") { state.refreshPreview() }
                    .keyboardShortcut("r", modifiers: [.command])
                Button("Toggle Inspector") { state.inspectorVisible.toggle() }
                    .keyboardShortcut("\\", modifiers: [.command])
                Button("Toggle Crop Overlay") { state.cropOverlayVisible.toggle() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .appSettings) {
                Button("Preferences…") { showingAbout = true }
                    .keyboardShortcut(",", modifiers: [.command])
            }
            CommandGroup(replacing: .help) {
                Button("Snapframe Help") {
                    if let url = URL(string: "https://github.com/imflawlezz") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            CommandMenu("Playback") {
                Button("Play / Pause") { state.player.togglePause() }
                    .keyboardShortcut(" ", modifiers: [])
                Button("Mute") { state.player.toggleMute() }
                    .keyboardShortcut("m", modifiers: [])
                Divider()
                Button("Previous Frame") { state.frameStep(-1) }
                    .keyboardShortcut(",", modifiers: [])
                Button("Next Frame") { state.frameStep(1) }
                    .keyboardShortcut(".", modifiers: [])
                Button("Back 10 Frames") { state.frameStep(-10) }
                    .keyboardShortcut(",", modifiers: [.shift])
                Button("Forward 10 Frames") { state.frameStep(10) }
                    .keyboardShortcut(".", modifiers: [.shift])
                Divider()
                Button("Speed 1×") { state.player.setSpeed(1) }
                    .keyboardShortcut("1", modifiers: [])
                Button("Speed 2×") { state.player.setSpeed(2) }
                    .keyboardShortcut("2", modifiers: [])
                Button("Speed 4×") { state.player.setSpeed(4) }
                    .keyboardShortcut("4", modifiers: [])
                Button("Speed 8×") { state.player.setSpeed(8) }
                    .keyboardShortcut("8", modifiers: [])
            }
            CommandMenu("Cues") {
                Button("Next Cue") { state.nextCue() }
                    .keyboardShortcut("]", modifiers: [])
                Button("Previous Cue") { state.prevCue() }
                    .keyboardShortcut("[", modifiers: [])
                Button("Delete Active Cue") { state.deleteActiveCue() }
                    .keyboardShortcut(.delete, modifiers: [])
            }
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
    }

    private static let videoExtensions: Set<String> = ["mkv", "mp4", "webm", "mov", "avi", "m4v"]

    private func openVideoIfSupported(_ url: URL) {
        guard Self.videoExtensions.contains(url.pathExtension.lowercased()) else { return }
        state.loadVideo(url)
    }

    private func openLaunchArgumentIfPresent() {
        let args = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-") }
        guard let path = args.first else { return }
        openVideoIfSupported(URL(fileURLWithPath: path))
    }
}
