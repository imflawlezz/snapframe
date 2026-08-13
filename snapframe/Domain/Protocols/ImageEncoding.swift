import CoreGraphics
import Foundation

protocol ImageEncoding {
    func encode(_ image: CGImage, format: ExportImageFormat, jpegQuality: Double) -> Data?
}
