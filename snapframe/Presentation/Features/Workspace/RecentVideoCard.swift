import AppKit
import SwiftUI

struct RecentVideoCard: View {
    let item: RecentVideo
    let preview: NSImage?
    let onOpen: () -> Void
    let onRevealFolder: () -> Void
    let onRemove: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(SnapTheme.videoWell)
                if let preview {
                    Image(nsImage: preview)
                        .resizable()
                        .interpolation(.medium)
                        .scaledToFill()
                } else {
                    Image(systemName: "film")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(SnapTheme.slate)
                }
            }
            .frame(width: 56, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SnapTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !item.mediaDetailsLine.isEmpty {
                    Text(item.mediaDetailsLine)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(SnapTheme.inkSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if hovering {
                Button(action: onRevealFolder) {
                    Image(systemName: "folder")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SnapTheme.inkSecondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .snapTooltip("Open output folder")

                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(SnapTheme.inkSecondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .snapTooltip("Remove from recents")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(hovering ? SnapTheme.accentSoft : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: onOpen)
    }
}
