import SwiftUI

struct InspectorPane: View {
    @Bindable var state: AppState
    @State private var liveCuesFraction: Double?
    @State private var isResizingSplit = false
    @State private var hoveringCropIndex: Int?
    @State private var editingCueID: String?

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < 300
            if state.hasCues {
                resizableSplit(totalHeight: geo.size.height, compact: compact)
            } else {
                fixedSplit(compact: compact)
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(SnapTheme.panel)
        .overlay(alignment: .leading) {
            Rectangle().fill(SnapTheme.stroke).frame(width: 1)
        }
    }

    private func fixedSplit(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            cuesSection(compact: compact)
            Divider().background(SnapTheme.stroke)
            cropsSection(compact: compact)
                .frame(maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func resizableSplit(totalHeight: CGFloat, compact: Bool) -> some View {
        let fraction = liveCuesFraction ?? UserPreferences.shared.cuesPaneFraction
        let cuesHeight = max(120, min(totalHeight - 140, totalHeight * fraction))

        return VStack(spacing: 0) {
            cuesSection(compact: compact)
                .frame(height: cuesHeight, alignment: .topLeading)

            ResizeDivider(axis: .vertical) { delta in
                let current = liveCuesFraction ?? UserPreferences.shared.cuesPaneFraction
                liveCuesFraction = min(0.72, max(0.22, current + Double(delta / totalHeight)))
            } onDragStateChanged: { dragging in
                isResizingSplit = dragging
                if !dragging, let fraction = liveCuesFraction {
                    UserPreferences.shared.cuesPaneFraction = fraction
                    liveCuesFraction = nil
                }
            }

            cropsSection(compact: compact)
                .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .transaction { transaction in
            if isResizingSplit { transaction.animation = nil }
        }
    }

    private func cuesSection(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            HStack(spacing: 0) {
                Text("Cues")
                    .font(SnapTheme.titleFont)
                    .foregroundStyle(SnapTheme.ink)
                Spacer()
                if state.hasCues {
                    Text("\(state.doneCueCount) / \(state.cueStore?.cues.count ?? 0)")
                        .font(SnapTheme.mono)
                        .foregroundStyle(SnapTheme.inkSecondary)
                }
            }

            if state.hasCues {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(state.cueStore?.cues ?? []) { cue in
                            cueRow(cue, compact: compact)
                        }
                    }
                    .padding(.bottom, 2)
                }
                .scrollIndicators(.visible)
                .tint(SnapTheme.accent)
                .frame(maxHeight: .infinity)

                inspectorToolbar(compact: compact) {
                    inspectorIconButton("plus", tooltip: "Add cue at playhead", shortcut: "N") {
                        state.addCueAtPlayhead()
                    }
                    .disabled(state.videoURL == nil)
                    .opacity(state.videoURL == nil ? 0.4 : 1)
                    inspectorIconButton("chevron.left", tooltip: "Previous cue", shortcut: "[") {
                        state.prevCue()
                    }
                    inspectorIconButton("chevron.right", tooltip: "Next cue", shortcut: "]") {
                        state.nextCue()
                    }
                    Spacer()
                    inspectorIconButton("trash.fill", kind: .danger, tooltip: "Delete cue", shortcut: "⌫") {
                        state.deleteActiveCue()
                    }
                    .disabled(state.highlightedCueID == nil)
                    .opacity(state.highlightedCueID == nil ? 0.4 : 1)
                }
            } else {
                HStack(spacing: 8) {
                    Text("No cues")
                        .font(SnapTheme.bodyFont)
                        .foregroundStyle(SnapTheme.inkSecondary)
                    Spacer(minLength: 0)
                    inspectorIconButton("plus", tooltip: "Add cue at playhead", shortcut: "N") {
                        state.addCueAtPlayhead()
                    }
                    .disabled(state.videoURL == nil)
                    .opacity(state.videoURL == nil ? 0.4 : 1)
                    Button("Import") { state.importCues() }
                        .buttonStyle(ToolButtonStyle(width: compact ? 56 : 66, height: compact ? 26 : ToolButtonStyle.size))
                        .disabled(state.videoURL == nil)
                }
            }
        }
        .padding(compact ? 8 : 12)
    }

    private func cropsSection(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            HStack {
                Text("Crops")
                    .font(SnapTheme.titleFont)
                    .foregroundStyle(SnapTheme.ink)
                Spacer()
                if let store = state.cropStore, !store.entries.isEmpty {
                    Text("\(store.entries.count)")
                        .font(SnapTheme.mono)
                        .foregroundStyle(SnapTheme.inkSecondary)
                }
            }

            let entries = state.cropStore?.entries ?? []
            let _ = state.cropsRevision
            if !entries.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { idx, e in
                            cropRow(e, index: idx, compact: compact)
                        }
                    }
                    .padding(.bottom, 2)
                }
                .scrollIndicators(.visible)
                .tint(SnapTheme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                inspectorToolbar(compact: compact) {
                    Spacer()
                    inspectorIconButton("trash.fill", kind: .danger, tooltip: "Delete crop", shortcut: "⇧⌫") {
                        state.deleteActiveCrop()
                    }
                    .disabled(state.highlightedCropIndex == nil)
                    .opacity(state.highlightedCropIndex == nil ? 0.4 : 1)
                }
            } else {
                Text("No crops saved yet")
                    .font(SnapTheme.bodyFont)
                    .foregroundStyle(SnapTheme.inkSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(compact ? 8 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func inspectorToolbar<Content: View>(compact: Bool, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: compact ? 3 : 4, content: content)
    }

    private func inspectorIconButton(
        _ systemName: String,
        kind: ToolButtonStyle.Kind = .normal,
        tooltip: String,
        shortcut: String = "",
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
        }
        .buttonStyle(ToolButtonStyle(kind: kind, width: 28, height: 26))
        .snapTooltip(tooltip, shortcut: shortcut)
    }

    private func cueRow(_ cue: Cue, compact: Bool) -> some View {
        CueInspectorRow(
            cue: cue,
            timeDisplay: state.displayTime(cue.t),
            jumpMode: state.jumpMode,
            active: state.highlightedCueID == cue.id,
            isEditing: editingCueID == cue.id,
            compact: compact,
            onSeek: {
                if editingCueID != cue.id { editingCueID = nil }
                state.gotoCue(cue.id)
            },
            onToggleDone: { state.toggleCueDone(cue.id) },
            onBeginEdit: { editingCueID = cue.id },
            onEndEdit: { if editingCueID == cue.id { editingCueID = nil } },
            onCommitTime: { state.updateCueTime(cue.id, text: $0) },
            onCommitLabel: { state.updateCueLabel(cue.id, label: $0) },
            onDelete: { state.deleteCue(cue.id) }
        )
    }

    private func cropRow(_ e: CropEntry, index: Int, compact: Bool) -> some View {
        let active = state.highlightedCropIndex == index
        let hovering = hoveringCropIndex == index
        return Button {
            state.seekCrop(at: index)
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(active ? SnapTheme.crop : SnapTheme.crop.opacity(0.55))
                    .frame(width: 7, height: 7)
                Text(state.displayTime(e.timecodeSeconds))
                    .font(compact ? .system(size: 11, weight: .medium, design: .monospaced) : SnapTheme.mono)
                    .foregroundStyle(SnapTheme.ink)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text("\(e.width)×\(e.height)")
                    .font(.system(size: compact ? 10 : 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(SnapTheme.inkSecondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                if compact {
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 4)
                    Text(e.file)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(SnapTheme.inkSecondary.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(minWidth: 0)
                }
            }
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 3 : 5)
            .background(rowBackground(active: active, hovering: hovering))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Reveal in Finder") {
                state.revealCrop(at: index)
            }
            Divider()
            Button("Delete", role: .destructive) {
                state.deleteCrop(at: index)
            }
        }
        .onHover { isHover in
            if isHover {
                hoveringCropIndex = index
            } else if hoveringCropIndex == index {
                hoveringCropIndex = nil
            }
        }
    }

    private func rowBackground(active: Bool, hovering: Bool) -> Color {
        if active { return SnapTheme.warnSoft }
        if hovering { return SnapTheme.warnSoft.opacity(0.45) }
        return Color.clear
    }
}

private struct CueInspectorRow: View {
    let cue: Cue
    let timeDisplay: String
    let jumpMode: JumpMode
    let active: Bool
    let isEditing: Bool
    var compact: Bool = false
    var onSeek: () -> Void
    var onToggleDone: () -> Void
    var onBeginEdit: () -> Void
    var onEndEdit: () -> Void
    var onCommitTime: (String) -> Void
    var onCommitLabel: (String) -> Void
    var onDelete: () -> Void

    @State private var timeText = ""
    @State private var labelText = ""
    @State private var hovering = false
    @State private var clickMonitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onToggleDone) {
                Image(systemName: cue.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(cue.done ? SnapTheme.good : SnapTheme.inkSecondary)
            }
            .buttonStyle(.plain)
            .snapTooltip(cue.done ? "Mark pending" : "Mark done")

            if isEditing {
                editFields
            } else {
                Button(action: onSeek) {
                    displayRow
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture(count: 2).onEnded { onBeginEdit() })
            }
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 4)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Edit") { onBeginEdit() }
            Button(cue.done ? "Mark Pending" : "Mark Done") { onToggleDone() }
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
        .onAppear {
            timeText = timeDisplay
            labelText = cue.label
            if isEditing { installClickMonitor() }
        }
        .onDisappear { removeClickMonitor() }
        .onChange(of: timeDisplay) { _, new in
            timeText = new
        }
        .onChange(of: cue.label) { _, new in
            labelText = new
        }
        .onChange(of: isEditing) { _, editing in
            if editing {
                timeText = timeDisplay
                labelText = cue.label
                installClickMonitor()
            } else {
                removeClickMonitor()
            }
        }
    }

    private var rowBackground: Color {
        if active { return SnapTheme.accentSoft }
        if hovering { return SnapTheme.accentSoft.opacity(0.45) }
        return Color.clear
    }

    private var displayRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                timeLabel
                if !cue.label.isEmpty {
                    Text(cue.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SnapTheme.inkSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                timeLabel
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var timeLabel: some View {
        Text(timeDisplay)
            .font(compact ? .system(size: 11, weight: .medium, design: .monospaced) : SnapTheme.mono)
            .foregroundStyle(SnapTheme.ink)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var editFields: some View {
        HStack(spacing: 6) {
            DigitsTextField(
                text: $timeText,
                placeholder: jumpMode == .time ? "00:00:00.000" : "frame",
                allowsTimecodeChars: jumpMode == .time,
                font: .monospacedDigitSystemFont(ofSize: 11, weight: .medium),
                textColor: NSColor(SnapTheme.fieldText),
                alignment: .left,
                onCommit: { onCommitTime(timeText) },
                onSubmit: finishEditing,
                focusGroup: cue.id
            )
            .frame(width: jumpMode == .time ? (compact ? 78 : 92) : 52, height: compact ? 20 : 22)
            .padding(.horizontal, 4)
            .background(SnapTheme.fieldBg)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(SnapTheme.stroke, lineWidth: 1))

            DigitsTextField(
                text: $labelText,
                placeholder: "Label",
                allowsAllCharacters: true,
                font: .systemFont(ofSize: 11, weight: .medium),
                textColor: NSColor(SnapTheme.fieldText),
                alignment: .left,
                onCommit: { onCommitLabel(labelText) },
                onSubmit: finishEditing,
                focusGroup: cue.id
            )
            .frame(maxWidth: .infinity, minHeight: 22)
            .padding(.horizontal, 4)
            .background(SnapTheme.fieldBg)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(SnapTheme.stroke, lineWidth: 1))
        }
    }

    private func finishEditing() {
        onCommitTime(timeText)
        onCommitLabel(labelText)
        NSApp.keyWindow?.endEditing(for: nil)
        onEndEdit()
    }

    private func installClickMonitor() {
        removeClickMonitor()
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [cue] event in
            let window = event.window ?? NSApp.keyWindow
            let hit = window?.contentView?.hitTest(event.locationInWindow)
            if DigitsTextField.hitView(hit, isInGroup: cue.id) {
                return event
            }
            finishEditing()
            return event
        }
    }

    private func removeClickMonitor() {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
    }
}
