import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class RecentVideosStore {
    static let shared = RecentVideosStore()

    private(set) var items: [RecentVideo] = []
    private let maxItems = 16
    private let storeURL: URL
    private let thumbsDir: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Snapframe", isDirectory: true)
        storeURL = base.appendingPathComponent("recents.json")
        thumbsDir = base.appendingPathComponent("thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: thumbsDir, withIntermediateDirectories: true)
        load()
    }

    static func cropsFolder(for videoURL: URL) -> URL {
        let stem = videoURL.deletingPathExtension().lastPathComponent
        return videoURL.deletingLastPathComponent().appendingPathComponent("\(stem)_crops")
    }

    func record(videoURL: URL, preview: NSImage?, mediaInfo: RecentVideoMediaInfo? = nil) {
        let output = Self.cropsFolder(for: videoURL)
        let thumbName = preview.map { saveThumbnail($0, for: videoURL) } ?? existingPreview(for: videoURL.path)

        var list = items.filter { $0.videoPath != videoURL.path }
        list.insert(RecentVideo(
            videoPath: videoURL.path,
            outputFolderPath: output.path,
            lastOpened: Date(),
            previewFilename: thumbName,
            videoWidth: mediaInfo?.width,
            videoHeight: mediaInfo?.height,
            fps: mediaInfo?.fps,
            durationSeconds: mediaInfo?.duration,
            codec: mediaInfo?.codec
        ), at: 0)
        items = Array(list.prefix(maxItems))
        persist()
    }

    func remove(_ item: RecentVideo) {
        items.removeAll { $0.id == item.id }
        if let name = item.previewFilename {
            try? FileManager.default.removeItem(at: thumbsDir.appendingPathComponent(name))
        }
        persist()
    }

    func clearAll() {
        for item in items {
            if let name = item.previewFilename {
                try? FileManager.default.removeItem(at: thumbsDir.appendingPathComponent(name))
            }
        }
        items = []
        persist()
    }

    func previewImage(for item: RecentVideo) -> NSImage? {
        guard let name = item.previewFilename else { return nil }
        return NSImage(contentsOf: thumbsDir.appendingPathComponent(name))
    }

    func revealOutputFolder(_ item: RecentVideo) {
        let url = item.outputFolderURL
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([item.videoURL])
        }
    }

    private func existingPreview(for path: String) -> String? {
        items.first(where: { $0.videoPath == path })?.previewFilename
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([RecentVideo].self, from: data) else {
            items = []
            return
        }
        items = decoded.filter { FileManager.default.fileExists(atPath: $0.videoPath) }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    private func saveThumbnail(_ image: NSImage, for videoURL: URL) -> String {
        let key = String(videoURL.path.hashValue.magnitude, radix: 16)
        let filename = "\(key).jpg"
        let url = thumbsDir.appendingPathComponent(filename)

        let targetW: CGFloat = 160
        let scale = targetW / max(image.size.width, 1)
        let targetH = max(1, image.size.height * scale)
        let thumb = NSImage(size: NSSize(width: targetW, height: targetH))
        thumb.lockFocus()
        image.draw(
            in: NSRect(x: 0, y: 0, width: targetW, height: targetH),
            from: .zero, operation: .copy, fraction: 1
        )
        thumb.unlockFocus()

        if let tiff = thumb.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            try? data.write(to: url, options: .atomic)
        }
        return filename
    }
}
