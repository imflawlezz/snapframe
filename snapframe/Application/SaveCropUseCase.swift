import CoreGraphics
import Foundation

struct SaveCropRequest {
    var crop: CropRect
    var videoSize: CGSize
    var frame: CGImage
    var pts: Double
    var format: ExportImageFormat
    var jpegQuality: Double
    var markCueDone: Bool
    var advanceAfterSave: Bool
    var cueMatchWindow: Double
}

enum SaveCropError: LocalizedError {
    case waitingForDimensions
    case tooLarge
    case outOfBounds
    case encodeFailed

    var errorDescription: String? {
        switch self {
        case .waitingForDimensions: return "Waiting for video dimensions…"
        case .tooLarge: return "Crop is larger than the video frame."
        case .outOfBounds: return "Crop rectangle is out of bounds."
        case .encodeFailed: return "Image encode failed"
        }
    }
}

struct SaveCropResult {
    var filename: String
    var entry: CropEntry
    var markedCue: Cue?
    var nextCueID: String?
}

enum SaveCropUseCase {
    @MainActor
    static func execute(
        request: SaveCropRequest,
        crops: CropRepository,
        cues: CueRepository?,
        imageEncoder: ImageEncoding
    ) throws -> SaveCropResult {
        let vw = Int(request.videoSize.width)
        let vh = Int(request.videoSize.height)
        guard vw > 0, vh > 0 else { throw SaveCropError.waitingForDimensions }

        guard request.crop.width <= vw, request.crop.height <= vh else {
            throw SaveCropError.tooLarge
        }

        let cg = request.frame
        guard let pixelRect = request.crop.scaledToImage(
            imageWidth: cg.width,
            imageHeight: cg.height,
            videoWidth: vw,
            videoHeight: vh
        ), let cropped = cg.cropping(to: pixelRect) else {
            throw SaveCropError.outOfBounds
        }

        try crops.ensureFolder()
        let filename = crops.nextFilename(format: request.format.fileExtension)
        let out = crops.cropsFolder.appendingPathComponent(filename)
        guard let data = imageEncoder.encode(
            cropped,
            format: request.format,
            jpegQuality: request.jpegQuality
        ) else {
            throw SaveCropError.encodeFailed
        }
        try data.write(to: out, options: .atomic)

        let entry = CropEntry(
            file: filename,
            timecode: Timecode.format(request.pts),
            timecodeSeconds: (request.pts * 1000).rounded() / 1000,
            x: request.crop.x,
            y: request.crop.y,
            width: request.crop.width,
            height: request.crop.height,
            videoWidth: vw,
            videoHeight: vh
        )
        try crops.add(entry)

        var marked: Cue?
        var nextID: String?
        if request.markCueDone, let cues {
            let target = cues.nearest(to: request.pts, maxDelta: request.cueMatchWindow)
            if let t = target, !t.done {
                try cues.markDone(t.id)
                marked = t
                if request.advanceAfterSave {
                    nextID = cues.nextPending(after: t.id)?.id
                }
            }
        }

        return SaveCropResult(filename: filename, entry: entry, markedCue: marked, nextCueID: nextID)
    }
}
