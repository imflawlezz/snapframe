import AppKit
import SwiftUI

struct VideoStage: View {
    @Bindable var state: AppState

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(SnapTheme.videoWell)

            VideoPlayerView(player: state.player.avPlayer)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .opacity(state.player.isPaused ? 0 : 1)

            if state.player.isPaused, let preview = state.player.frameImage {
                Image(nsImage: preview)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .allowsHitTesting(false)
            }

            if state.cropFrameChromeVisible || state.cropScissorsChromeVisible {
                CropOverlayView(
                    videoSize: state.player.videoSize,
                    crop: $state.crop,
                    resizeLock: state.cropResizeLock,
                    scissorsMode: state.cropScissorsChromeVisible,
                    onInteractionChange: { state.setCropInteracting($0) },
                    onScissorsComplete: { state.saveCrop() }
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.opacity)
            }

            if state.isLoadingVideo {
                StageLoadingOverlay(message: state.loadProgressMessage)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(SnapTheme.ink.opacity(0.12), lineWidth: 1))
        .animation(SnapMotion.cropBar, value: state.cropFrameChromeVisible)
        .animation(SnapMotion.cropBar, value: state.cropScissorsChromeVisible)
        .animation(nil, value: state.inspectorVisible)
        .animation(nil, value: state.cropOverlayVisible)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
