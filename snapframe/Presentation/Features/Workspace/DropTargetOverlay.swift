import SwiftUI

struct DropTargetOverlay: View {
    private let topInset: CGFloat = 44
    private let edgeInset: CGFloat = 16

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    SnapTheme.accent,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [11, 7])
                )
                .padding(.top, topInset)
                .padding(.leading, edgeInset)
                .padding(.trailing, edgeInset)
                .padding(.bottom, edgeInset)
                .allowsHitTesting(false)

            VStack(spacing: 8) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 26, weight: .semibold))
                Text("Drop video to open")
                    .font(SnapTheme.titleFont)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(SnapTheme.accent)
                    .shadow(color: .black.opacity(0.28), radius: 14, y: 5)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
