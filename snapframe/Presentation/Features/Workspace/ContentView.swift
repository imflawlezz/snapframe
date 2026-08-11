import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var state: AppState
    @Binding var showingAbout: Bool
    @State private var theme = AppTheme.shared
    @State private var recents = RecentVideosStore.shared
    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            SnapTheme.mist.ignoresSafeArea()

            if state.videoURL == nil && !state.isLoadingVideo {
                emptyState
            } else {
                workspace
            }

            if state.isLoadingVideo {
                LoadingOverlay(message: state.loadProgressMessage)
            }

            if isDropTargeted {
                DropTargetOverlay()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .frame(minWidth: 1080, minHeight: 680)
        .preferredColorScheme(theme.swiftUIScheme)
        .environment(\.appTheme, theme)
        .sheet(isPresented: $showingAbout) {
            PreferencesSheet()
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { state.errorMessage = nil }
        } message: {
            Text(state.errorMessage ?? "")
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
        .animation(.easeOut(duration: 0.15), value: isDropTargeted)
        .background(HotkeyCatcher(state: state, showingAbout: $showingAbout))
        .onChange(of: state.player.videoSize) { _, new in
            if new.width > 0 { state.ensureCenteredCrop() }
        }
        .onChange(of: state.player.position) { _, _ in
            if !state.isLoadingVideo { state.syncSeekInputFromPlayer() }
        }
        .onChange(of: state.jumpMode) { _, _ in
            state.syncSeekInputFromPlayer()
        }
        .onChange(of: state.crop) { _, _ in
            state.syncCropFieldsFromRect()
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        Group {
            if recents.items.isEmpty {
                emptyOpenHero
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    emptyOpenHero
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Rectangle()
                        .fill(SnapTheme.stroke)
                        .frame(width: 1)

                    recentPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyOpenHero: some View {
        VStack(spacing: 16) {
            Text("SNAPFRAME")
                .font(SnapTheme.displayFont)
                .tracking(6)
                .foregroundStyle(SnapTheme.ink)

            VStack(spacing: 4) {
                Text("Supported formats")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(SnapTheme.inkSecondary)
                    .textCase(.uppercase)
                Text(AppState.supportedFormats.joined(separator: "  ·  "))
                    .font(SnapTheme.bodyFont)
                    .foregroundStyle(SnapTheme.ink)
            }

            HStack(spacing: 10) {
                Button(action: { state.openVideo() }) {
                    HStack(spacing: 12) {
                        Text("Open Video")
                            .font(SnapTheme.titleFont)
                        ShortcutKeycapRow(shortcut: "⌘O", compact: true, onAccent: true)
                    }
                    .padding(.horizontal, 6)
                }
                .buttonStyle(ToolButtonStyle(kind: .accent, width: 200, height: 44))

                Button {
                    showingAbout = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(ToolButtonStyle(width: 44, height: 44))
                .snapTooltip("Preferences", shortcut: "⌘,")
            }

            Text("or drop a file")
                .font(.custom("Avenir Next", size: 12).weight(.medium))
                .foregroundStyle(SnapTheme.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recentPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent")
                    .font(SnapTheme.titleFont)
                    .foregroundStyle(SnapTheme.ink)
                Spacer()
                Button("Clear list") { recents.clearAll() }
                    .buttonStyle(.plain)
                    .font(SnapTheme.bodyFont)
                    .foregroundStyle(SnapTheme.inkSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(recents.items) { item in
                        RecentVideoCard(
                            item: item,
                            preview: recents.previewImage(for: item),
                            onOpen: { state.loadVideo(item.videoURL) },
                            onRevealFolder: { recents.revealOutputFolder(item) },
                            onRemove: { recents.remove(item) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(SnapTheme.panel.opacity(0.55))
    }

    // MARK: - Workspace

    private var workspace: some View {
        VStack(spacing: 0) {
            topBar
            HStack(spacing: 0) {
                mainColumn
                if state.inspectorVisible {
                    InspectorPane(state: state)
                        .frame(width: 304)
                }
            }
            mediaInfoBar
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 0) {
            Text("SNAPFRAME")
                .font(.custom("Avenir Next Condensed", size: 16).weight(.bold))
                .tracking(3)
                .foregroundStyle(SnapTheme.ink)

            if let name = state.videoURL?.lastPathComponent {
                Text(name)
                    .font(SnapTheme.bodyFont)
                    .foregroundStyle(SnapTheme.inkSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.leading, 10)
            }

            Spacer(minLength: 12)

            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    ToolButton(systemName: "film", tooltip: "Open video", shortcut: "⌘O") { state.openVideo() }
                    ToolButton(systemName: "list.bullet", tooltip: "Import cues", shortcut: "⌘I") { state.importCues() }
                }

                if state.outputFolderExists {
                    HStack(spacing: 4) {
                        ToolButton(
                            systemName: "folder",
                            tooltip: "Open output folder"
                        ) { state.revealOutputFolder() }
                    }
                }

                HStack(spacing: 4) {
                    ToolButton(
                        systemName: "arrow.clockwise",
                        tooltip: "Refresh preview",
                        shortcut: "⌘R"
                    ) { state.refreshPreview() }
                    .disabled(state.videoURL == nil || state.isLoadingVideo)
                    .opacity(state.videoURL == nil || state.isLoadingVideo ? 0.4 : 1)
                    ToolButton(
                        systemName: "crop",
                        kind: state.cropOverlayVisible ? .accent : .normal,
                        tooltip: "Toggle crop overlay", shortcut: "⌘⇧C"
                    ) { state.cropOverlayVisible.toggle() }
                    ToolButton(
                        systemName: "sidebar.right",
                        kind: state.inspectorVisible ? .accent : .normal,
                        tooltip: "Toggle inspector", shortcut: "⌘\\"
                    ) { state.inspectorVisible.toggle() }
                }

                HStack(spacing: 4) {
                    ToolButton(
                        systemName: "slider.horizontal.3",
                        tooltip: "Preferences",
                        shortcut: "⌘,"
                    ) {
                        showingAbout = true
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(SnapTheme.panel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(SnapTheme.stroke).frame(height: 1)
        }
    }

    // MARK: - Main column

    private var mainColumn: some View {
        VStack(spacing: 0) {
            VideoStage(state: state)
                .padding(.horizontal, 10)
                .padding(.top, 8)
            transportBar
                .contentShape(Rectangle())
                .onTapGesture { DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) } }
            TimelineView(
                duration: state.player.duration,
                position: state.player.position,
                fps: state.player.fps,
                markers: state.timelineMarkers,
                seekInput: $state.seekInput,
                jumpMode: $state.jumpMode,
                onSeek: { t, precise in state.onTimelineSeek(seconds: t, precise: precise) },
                onMarker: { id in state.gotoCue(id) },
                onJumpSubmit: { state.performSeek() }
            )
            .background(SnapTheme.panel.opacity(0.5))
            .contentShape(Rectangle())
            .onTapGesture { DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Transport

    private var transportBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    ToolButton(
                        systemName: state.player.isPaused ? "play.fill" : "pause.fill",
                        kind: .accent,
                        tooltip: "Play / Pause", shortcut: "Space"
                    ) { state.player.togglePause() }
                    ToolButton(
                        systemName: state.player.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                        tooltip: "Mute", shortcut: "M"
                    ) { state.player.toggleMute() }
                }

                HStack(spacing: 4) {
                    ToolButton(systemName: "backward.end.fill",  tooltip: "Back 10 frames",   shortcut: "⇧,") { state.frameStep(-10) }
                    ToolButton(systemName: "chevron.backward",   tooltip: "Previous frame",    shortcut: ",")  { state.frameStep(-1) }
                    ToolButton(systemName: "chevron.forward",    tooltip: "Next frame",        shortcut: ".")  { state.frameStep(1) }
                    ToolButton(systemName: "forward.end.fill",   tooltip: "Forward 10 frames", shortcut: "⇧.") { state.frameStep(10) }
                }

                HStack(spacing: 3) {
                    ForEach([1.0, 2.0, 4.0, 8.0], id: \.self) { s in
                        Button("\(Int(s))×") { state.player.setSpeed(s) }
                            .buttonStyle(ToolButtonStyle(
                                kind: abs(state.player.speed - s) < 0.01 ? .accent : .normal,
                                width: 34
                            ))
                            .snapTooltip("Speed \(Int(s))×", shortcut: "\(Int(s))")
                    }
                }
            }

            Spacer(minLength: 12)

            if state.cropOverlayVisible {
                HStack(spacing: 6) {
                    cropFields
                    Button {
                        state.saveCrop()
                    } label: {
                        Label("Save crop", systemImage: "square.and.arrow.down")
                            .font(SnapTheme.titleFont)
                    }
                    .buttonStyle(ToolButtonStyle(kind: .accent, width: 108))
                    .disabled(state.player.videoSize == .zero || state.isLoadingVideo)
                    .opacity(state.player.videoSize == .zero ? 0.4 : 1)
                    .snapTooltip("Save crop", shortcut: "⌘S")
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) } }
    }

    // MARK: - Crop fields

    private var cropFields: some View {
        HStack(spacing: 5) {
            cropField(label: "Size", placeholder: "px", text: $state.cropSizeText) {
                state.applyCropFields()
                DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) }
            }
            cropField(label: "X", placeholder: "Δ", text: $state.cropOffsetXText) {
                state.applyCropFields()
                DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) }
            }
            cropField(label: "Y", placeholder: "Δ", text: $state.cropOffsetYText) {
                state.applyCropFields()
                DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) }
            }
        }
    }

    private func cropField(label: String, placeholder: String, text: Binding<String>, onSubmit: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SnapTheme.inkSecondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(SnapTheme.mono)
                .foregroundStyle(SnapTheme.fieldText)
                .multilineTextAlignment(.center)
                .frame(width: 48, height: 28)
                .background(SnapTheme.fieldBg)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(SnapTheme.stroke, lineWidth: 1))
                .onSubmit(onSubmit)
        }
    }

    // MARK: - Footer

    private var mediaInfoBar: some View {
        HStack(spacing: 12) {
            Text(state.mediaInfoLine)
                .font(SnapTheme.mono)
                .foregroundStyle(SnapTheme.inkSecondary)
                .lineLimit(1)
            Spacer()
            if state.player.videoSize.width > 0 {
                Text("frame \(state.player.currentFrame)")
                    .font(SnapTheme.mono)
                    .foregroundStyle(SnapTheme.inkSecondary.opacity(0.8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(SnapTheme.panel)
        .overlay(alignment: .top) {
            Rectangle().fill(SnapTheme.stroke).frame(height: 1)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for p in providers {
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                guard ["mkv", "mp4", "webm", "mov", "avi", "m4v"].contains(url.pathExtension.lowercased()) else { return }
                DispatchQueue.main.async { state.loadVideo(url) }
            }
        }
        return true
    }
}
