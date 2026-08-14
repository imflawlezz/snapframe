import Foundation
import Observation

struct CropMetadataFile: Codable {
    var source: String
    var sourcePath: String
    var crops: [CropEntry]

    enum CodingKeys: String, CodingKey {
        case source
        case sourcePath = "source_path"
        case crops
    }
}

@Observable
@MainActor
final class CropStore: CropRepository {
    private(set) var entries: [CropEntry] = []

    let videoURL: URL

    var cropsFolder: URL { Self.cropsFolder(for: videoURL) }

    var metaURL: URL { cropsFolder.appendingPathComponent("metadata.json") }

    init(videoURL: URL) {
        self.videoURL = videoURL
        load()
    }

    static func cropsFolder(for videoURL: URL) -> URL {
        let stem = videoURL.deletingPathExtension().lastPathComponent
        return videoURL.deletingLastPathComponent().appendingPathComponent("\(stem)_crops")
    }

    func load() {
        guard let data = try? Data(contentsOf: metaURL),
              let file = try? JSONDecoder().decode(CropMetadataFile.self, from: data) else {
            entries = []
            return
        }
        entries = file.crops
    }

    func ensureFolder() throws {
        try FileManager.default.createDirectory(at: cropsFolder, withIntermediateDirectories: true)
    }

    func nextFilename(format: String = "png") -> String {
        let existing = Set(entries.map(\.file))
        var n = 1
        while true {
            let name = String(format: "crop_%03d.%@", n, format)
            let path = cropsFolder.appendingPathComponent(name)
            if !existing.contains(name) && !FileManager.default.fileExists(atPath: path.path) {
                return name
            }
            n += 1
        }
    }

    func add(_ entry: CropEntry) throws {
        try ensureFolder()
        entries.append(entry)
        try save()
    }

    func remove(at index: Int) throws {
        guard entries.indices.contains(index) else { return }
        let entry = entries.remove(at: index)
        let path = cropsFolder.appendingPathComponent(entry.file)
        try? FileManager.default.removeItem(at: path)
        try save()
    }

    private func save() throws {
        try ensureFolder()
        let file = CropMetadataFile(
            source: videoURL.lastPathComponent,
            sourcePath: videoURL.path,
            crops: entries
        )
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try enc.encode(file)
        try data.write(to: metaURL, options: .atomic)
    }
}
