import Foundation
import XCTest
@testable import Snapframe

@MainActor
final class CueStoreTests: XCTestCase {
    private var directory: URL!
    private var store: CueStore!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapframe-cue-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = CueStore(sourceFilename: "Movie.mp4")
        store.bindFileURL(directory.appendingPathComponent("Movie.cues.json"))
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
        directory = nil
        store = nil
    }

    func testAddSortsByTimeAndPersists() throws {
        _ = try store.add(at: 3.0, label: "later")
        _ = try store.add(at: 1.25, label: "earlier")
        XCTAssertEqual(store.cues.map(\.t), [1.25, 3.0])
        XCTAssertEqual(store.pending.count, 2)

        let reloaded = CueStore(sourceFilename: "Movie.mp4")
        try reloaded.load(from: store.fileURL!)
        XCTAssertEqual(reloaded.cues.map(\.label), ["earlier", "later"])
    }

    func testNearestWithinDelta() throws {
        _ = try store.add(at: 10.0)
        _ = try store.add(at: 20.0)
        XCTAssertEqual(store.nearest(to: 10.2, maxDelta: 0.5)?.t, 10.0)
        XCTAssertNil(store.nearest(to: 10.2, maxDelta: 0.1))
    }

    func testMarkDoneAndNextPending() throws {
        let a = try store.add(at: 1)
        let b = try store.add(at: 2)
        let c = try store.add(at: 3)
        try store.markDone(a.id)
        XCTAssertEqual(store.pending.map(\.id), [b.id, c.id])
        XCTAssertEqual(store.nextPending(after: a.id)?.id, b.id)
        XCTAssertEqual(store.nextPending(after: b.id)?.id, c.id)
        XCTAssertEqual(store.nextPending(after: c.id)?.id, b.id)
    }

    func testUpdateTimeAndLabel() throws {
        let cue = try store.add(at: 5, label: "old")
        try store.updateLabel(cue.id, label: "new")
        try store.updateTime(cue.id, seconds: 1.5)
        XCTAssertEqual(store.cue(id: cue.id)?.label, "new")
        XCTAssertEqual(store.cue(id: cue.id)?.t, 1.5)
        XCTAssertEqual(store.cues.first?.t, 1.5)
    }

    func testRemove() throws {
        let cue = try store.add(at: 1)
        try store.remove(cue.id)
        XCTAssertTrue(store.cues.isEmpty)
    }

    func testLoadRejectsSourceMismatch() throws {
        let json = """
        {
          "format": "snapframe-cues",
          "version": 1,
          "source": "Other.mp4",
          "cues": [{ "t": 1.0, "label": "x" }]
        }
        """.data(using: .utf8)!
        let url = directory.appendingPathComponent("bad.cues.json")
        try json.write(to: url)
        XCTAssertThrowsError(try store.load(from: url)) { error in
            guard case CueError.sourceMismatch = error else {
                return XCTFail("expected sourceMismatch, got \(error)")
            }
        }
    }

    func testLoadAcceptsTimecodeField() throws {
        let json = """
        {
          "format": "snapframe-cues",
          "version": 1,
          "source": "Movie.mp4",
          "cues": [{ "timecode": "00:00:02.500", "label": "tc" }]
        }
        """.data(using: .utf8)!
        let url = directory.appendingPathComponent("tc.cues.json")
        try json.write(to: url)
        try store.load(from: url)
        XCTAssertEqual(store.cues.count, 1)
        XCTAssertEqual(store.cues[0].t, 2.5, accuracy: 0.0001)
        XCTAssertEqual(store.cues[0].label, "tc")
    }

    func testSidecarURL() {
        let video = URL(fileURLWithPath: "/tmp/clips/Movie.mp4")
        XCTAssertEqual(
            FileAccess.sidecarCuesURL(for: video).path,
            "/tmp/clips/Movie.cues.json"
        )
    }
}
