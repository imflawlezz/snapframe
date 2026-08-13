import CoreGraphics
import Foundation

enum CropResizeLock: Equatable {
    case free
    case ratio(width: Int, height: Int)
    case square
}

struct CropRect: Equatable {
    var x: Int
    var y: Int
    var width: Int
    var height: Int

    static let `default` = CropRect(x: 0, y: 0, width: 320, height: 320)
    private static let minSide = 16

    var centerX: Int { x + width / 2 }
    var centerY: Int { y + height / 2 }
    var isSquare: Bool { width == height }

    init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(x: Int, y: Int, size: Int) {
        self.init(x: x, y: y, width: size, height: size)
    }

    func centerOffset(in video: CGSize) -> (dx: Int, dy: Int) {
        guard video.width > 0, video.height > 0 else { return (0, 0) }
        let vx = Int(video.width) / 2
        let vy = Int(video.height) / 2
        return (centerX - vx, centerY - vy)
    }

    mutating func center(in video: CGSize) {
        guard video.width > 0, video.height > 0 else { return }
        clamp(in: video)
        x = max(0, (Int(video.width) - width) / 2)
        y = max(0, (Int(video.height) - height) / 2)
        clamp(in: video)
    }

    mutating func setCenterOffset(dx: Int, dy: Int, in video: CGSize) {
        guard video.width > 0, video.height > 0 else { return }
        let vx = Int(video.width) / 2
        let vy = Int(video.height) / 2
        x = vx + dx - width / 2
        y = vy + dy - height / 2
        clamp(in: video)
    }

    mutating func setWidth(_ newWidth: Int, in video: CGSize, lock: CropResizeLock) {
        applySize(requestedWidth: newWidth, requestedHeight: nil, in: video, lock: lock)
    }

    mutating func setHeight(_ newHeight: Int, in video: CGSize, lock: CropResizeLock) {
        applySize(requestedWidth: nil, requestedHeight: newHeight, in: video, lock: lock)
    }

    private mutating func applySize(
        requestedWidth: Int?,
        requestedHeight: Int?,
        in video: CGSize,
        lock: CropResizeLock
    ) {
        guard video.width > 0, video.height > 0 else { return }
        let cx = centerX
        let cy = centerY
        let maxW = Int(video.width)
        let maxH = Int(video.height)
        let size = Self.resolvedSize(
            requestedWidth: requestedWidth,
            requestedHeight: requestedHeight,
            currentWidth: width,
            currentHeight: height,
            maxW: maxW,
            maxH: maxH,
            lock: lock
        )
        width = size.width
        height = size.height
        x = cx - width / 2
        y = cy - height / 2
        x = max(0, min(x, maxW - width))
        y = max(0, min(y, maxH - height))
    }

    private static func resolvedSize(
        requestedWidth: Int?,
        requestedHeight: Int?,
        currentWidth: Int,
        currentHeight: Int,
        maxW: Int,
        maxH: Int,
        lock: CropResizeLock
    ) -> (width: Int, height: Int) {
        switch lock {
        case .free:
            let w = min(max(requestedWidth ?? currentWidth, minSide), maxW)
            let h = min(max(requestedHeight ?? currentHeight, minSide), maxH)
            return (w, h)

        case .square:
            let requested = requestedWidth ?? requestedHeight ?? min(currentWidth, currentHeight)
            let side = min(max(requested, minSide), min(maxW, maxH))
            return (side, side)

        case .ratio(let rw, let rh):
            let maxFit = largestFitting(ratioW: rw, ratioH: rh, maxW: maxW, maxH: maxH)
            let minFit = smallestFitting(ratioW: rw, ratioH: rh, maxW: maxW, maxH: maxH)
            let desiredW: Int
            if let w = requestedWidth {
                desiredW = w
            } else if let h = requestedHeight {
                desiredW = width(forHeight: h, ratioW: rw, ratioH: rh)
            } else {
                desiredW = currentWidth
            }
            let w = min(max(desiredW, minFit.width), maxFit.width)
            let h = height(forWidth: w, ratioW: rw, ratioH: rh)
            if h <= maxH, h >= minSide {
                return (w, h)
            }
            return maxFit
        }
    }

    private static func largestFitting(ratioW: Int, ratioH: Int, maxW: Int, maxH: Int) -> (width: Int, height: Int) {
        var lo = minSide
        var hi = maxW
        var best = (width: minSide, height: minSide)
        while lo <= hi {
            let mid = (lo + hi) / 2
            let h = height(forWidth: mid, ratioW: ratioW, ratioH: ratioH)
            if h >= minSide, h <= maxH, mid <= maxW {
                best = (mid, h)
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        return best
    }

    private static func smallestFitting(ratioW: Int, ratioH: Int, maxW: Int, maxH: Int) -> (width: Int, height: Int) {
        for w in minSide...maxW {
            let h = height(forWidth: w, ratioW: ratioW, ratioH: ratioH)
            if h >= minSide, h <= maxH {
                return (w, h)
            }
        }
        return (minSide, minSide)
    }

    mutating func clamp(in video: CGSize) {
        guard video.width > 0, video.height > 0 else { return }
        let maxW = Int(video.width)
        let maxH = Int(video.height)
        width = max(Self.minSide, min(width, maxW))
        height = max(Self.minSide, min(height, maxH))
        x = max(0, min(x, maxW - width))
        y = max(0, min(y, maxH - height))
    }

    func scaledToImage(imageWidth: Int, imageHeight: Int, videoWidth: Int, videoHeight: Int) -> CGRect? {
        guard videoWidth > 0, videoHeight > 0, imageWidth > 0, imageHeight > 0 else { return nil }
        let scale = CGFloat(imageWidth) / CGFloat(videoWidth)
        let cx = max(0, min(Int((CGFloat(x) * scale).rounded()), imageWidth - 1))
        let cy = max(0, min(Int((CGFloat(y) * scale).rounded()), imageHeight - 1))
        let cw = Int((CGFloat(width) * scale).rounded())
        let ch = Int((CGFloat(height) * scale).rounded())
        guard cw > 0, ch > 0, cx + cw <= imageWidth, cy + ch <= imageHeight else { return nil }
        return CGRect(x: cx, y: cy, width: cw, height: ch)
    }

    private static func height(forWidth w: Int, ratioW: Int, ratioH: Int) -> Int {
        guard ratioW > 0 else { return w }
        return max(minSide, Int((Double(w) * Double(ratioH) / Double(ratioW)).rounded()))
    }

    private static func width(forHeight h: Int, ratioW: Int, ratioH: Int) -> Int {
        guard ratioH > 0 else { return h }
        return max(minSide, Int((Double(h) * Double(ratioW) / Double(ratioH)).rounded()))
    }
}
