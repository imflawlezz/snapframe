import CoreGraphics
import Foundation
import XCTest
@testable import Snapframe

@MainActor
final class SaveCropUseCaseTests: XCTestCase {
    private var directory: URL!
    private var crops: FakeCropRepository!
    private var cues: FakeCueRepository!
    private var encoder: FakeImageEncoder!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapframe-save-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        crops = FakeCropRepository(folder: directory)
        cues = FakeCueRepository()
        encoder = FakeImageEncoder()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
        directory = nil
        crops = nil
        cues = nil
        encoder = nil
    }

    func testSaveWritesImageAndEntry() throws {
        let frame = try makeCGImage(width: 200, height: 100)
        let result = try SaveCropUseCase.execute(
            request: SaveCropRequest(
                crop: CropRect(x: 10, y: 10, width: 40, height: 20),
                videoSize: CGSize(width: 200, height: 100),
                frame: frame,
                pts: 1.25,
                format: .png,
                jpegQuality: 0.9,
                markCueDone: false,
                advanceAfterSave: false,
                cueMatchWindow: 0.2
            ),
            crops: crops,
            cues: cues,
            imageEncoder: encoder
        )

        XCTAssertEqual(result.filename, "crop_001.png")
        XCTAssertEqual(result.entry.width, 40)
        XCTAssertEqual(result.entry.height, 20)
        XCTAssertEqual(result.entry.timecodeSeconds, 1.25)
        XCTAssertEqual(crops.entries.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent(result.filename).path))
        XCTAssertEqual(encoder.lastFormat, .png)
    }

    func testMarkCueDoneAndAdvance() throws {
        let first = cues.addCue(t: 1.0, label: "a")
        let second = cues.addCue(t: 2.0, label: "b")
        let frame = try makeCGImage(width: 100, height: 100)

        let result = try SaveCropUseCase.execute(
            request: SaveCropRequest(
                crop: CropRect(x: 0, y: 0, width: 16, height: 16),
                videoSize: CGSize(width: 100, height: 100),
                frame: frame,
                pts: 1.05,
                format: .jpeg,
                jpegQuality: 0.8,
                markCueDone: true,
                advanceAfterSave: true,
                cueMatchWindow: 0.2
            ),
            crops: crops,
            cues: cues,
            imageEncoder: encoder
        )

        XCTAssertEqual(result.markedCue?.id, first.id)
        XCTAssertEqual(result.nextCueID, second.id)
        XCTAssertTrue(cues.cue(id: first.id)?.done == true)
        XCTAssertEqual(encoder.lastFormat, .jpeg)
    }

    func testRejectsMissingDimensions() {
        XCTAssertThrowsError(
            try SaveCropUseCase.execute(
                request: makeRequest(videoSize: .zero, crop: CropRect.default),
                crops: crops,
                cues: nil,
                imageEncoder: encoder
            )
        ) { error in
            guard case SaveCropError.waitingForDimensions = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }

    func testRejectsCropLargerThanVideo() {
        XCTAssertThrowsError(
            try SaveCropUseCase.execute(
                request: makeRequest(
                    videoSize: CGSize(width: 100, height: 100),
                    crop: CropRect(x: 0, y: 0, width: 200, height: 50)
                ),
                crops: crops,
                cues: nil,
                imageEncoder: encoder
            )
        ) { error in
            guard case SaveCropError.tooLarge = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }

    func testRejectsEncodeFailure() {
        encoder.fail = true
        XCTAssertThrowsError(
            try SaveCropUseCase.execute(
                request: makeRequest(
                    videoSize: CGSize(width: 100, height: 100),
                    crop: CropRect(x: 0, y: 0, width: 16, height: 16)
                ),
                crops: crops,
                cues: nil,
                imageEncoder: encoder
            )
        ) { error in
            guard case SaveCropError.encodeFailed = error else {
                return XCTFail("unexpected \(error)")
            }
        }
    }

    private func makeRequest(videoSize: CGSize, crop: CropRect) -> SaveCropRequest {
        SaveCropRequest(
            crop: crop,
            videoSize: videoSize,
            frame: (try? makeCGImage(width: 100, height: 100))!,
            pts: 0,
            format: .png,
            jpegQuality: 0.9,
            markCueDone: false,
            advanceAfterSave: false,
            cueMatchWindow: 0.2
        )
    }

    private func makeCGImage(width: Int, height: Int) throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        )
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ), let image = context.makeImage() else {
            throw NSError(domain: "SaveCropUseCaseTests", code: 1)
        }
        return image
    }
}

@MainActor
private final class FakeCropRepository: CropRepository {
    private(set) var entries: [CropEntry] = []
    let cropsFolder: URL

    init(folder: URL) {
        cropsFolder = folder
    }

    func ensureFolder() throws {
        try FileManager.default.createDirectory(at: cropsFolder, withIntermediateDirectories: true)
    }

    func nextFilename(format: String) -> String {
        let existing = Set(entries.map(\.file))
        var n = 1
        while true {
            let name = String(format: "crop_%03d.%@", n, format)
            if !existing.contains(name) { return name }
            n += 1
        }
    }

    func add(_ entry: CropEntry) throws {
        entries.append(entry)
    }

    func remove(at index: Int) throws {
        guard entries.indices.contains(index) else { return }
        entries.remove(at: index)
    }
}

@MainActor
private final class FakeCueRepository: CueRepository {
    private(set) var cues: [Cue] = []
    var pending: [Cue] { cues.filter { !$0.done } }
    let sourceFilename = "Movie.mp4"

    func bindFileURL(_ url: URL) {}

    @discardableResult
    func add(at seconds: Double, label: String) throws -> Cue {
        addCue(t: seconds, label: label)
    }

    @discardableResult
    func addCue(t: Double, label: String = "") -> Cue {
        let cue = Cue(id: UUID().uuidString, t: t, label: label, done: false)
        cues.append(cue)
        cues.sort { $0.t < $1.t }
        return cue
    }

    func load(from url: URL) throws {}

    func cue(id: String) -> Cue? { cues.first { $0.id == id } }

    func markDone(_ id: String) throws { try setDone(id, done: true) }

    func setDone(_ id: String, done: Bool) throws {
        guard let i = cues.firstIndex(where: { $0.id == id }) else { return }
        cues[i].done = done
    }

    func updateLabel(_ id: String, label: String) throws {}
    func updateTime(_ id: String, seconds: Double) throws {}
    func remove(_ id: String) throws { cues.removeAll { $0.id == id } }

    func nearest(to seconds: Double, maxDelta: Double) -> Cue? {
        cues.min { abs($0.t - seconds) < abs($1.t - seconds) }
            .flatMap { abs($0.t - seconds) <= maxDelta ? $0 : nil }
    }

    func nextPending(after id: String?) -> Cue? {
        let pend = pending
        guard !pend.isEmpty else { return nil }
        guard let id else { return pend[0] }
        var seen = false
        for c in cues {
            if c.id == id { seen = true; continue }
            if seen && !c.done { return c }
        }
        return pend[0]
    }
}

private final class FakeImageEncoder: ImageEncoding {
    var fail = false
    private(set) var lastFormat: ExportImageFormat?

    func encode(_ image: CGImage, format: ExportImageFormat, jpegQuality: Double) -> Data? {
        lastFormat = format
        if fail { return nil }
        return Data([0x89, 0x50, 0x4E, 0x47])
    }
}
