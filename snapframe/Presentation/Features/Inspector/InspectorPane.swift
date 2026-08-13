import SwiftUI

struct InspectorPane: View {
    @Bindable var state: AppState
    @State private var liveCuesFraction: Double?
    @State private var isResizingSplit = false
    @State private var hoveringCropIndex: Int?

    var body: some View {
        GeometryReader { geo in
            if state.hasCues {
                resizableSplit(totalHeight: geo.size.height)
            } else {
                fixedSplit
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(SnapTheme.panel)
        .overlay(alignment: .leading) {
            Rectangle().fill(SnapTheme.stroke).frame(width: 1)
        }
    }

    private var fixedSplit: some View {
        VStack(alignment: .leading, spacing: 0) {
            cuesSection
            Divider().background(SnapTheme.stroke)
            cropsSection
                .frame(maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func resizableSplit(totalHeight: CGFloat) -> some View {
        let fraction = liveCuesFraction ?? UserPreferences.shared.cuesPaneFraction
        let cuesHeight = max(120, min(totalHeight - 140, totalHeight * fraction))

        return VStack(spacing: 0) {
            cuesSection
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

            cropsSection
                .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .transaction { transaction in
            if isResizingSplit { transaction.animation = nil }
        }
    }

    private var cuesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                            cueRow(cue)
                        }
                    }
                    .padding(.bottom, 2)
                }
                .scrollIndicators(.visible)
                .tint(SnapTheme.accent)
                .frame(maxHeight: .infinity)

                HStack(spacing: 4) {
                    ToolButton(systemName: "chevron.left", tooltip: "Previous cue", shortcut: "[") { state.prevCue() }
                    ToolButton(systemName: "chevron.right", tooltip: "Next cue", shortcut: "]") { state.nextCue() }
                    Spacer()
                    ToolButton(systemName: "trash.fill", kind: .danger, tooltip: "Delete cue", shortcut: "⌫") {
                        state.deleteActiveCue()
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Text("No cues loaded")
                        .font(SnapTheme.bodyFont)
                        .foregroundStyle(SnapTheme.inkSecondary)
                    Spacer(minLength: 0)
                    Button("Import") { state.importCues() }
                        .buttonStyle(ToolButtonStyle(width: 66))
                }
            }
        }
        .padding(12)
    }

    private var cropsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                            cropRow(e, index: idx)
                        }
                    }
                    .padding(.bottom, 2)
                }
                .scrollIndicators(.visible)
                .tint(SnapTheme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                HStack(spacing: 4) {
                    Spacer()
                    ToolButton(
                        systemName: "trash.fill",
                        kind: .danger,
                        tooltip: "Delete crop",
                        shortcut: "⇧⌫"
                    ) {
                        state.deleteActiveCrop()
                    }
                    .disabled(state.activeCropIndex == nil)
                    .opacity(state.activeCropIndex == nil ? 0.4 : 1)
                }
            } else {
                Text("No crops saved yet")
                    .font(SnapTheme.bodyFont)
                    .foregroundStyle(SnapTheme.inkSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func cueRow(_ cue: Cue) -> some View {
        let active = state.cueStore?.activeID == cue.id
        return Button { state.gotoCue(cue.id) } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(cue.done ? SnapTheme.good : (active ? SnapTheme.accent : SnapTheme.warn))
                    .frame(width: 7, height: 7)
                Text(cue.timecode)
                    .font(SnapTheme.mono)
                    .foregroundStyle(SnapTheme.ink)
                    .lineLimit(1)
                    .layoutPriority(1)
                if !cue.label.isEmpty {
                    Text(cue.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SnapTheme.inkSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(active ? SnapTheme.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func cropRow(_ e: CropEntry, index: Int) -> some View {
        let active = state.activeCropIndex == index
        let hovering = hoveringCropIndex == index
        return Button {
            state.seekCrop(at: index)
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(active ? SnapTheme.accent : SnapTheme.warn.opacity(0.85))
                    .frame(width: 7, height: 7)
                Text(e.timecode)
                    .font(SnapTheme.mono)
                    .foregroundStyle(SnapTheme.ink)
                    .lineLimit(1)
                    .layoutPriority(1)
                Text("\(e.width)×\(e.height)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(SnapTheme.inkSecondary)
                Spacer(minLength: 0)
                Text(e.file)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SnapTheme.inkSecondary.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(rowBackground(active: active, hovering: hovering))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHover in
            if isHover {
                hoveringCropIndex = index
            } else if hoveringCropIndex == index {
                hoveringCropIndex = nil
            }
        }
    }

    private func rowBackground(active: Bool, hovering: Bool) -> Color {
        if active { return SnapTheme.accentSoft }
        if hovering { return SnapTheme.accentSoft.opacity(0.45) }
        return Color.clear
    }
}
