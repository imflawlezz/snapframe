import Foundation

enum ExportImageFormat: String, CaseIterable, Identifiable {
    case png, jpeg

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
    var fileExtension: String { rawValue }
}
