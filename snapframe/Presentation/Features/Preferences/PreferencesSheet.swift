import AppKit
import SwiftUI

struct PreferencesSheet: View {
    var onOpen: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var theme = AppTheme.shared
    @State private var prefs = UserPreferences.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("Appearance")
                    preferenceRow(label: "Theme") {
                        schemePicker
                            .frame(maxWidth: .infinity)
                    }
                    preferenceToggle(
                        label: "Pause on focus loss",
                        detail: "Pause playback when the window loses focus",
                        isOn: $prefs.pauseOnFocusLoss
                    )

                    sectionHeader("Export")
                    preferenceRow(label: "Format") {
                        exportFormatPicker
                            .frame(maxWidth: .infinity)
                    }
                    if prefs.exportFormat == .jpeg {
                        preferenceRow(label: "Quality") {
                            HStack(spacing: 10) {
                                Slider(value: $prefs.jpegQuality, in: 0.5...1.0)
                                    .tint(SnapTheme.accent)
                                Text("\(Int(prefs.jpegQuality * 100))%")
                                    .font(SnapTheme.mono)
                                    .foregroundStyle(SnapTheme.inkSecondary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    preferenceToggle(
                        label: "Mark cue done on save",
                        detail: "Mark nearest cue complete when saving a crop",
                        isOn: $prefs.markCueDoneOnSave
                    )
                    preferenceToggle(
                        label: "Jump to next cue after save",
                        detail: "Go to the next pending cue after a successful save",
                        isOn: $prefs.advanceToNextCueAfterSave
                    )

                    sectionHeader("Cues")
                    preferenceToggle(
                        label: "Auto-import sidecar",
                        detail: "Load video.cues.json next to the file on open",
                        isOn: $prefs.autoImportSidecarCues
                    )
                    preferenceRow(label: "Snap range (time)") {
                        HStack(spacing: 10) {
                            Slider(value: $prefs.cueSnapToleranceSeconds, in: 0.05...2.0)
                                .tint(SnapTheme.accent)
                            Text(String(format: "%.2f s", prefs.cueSnapToleranceSeconds))
                                .font(SnapTheme.mono)
                                .foregroundStyle(SnapTheme.inkSecondary)
                                .frame(width: 52, alignment: .trailing)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    preferenceRow(label: "Snap range (frame)") {
                        HStack(spacing: 10) {
                            Slider(
                                value: Binding(
                                    get: { Double(prefs.cueSnapToleranceFrames) },
                                    set: { prefs.cueSnapToleranceFrames = Int($0.rounded()) }
                                ),
                                in: 1...30,
                                step: 1
                            )
                            .tint(SnapTheme.accent)
                            Text("\(prefs.cueSnapToleranceFrames) f")
                                .font(SnapTheme.mono)
                                .foregroundStyle(SnapTheme.inkSecondary)
                                .frame(width: 52, alignment: .trailing)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 420)
            .background(SnapTheme.mist)
            .tint(SnapTheme.accent)
            Divider()
            footer
        }
        .frame(width: 480)
        .background(SnapTheme.panel)
        .preferredColorScheme(theme.swiftUIScheme)
        .tint(SnapTheme.accent)
        .onAppear { onOpen?() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 48, height: 48)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("SNAPFRAME")
                        .font(.custom("Avenir Next Condensed", size: 28).weight(.semibold))
                        .tracking(4)
                        .foregroundStyle(SnapTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(appVersionLabel)
                        .font(SnapTheme.bodyFont)
                        .foregroundStyle(SnapTheme.inkSecondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: true)
                }
                .layoutPriority(1)
            }

            Spacer(minLength: 8)

            Button {
                if let url = URL(string: "https://github.com/imflawlezz") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Made with")
                    Image(systemName: "heart.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(red: 0.92, green: 0.28, blue: 0.36))
                    Text("by imflawlezz")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SnapTheme.inkSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: true)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(SnapTheme.chip)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(SnapTheme.stroke, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .fixedSize()
            .snapTooltip("github.com/imflawlezz")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(SnapTheme.panel)
    }

    private var appVersionLabel: String {
        AppInfo.versionLabel
    }

    private var footer: some View {
        HStack {
            Button("Reset defaults") {
                prefs.resetToDefaults()
            }
            .buttonStyle(.plain)
            .font(SnapTheme.bodyFont)
            .foregroundStyle(SnapTheme.inkSecondary)
            Spacer()
            Button("Close") { dismiss() }
                .buttonStyle(ToolButtonStyle(kind: .accent, width: 88))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(SnapTheme.panel)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(SnapTheme.inkSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 6)
    }

    private var schemePicker: some View {
        segmentPicker(
            items: AppColorScheme.allCases,
            selection: theme.scheme,
            label: { $0.label },
            icon: { s in AnyView(schemeIcon(s)) },
            onSelect: { theme.scheme = $0 }
        )
    }

    private var exportFormatPicker: some View {
        segmentPicker(
            items: ExportImageFormat.allCases,
            selection: prefs.exportFormat,
            label: { $0.label },
            icon: { _ in AnyView(EmptyView()) },
            onSelect: { prefs.exportFormat = $0 }
        )
    }

    private func segmentPicker<T: Identifiable & Equatable>(
        items: [T],
        selection: T,
        label: @escaping (T) -> String,
        icon: @escaping (T) -> AnyView,
        onSelect: @escaping (T) -> Void
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                Button { onSelect(item) } label: {
                    HStack(spacing: 5) {
                        icon(item)
                        Text(label(item))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 32)
                    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .background {
                    if selection == item {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(SnapTheme.accent)
                            .padding(2)
                    }
                }
                .foregroundStyle(selection == item ? Color.white : SnapTheme.ink)
            }
        }
        .padding(2)
        .background(SnapTheme.chip)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(SnapTheme.stroke, lineWidth: 1))
    }

    private func preferenceRow<C: View>(label: String, @ViewBuilder content: () -> C) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(label)
                .font(SnapTheme.bodyFont)
                .foregroundStyle(SnapTheme.ink)
                .frame(width: 120, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func preferenceToggle(label: String, detail: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(SnapTheme.bodyFont)
                    .foregroundStyle(SnapTheme.ink)
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SnapTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(SnapTheme.accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func schemeIcon(_ s: AppColorScheme) -> some View {
        switch s {
        case .light:  Image(systemName: "sun.max").font(.system(size: 11))
        case .dark:   Image(systemName: "moon").font(.system(size: 11))
        case .system: Image(systemName: "circle.lefthalf.filled").font(.system(size: 11))
        }
    }
}
