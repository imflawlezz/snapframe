import Foundation

struct RecentVideo: Codable, Identifiable, Equatable {
    var id: String { videoPath }
    var videoPath: String
    var outputFolderPath: String
    var lastOpened: Date
    var previewFilename: String?

    var videoURL: URL { URL(fileURLWithPath: videoPath) }
    var outputFolderURL: URL { URL(fileURLWithPath: outputFolderPath) }
    var displayName: String { videoURL.lastPathComponent }
    var outputFolderName: String { outputFolderURL.lastPathComponent }
}
