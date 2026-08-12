import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var state: AppState
    @Binding var showingAbout: Bool
    @State private var theme = AppTheme.shared
    @State private var recents = RecentVideosStore.shared
    @Bindable private var prefs = UserPreferences.shared
    @State private var isDropTargeted = false
    @State private var liveInspectorWidth: Double?
    @State private var isResizingInspector = false
    @State private var lastSeekSyncAt = Date.distantPast

    var body: some View {
        ZStack {
            SnapTheme.mist.ignoresSafeArea()

            if state.videoURL == nil {
                emptyState
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                workspace
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            if isDropTargeted {
                DropTargetOverlay()
                    .transition(.opacity)
                    .allowsHitTesting(false)
                    .zIndex(20)
            }
        }
        .animation(SnapMotion.standard, value: isDropTargeted)
        .frame(minWidth: WorkspaceLayout.windowMinWidth, minHeight: WorkspaceLayout.windowMinHeight)
        .background(
            WindowMinSizeConfigurator(minSize: NSSize(
                width: WorkspaceLayout.windowMinWidth,
                height: WorkspaceLayout.windowMinHeight
            ))
        )
        .preferredColorScheme(theme.swiftUIScheme)
        .environment(\.appTheme, theme)
        .sheet(isPresented: $showingAbout) {
            PreferencesSheet(onOpen: {
                state.player.pause(true)
            })
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { state.errorMessage = nil }
        } message: {
            Text(state.errorMessage ?? "")
        }
        .animation(state.isOpeningVideo ? nil : SnapMotion.spring, value: state.videoURL?.absoluteString)
        .animation(SnapMotion.standard, value: state.isOpeningVideo)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
        .background(HotkeyCatcher(state: state))
        .onChange(of: state.player.videoSize) { _, new in
            if new.width > 0 { state.ensureCenteredCrop() }
        }
        .onChange(of: state.player.position) { _, _ in
            guard !state.isLoadingVideo else { return }
            if state.player.isPaused {
                state.syncSeekInputFromPlayer()
            } else {
                let now = Date()
                if now.timeIntervalSince(lastSeekSyncAt) > 0.25 {
                    lastSeekSyncAt = now
                    state.syncSeekInputFromPlayer()
                }
            }
        }
        .onChange(of: state.jumpMode) { _, _ in
            state.syncSeekInputFromPlayer()
        }
        .onChange(of: state.crop) { _, _ in
            state.syncCropFieldsFromRect()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            if prefs.pauseOnFocusLoss {
                state.player.pause(true)
            }
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
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(SnapMotion.spring, value: recents.items.isEmpty)
        .overlay {
            if state.isOpeningVideo {
                LoadingCard(message: state.loadProgressMessage)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
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
                Button("Clear list") {
                    withAnimation(SnapMotion.spring) {
                        recents.clearAll()
                    }
                }
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
                            onRemove: {
                                withAnimation(SnapMotion.standard) {
                                    recents.remove(item)
                                }
                            }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .animation(SnapMotion.spring, value: recents.items.map(\.id))
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
                    .frame(minWidth: WorkspaceLayout.mainMinWidth, maxWidth: .infinity)
                    .layoutPriority(1)
                if state.inspectorVisible {
                    ResizeDivider(axis: .horizontal) { delta in
                        let current = liveInspectorWidth ?? prefs.inspectorWidth
                        liveInspectorWidth = round(min(
                            WorkspaceLayout.inspectorMaxWidth,
                            max(WorkspaceLayout.inspectorMinWidth, current - Double(delta))
                        ))
                    } onDragStateChanged: { dragging in
                        isResizingInspector = dragging
                        if !dragging, let width = liveInspectorWidth {
                            prefs.inspectorWidth = width
                            liveInspectorWidth = nil
                        }
                    }
                    InspectorPane(state: state)
                        .frame(
                            width: liveInspectorWidth ?? prefs.inspectorWidth,
                            alignment: .topLeading
                        )
                        .frame(
                            minWidth: WorkspaceLayout.inspectorMinWidth,
                            maxWidth: WorkspaceLayout.inspectorMaxWidth
                        )
                        .fixedSize(horizontal: true, vertical: false)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .transaction { transaction in
                if isResizingInspector { transaction.animation = nil }
            }
            mediaInfoBar
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 0) {
            ToolButton(
                systemName: "house",
                tooltip: "Home",
                shortcut: "Esc"
            ) {
                state.closeVideo()
            }
            .padding(.trailing, 8)

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

            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    ToolButton(
                        systemName: state.player.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                        tooltip: "Mute", shortcut: "M"
                    ) { state.player.toggleMute() }
                    Slider(
                        value: Binding(
                            get: { state.player.volume },
                            set: { state.player.setVolume($0) }
                        ),
                        in: 0...100,
                        onEditingChanged: { editing in
                            if !editing { state.player.commitVolume() }
                        }
                    )
                    .frame(width: 88)
                    .tint(SnapTheme.accent)
                    .disabled(state.player.isMuted)
                    .opacity(state.player.isMuted ? 0.4 : 1)
                }

                Rectangle()
                    .fill(SnapTheme.stroke)
                    .frame(width: 1, height: 22)

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
                        tooltip: "Toggle crop overlay", shortcut: "C"
                    ) { state.cropOverlayVisible.toggle() }
                    ToolButton(
                        systemName: "sidebar.right",
                        kind: state.inspectorVisible ? .accent : .normal,
                        tooltip: "Toggle inspector", shortcut: "⌘\\"
                    ) {
                        withAnimation(SnapMotion.inspector) {
                            state.inspectorVisible.toggle()
                        }
                    }
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
                isPlaying: !state.player.isPaused,
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
        .frame(minWidth: WorkspaceLayout.mainMinWidth)
    }

    // MARK: - Transport

    private var transportBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    ToolButton(
                        systemName: state.player.isPaused ? "play.fill" : "pause.fill",
                        kind: .accent,
                        tooltip: "Play / Pause", shortcut: "Space"
                    ) { state.player.togglePause() }
                }

                HStack(spacing: 4) {
                    FrameSkipButton(count: 10, direction: .backward, tooltip: "Back 10 frames", shortcut: "⇧←") {
                        state.frameStep(-10)
                    }
                    FrameSkipButton(count: 1, direction: .backward, tooltip: "Previous frame", shortcut: "←") {
                        state.frameStep(-1)
                    }
                    FrameSkipButton(count: 1, direction: .forward, tooltip: "Next frame", shortcut: "→") {
                        state.frameStep(1)
                    }
                    FrameSkipButton(count: 10, direction: .forward, tooltip: "Forward 10 frames", shortcut: "⇧→") {
                        state.frameStep(10)
                    }
                }

                HStack(spacing: 3) {
                    ForEach([0.5, 1.0, 2.0], id: \.self) { s in
                        Button(speedLabel(s)) { state.player.setSpeed(s) }
                            .font(SnapTheme.bodyFont)
                            .buttonStyle(ToolButtonStyle(
                                kind: abs(state.player.speed - s) < 0.01 ? .accent : .normal,
                                width: s == 0.5 ? 40 : 34
                            ))
                            .snapTooltip("Speed \(speedLabel(s))", shortcut: speedShortcut(s))
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
        .background(SnapTheme.panel)
        .overlay(alignment: .top) {
            Rectangle().fill(SnapTheme.stroke).frame(height: 1)
        }
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
            cropField(label: "X", placeholder: "Δ", text: $state.cropOffsetXText, allowsNegative: true) {
                state.applyCropFields()
                DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) }
            }
            cropField(label: "Y", placeholder: "Δ", text: $state.cropOffsetYText, allowsNegative: true) {
                state.applyCropFields()
                DispatchQueue.main.async { NSApp.keyWindow?.makeFirstResponder(nil) }
            }
        }
    }

    private func cropField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        allowsNegative: Bool = false,
        onSubmit: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SnapTheme.inkSecondary)
            DigitsTextField(
                text: text,
                placeholder: placeholder,
                allowsNegative: allowsNegative,
                font: .monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                textColor: NSColor(SnapTheme.fieldText),
                alignment: .center,
                onCommit: onSubmit
            )
            .frame(width: 48, height: 28)
            .background(SnapTheme.fieldBg)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(SnapTheme.stroke, lineWidth: 1))
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
                guard ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased()) else { return }
                DispatchQueue.main.async { state.loadVideo(url) }
            }
        }
        return true
    }

    private func speedLabel(_ speed: Double) -> String {
        speed == 0.5 ? "0.5×" : "\(Int(speed))×"
    }

    private func speedShortcut(_ speed: Double) -> String {
        switch speed {
        case 0.5: "1"
        case 1.0: "2"
        case 2.0: "3"
        default: ""
        }
    }
}
