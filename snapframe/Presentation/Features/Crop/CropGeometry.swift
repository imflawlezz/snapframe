import CoreGraphics

enum CropGeometry {
    static func letterbox(videoSize: CGSize, in container: CGSize) -> CGRect {
        guard videoSize.width > 0, videoSize.height > 0 else { return .zero }
        let scale = min(container.width / videoSize.width, container.height / videoSize.height)
        let w = videoSize.width * scale
        let h = videoSize.height * scale
        return CGRect(
            x: (container.width - w) / 2,
            y: (container.height - h) / 2,
            width: w,
            height: h
        )
    }

    static func viewRect(crop: CropRect, letter: CGRect, videoSize: CGSize) -> CGRect {
        guard videoSize.width > 0 else { return .zero }
        let scale = letter.width / videoSize.width
        return CGRect(
            x: letter.minX + CGFloat(crop.x) * scale,
            y: letter.minY + CGFloat(crop.y) * scale,
            width: CGFloat(crop.width) * scale,
            height: CGFloat(crop.height) * scale
        )
    }
}
