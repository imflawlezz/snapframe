import Foundation
import XCTest
@testable import Snapframe

@MainActor
final class CropStoreTests: XCTestCase {
    private var directory: URL!
    private var videoURL: URL!
    private var store: CropStore!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapframe-crop-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        videoURL = directory.appendingPathComponent("Movie.mp4")
        FileManager.default.createFile(atPath: videoURL.path, contents: Data())
        store = CropStore(videoURL: videoURL)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
        directory = nil
        videoURL = nil
        store = nil
    }

    func testCropsFolderName() {
        XCTAssertEqual(store.cropsFolder.lastPathComponent, "Movie_crops")
        XCTAssertEqual(CropStore.cropsFolder(for: videoURL), store.cropsFolder)
    }

    func testNextFilenameSkipsExisting() throws {
        XCTAssertEqual(store.nextFilename(format: "png"), "crop_001.png")
        try store.ensureFolder()
        try Data().write(to: store.cropsFolder.appendingPathComponent("crop_001.png"))
        try store.add(CropEntry(
            file: "crop_002.png",
            timecode: "00:00:00.000",
            timecodeSeconds: 0,
            x: 0, y: 0, width: 10, height: 10,
            videoWidth: 100, videoHeight: 100
        ))
        XCTAssertEqual(store.nextFilename(format: "png"), "crop_003.png")
    }

    func testAddPersistsAndReload() throws {
        let entry = CropEntry(
            file: "crop_001.png",
            timecode: "00:00:01.000",
            timecodeSeconds: 1,
            x: 1, y: 2, width: 30, height: 40,
            videoWidth: 100, videoHeight: 80
        )
        try Data([0x89]).write(to: {
            try store.ensureFolder()
            return store.cropsFolder.appendingPathComponent(entry.file)
        }())
        try store.add(entry)

        let reloaded = CropStore(videoURL: videoURL)
        XCTAssertEqual(reloaded.entries, [entry])
    }

    func testRemoveDeletesFileAndMetadata() throws {
        try store.ensureFolder()
        let file = "crop_001.png"
        let path = store.cropsFolder.appendingPathComponent(file)
        try Data([1, 2, 3]).write(to: path)
        try store.add(CropEntry(
            file: file,
            timecode: "00:00:00.000",
            timecodeSeconds: 0,
            x: 0, y: 0, width: 16, height: 16,
            videoWidth: 64, videoHeight: 64
        ))
        try store.remove(at: 0)
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path.path))
    }
}
