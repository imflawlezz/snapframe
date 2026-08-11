import Foundation

@MainActor
protocol CropRepository: AnyObject {
    var entries: [CropEntry] { get }
    var cropsFolder: URL { get }

    func ensureFolder() throws
    func nextFilename(format: String) -> String
    func add(_ entry: CropEntry) throws
    func remove(at index: Int) throws
}
