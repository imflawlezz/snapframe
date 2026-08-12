import SwiftUI

struct LoadingCard: View {
    var message: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            if !message.isEmpty {
                Text(message)
                    .font(SnapTheme.bodyFont)
                    .foregroundStyle(SnapTheme.inkSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(SnapTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(SnapTheme.stroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
    }
}

struct StageLoadingOverlay: View {
    var message: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)

            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.regular)
                if !message.isEmpty {
                    Text(message)
                        .font(SnapTheme.bodyFont)
                        .foregroundStyle(SnapTheme.inkSecondary)
                }
            }
        }
        .transition(.opacity)
    }
}
