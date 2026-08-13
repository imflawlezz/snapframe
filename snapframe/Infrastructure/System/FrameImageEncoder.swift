import AppKit
import CoreGraphics
import Foundation

struct FrameImageEncoder: ImageEncoding {
    func encode(_ image: CGImage, format: ExportImageFormat, jpegQuality: Double) -> Data? {
        let rep = NSBitmapImageRep(cgImage: image)
        switch format {
        case .png:
            return rep.representation(using: .png, properties: [:])
        case .jpeg:
            return rep.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality])
        }
    }
}
