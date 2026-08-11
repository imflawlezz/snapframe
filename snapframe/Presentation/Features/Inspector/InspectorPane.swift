import SwiftUI

struct InspectorPane: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cuesSection
                .frame(maxHeight: state.hasCues ? .infinity : nil, alignment: .topLeading)
                .layoutPriority(state.hasCues ? 1 : 0)

            Divider().background(SnapTheme.stroke)

            cropsSection
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .layoutPriority(1)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(SnapTheme.panel)
        .overlay(alignment: .leading) {
            Rectangle().fill(SnapTheme.stroke).frame(width: 1)
        }
    }

    // MARK: Cues

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

    // MARK: Crops

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
        Button { state.seekCrop(at: index) } label: {
            HStack(spacing: 6) {
                Text(e.timecode)
                    .font(SnapTheme.mono)
                    .foregroundStyle(SnapTheme.ink)
                    .lineLimit(1)
                    .layoutPriority(1)
                Text("\(e.size)px")
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Seek") { state.seekCrop(at: index) }
            Button("Delete", role: .destructive) { state.deleteCrop(at: index) }
        }
    }
}
