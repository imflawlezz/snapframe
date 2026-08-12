import Foundation

struct RecentVideo: Codable, Identifiable, Equatable {
    var id: String { videoPath }
    var videoPath: String
    var outputFolderPath: String
    var lastOpened: Date
    var previewFilename: String?
    var videoWidth: Int?
    var videoHeight: Int?
    var fps: Double?
    var durationSeconds: Double?
    var codec: String?

    var videoURL: URL { URL(fileURLWithPath: videoPath) }
    var outputFolderURL: URL { URL(fileURLWithPath: outputFolderPath) }
    var displayName: String { videoURL.lastPathComponent }
    var outputFolderName: String { outputFolderURL.lastPathComponent }

    var mediaDetailsLine: String {
        var parts: [String] = []
        if let videoWidth, let videoHeight, videoWidth > 0, videoHeight > 0 {
            parts.append("\(videoWidth)×\(videoHeight)")
        }
        if let fps, fps > 0 {
            parts.append(String(format: "%.3f fps", fps))
        }
        if let durationSeconds, durationSeconds > 0 {
            parts.append(Timecode.format(durationSeconds))
        }
        if let codec, !codec.isEmpty {
            parts.append(codec.uppercased())
        }
        return parts.joined(separator: " · ")
    }
}

struct RecentVideoMediaInfo {
    var width: Int
    var height: Int
    var fps: Double
    var duration: Double
    var codec: String?
}
