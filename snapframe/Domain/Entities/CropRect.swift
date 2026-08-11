import CoreGraphics
import Foundation

struct CropRect: Equatable {
    var x: Int
    var y: Int
    var size: Int

    static let `default` = CropRect(x: 0, y: 0, size: 320)

    var centerX: Int { x + size / 2 }
    var centerY: Int { y + size / 2 }

    func centerOffset(in video: CGSize) -> (dx: Int, dy: Int) {
        guard video.width > 0, video.height > 0 else { return (0, 0) }
        let vx = Int(video.width) / 2
        let vy = Int(video.height) / 2
        return (centerX - vx, centerY - vy)
    }

    mutating func center(in video: CGSize) {
        guard video.width > 0, video.height > 0 else { return }
        let maxS = Int(min(video.width, video.height))
        size = min(max(size, 16), maxS)
        x = max(0, (Int(video.width) - size) / 2)
        y = max(0, (Int(video.height) - size) / 2)
    }

    mutating func setCenterOffset(dx: Int, dy: Int, in video: CGSize) {
        guard video.width > 0, video.height > 0 else { return }
        let maxS = Int(min(video.width, video.height))
        size = min(max(size, 16), maxS)
        let half = size / 2
        let vx = Int(video.width) / 2
        let vy = Int(video.height) / 2
        x = vx + dx - half
        y = vy + dy - half
        clamp(in: video)
    }

    mutating func setSize(_ newSize: Int, in video: CGSize) {
        guard video.width > 0, video.height > 0 else { return }
        let maxS = Int(min(video.width, video.height))
        let oldCenter = (centerX, centerY)
        size = min(max(newSize, 16), maxS)
        x = oldCenter.0 - size / 2
        y = oldCenter.1 - size / 2
        clamp(in: video)
    }

    mutating func clamp(in video: CGSize) {
        guard video.width > 0, video.height > 0 else { return }
        let maxS = Int(min(video.width, video.height))
        size = max(16, min(size, maxS))
        x = max(0, min(x, Int(video.width) - size))
        y = max(0, min(y, Int(video.height) - size))
    }

    func scaledToImage(imageWidth: Int, imageHeight: Int, videoWidth: Int, videoHeight: Int) -> CGRect? {
        guard videoWidth > 0, videoHeight > 0, imageWidth > 0, imageHeight > 0 else { return nil }
        let scale = CGFloat(imageWidth) / CGFloat(videoWidth)
        let cx = max(0, min(Int((CGFloat(x) * scale).rounded()), imageWidth - 1))
        let cy = max(0, min(Int((CGFloat(y) * scale).rounded()), imageHeight - 1))
        let cs = Int((CGFloat(size) * scale).rounded())
        guard cs > 0, cx + cs <= imageWidth, cy + cs <= imageHeight else { return nil }
        return CGRect(x: cx, y: cy, width: cs, height: cs)
    }
}
