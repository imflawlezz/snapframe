import SwiftUI

struct LoadingOverlay: View {
    var message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().controlSize(.large)
                Text(message.isEmpty ? "Loading…" : message)
                    .font(SnapTheme.titleFont)
                    .foregroundStyle(SnapTheme.ink)
            }
            .padding(28)
            .background(SnapTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 16)
        }
    }
}
