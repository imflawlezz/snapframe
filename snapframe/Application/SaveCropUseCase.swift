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
}

enum SaveCropError: LocalizedError {
    case waitingForDimensions
    case sizeTooLarge(Int)
    case outOfBounds
    case encodeFailed

    var errorDescription: String? {
        switch self {
        case .waitingForDimensions: return "Waiting for video dimensions…"
        case .sizeTooLarge(let max): return "Max size is \(max)px."
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
        cues: CueRepository?
    ) throws -> SaveCropResult {
        let vw = Int(request.videoSize.width)
        let vh = Int(request.videoSize.height)
        guard vw > 0, vh > 0 else { throw SaveCropError.waitingForDimensions }

        let maxS = min(vw, vh)
        guard request.crop.size <= maxS else { throw SaveCropError.sizeTooLarge(maxS) }

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
        guard let data = FrameImageEncoder.encode(
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
            size: request.crop.size,
            videoWidth: vw,
            videoHeight: vh
        )
        try crops.add(entry)

        var marked: Cue?
        var nextID: String?
        if request.markCueDone, let cues {
            var target = cues.activeID.flatMap { cues.cue(id: $0) }
            if target == nil { target = cues.nearest(to: request.pts, maxDelta: 0.35) }
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
