import AppKit
import SwiftUI

struct VideoStage: View {
    @Bindable var state: AppState

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(SnapTheme.videoWell)
            VideoFrameLayer(image: state.player.frameImage, isLoading: state.isLoadingVideo)
                .allowsHitTesting(false)
            if state.cropOverlayVisible {
                CropOverlayView(
                    videoSize: state.player.videoSize,
                    crop: $state.crop,
                    onInteractionChange: { state.setCropInteracting($0) }
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(SnapTheme.ink.opacity(0.12), lineWidth: 1))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct VideoFrameLayer: View {
    let image: NSImage?
    let isLoading: Bool

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.low)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if isLoading {
                ProgressView().controlSize(.small).tint(.white.opacity(0.7))
            } else {
                Text("No frame")
                    .font(SnapTheme.bodyFont)
                    .foregroundStyle(SnapTheme.inkSecondary)
            }
        }
    }
}
