import AppKit
import SwiftUI

@main
struct snapframeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState()
    @State private var showingPreferences = false
    @State private var recents = RecentVideosStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView(
                state: state,
                showingPreferences: $showingPreferences
            )
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                    AppTheme.shared.applyToWindows()
                    NSApp.keyWindow?.title = AppInfo.windowTitle
                    appDelegate.openVideo = { [state] url in
                        state.loadVideo(url)
                    }
                    appDelegate.onQuit = { [state] in
                        state.player.pause(true)
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
        .defaultSize(width: 1360, height: 860)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About \(AppInfo.name)") {
                    AppInfo.showAboutPanel()
                }
            }
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
                        Button("Clear Menu") {
                            withAnimation(SnapMotion.spring) {
                                recents.clearAll()
                            }
                        }
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
            }
            CommandGroup(replacing: .appSettings) {
                Button("Preferences…") { showingPreferences = true }
                    .keyboardShortcut(",", modifiers: [.command])
            }
            CommandGroup(replacing: .help) {
                Button("\(AppInfo.name) on GitHub") {
                    NSWorkspace.shared.open(AppInfo.repositoryURL)
                }
            }
            CommandMenu("Playback") {
                Button("Play / Pause") { state.player.togglePause() }
                    .keyboardShortcut(.space, modifiers: [])
                Button("Mute") { state.player.toggleMute() }
                    .keyboardShortcut("m", modifiers: [])
                Divider()
                Button("Previous Frame") { state.frameStep(-1) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("Next Frame") { state.frameStep(1) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Button("Back 10 Frames") { state.frameStep(-10) }
                    .keyboardShortcut(.leftArrow, modifiers: [.shift])
                Button("Forward 10 Frames") { state.frameStep(10) }
                    .keyboardShortcut(.rightArrow, modifiers: [.shift])
                Divider()
                Button("Seek Backward 1s") { state.seekStep(seconds: -1) }
                .keyboardShortcut(.leftArrow, modifiers: [.option])
                Button("Seek Forward 1s") { state.seekStep(seconds: 1) }
                .keyboardShortcut(.rightArrow, modifiers: [.option])
                Button("Seek Backward 5s") { state.seekStep(seconds: -5) }
                .keyboardShortcut(.leftArrow, modifiers: [.option, .shift])
                Button("Seek Forward 5s") { state.seekStep(seconds: 5) }
                .keyboardShortcut(.rightArrow, modifiers: [.option, .shift])
                Divider()
                Button("Speed 0.5×") { state.player.setSpeed(0.5) }
                    .keyboardShortcut("1", modifiers: [])
                Button("Speed 1×") { state.player.setSpeed(1) }
                    .keyboardShortcut("2", modifiers: [])
                Button("Speed 2×") { state.player.setSpeed(2) }
                    .keyboardShortcut("3", modifiers: [])
                Divider()
                Button("Go to Start") { state.goToStart() }
                    .keyboardShortcut(.return, modifiers: [])
                Button("Follow Playhead") { state.followPlayhead.toggle() }
                    .keyboardShortcut("p", modifiers: [])
            }
            CommandMenu("Cues") {
                Button("Add Cue at Playhead") { state.addCueAtPlayhead() }
                    .keyboardShortcut("n", modifiers: [])
                Button("Previous Cue") { state.prevCue() }
                    .keyboardShortcut("[", modifiers: [])
                Button("Next Cue") { state.nextCue() }
                    .keyboardShortcut("]", modifiers: [])
                Button("Delete Active Cue") { state.deleteActiveCue() }
                    .keyboardShortcut(.delete, modifiers: [])
                Divider()
                Button("Snap to Cues") { state.toggleSnapToCues() }
                    .keyboardShortcut("s", modifiers: [])
            }
            CommandMenu("Crops") {
                Button("Frame Crop") { state.toggleCropOverlay() }
                    .keyboardShortcut("c", modifiers: [])
                Button("Scissors Crop") { state.toggleCropScissors() }
                    .keyboardShortcut("x", modifiers: [])
                Button("Aspect Lock") { state.toggleCropRatioLock() }
                    .keyboardShortcut("l", modifiers: [])
                Button("Square Proportions") { state.toggleCropSquareLock() }
                    .keyboardShortcut("r", modifiers: [])
                Button("Delete Active Crop") { state.deleteActiveCrop() }
                    .keyboardShortcut(.delete, modifiers: .shift)
            }
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
    }

    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]

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
