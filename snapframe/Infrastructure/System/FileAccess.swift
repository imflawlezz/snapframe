import AppKit
import UniformTypeIdentifiers

enum FileAccess {
    static let videoTypes: [UTType] = {
        var types: [UTType] = [.mpeg4Movie, .quickTimeMovie, .avi]
        if let mkv = UTType(filenameExtension: "mkv") { types.insert(mkv, at: 0) }
        if let webm = UTType(filenameExtension: "webm") { types.append(webm) }
        return types
    }()

    static func openVideoPanel(startURL: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = videoTypes
        panel.title = "Open Video"
        if let startURL { panel.directoryURL = startURL }
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func openCuesPanel(startURL: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.json]
        panel.title = "Import Cues"
        if let startURL { panel.directoryURL = startURL }
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func sidecarCuesURL(for video: URL) -> URL {
        video.deletingPathExtension().appendingPathExtension("cues.json")
    }
}
