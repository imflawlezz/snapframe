import AppKit
import SwiftUI

struct VideoStage: View {
    @Bindable var state: AppState

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(SnapTheme.videoWell)

            VideoPlayerView(player: state.player.avPlayer)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if state.cropOverlayVisible || state.cropScissorsMode {
                CropOverlayView(
                    videoSize: state.player.videoSize,
                    crop: $state.crop,
                    resizeLock: state.cropResizeLock,
                    scissorsMode: state.cropScissorsMode,
                    onInteractionChange: { state.setCropInteracting($0) },
                    onScissorsComplete: { state.saveCrop() }
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if state.isLoadingVideo {
                StageLoadingOverlay(message: state.loadProgressMessage)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(SnapTheme.ink.opacity(0.12), lineWidth: 1))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
