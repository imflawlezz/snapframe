import Foundation
import XCTest
@testable import Snapframe

@MainActor
final class CropEntryCodingTests: XCTestCase {
    func testEncodeDecodeRoundTrip() throws {
        let entry = CropEntry(
            file: "crop_001.png",
            timecode: "00:00:01.500",
            timecodeSeconds: 1.5,
            x: 10,
            y: 20,
            width: 320,
            height: 240,
            videoWidth: 1920,
            videoHeight: 1080
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(CropEntry.self, from: data)
        XCTAssertEqual(decoded, entry)
    }

    func testDecodeLegacySquareSize() throws {
        let json = """
        {
          "file": "crop_001.png",
          "timecode": "00:00:00.000",
          "timecode_seconds": 0,
          "crop": { "x": 5, "y": 7, "size": 128 },
          "video_size": { "width": 640, "height": 360 }
        }
        """.data(using: .utf8)!
        let entry = try JSONDecoder().decode(CropEntry.self, from: json)
        XCTAssertEqual(entry.width, 128)
        XCTAssertEqual(entry.height, 128)
        XCTAssertEqual(entry.x, 5)
        XCTAssertEqual(entry.y, 7)
    }

    func testMetadataFileUsesSnakeCaseKeys() throws {
        let file = CropMetadataFile(
            source: "Movie.mp4",
            sourcePath: "/tmp/Movie.mp4",
            crops: []
        )
        let data = try JSONEncoder().encode(file)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["source"] as? String, "Movie.mp4")
        XCTAssertEqual(object["source_path"] as? String, "/tmp/Movie.mp4")
        XCTAssertNotNil(object["crops"])
    }
}
