import CoreGraphics
import XCTest
@testable import Snapframe

@MainActor
final class CropGeometryTests: XCTestCase {
    func testLetterboxFitsWidthLimitedVideo() {
        let letter = CropGeometry.letterbox(
            videoSize: CGSize(width: 1920, height: 1080),
            in: CGSize(width: 800, height: 800)
        )
        XCTAssertEqual(letter.width, 800, accuracy: 0.001)
        XCTAssertEqual(letter.height, 450, accuracy: 0.001)
        XCTAssertEqual(letter.minX, 0, accuracy: 0.001)
        XCTAssertEqual(letter.minY, 175, accuracy: 0.001)
    }

    func testLetterboxFitsHeightLimitedVideo() {
        let letter = CropGeometry.letterbox(
            videoSize: CGSize(width: 1080, height: 1920),
            in: CGSize(width: 800, height: 800)
        )
        XCTAssertEqual(letter.width, 450, accuracy: 0.001)
        XCTAssertEqual(letter.height, 800, accuracy: 0.001)
        XCTAssertEqual(letter.minX, 175, accuracy: 0.001)
        XCTAssertEqual(letter.minY, 0, accuracy: 0.001)
    }

    func testLetterboxZeroVideoReturnsZero() {
        XCTAssertEqual(
            CropGeometry.letterbox(videoSize: .zero, in: CGSize(width: 100, height: 100)),
            .zero
        )
    }

    func testViewRectMapsCropIntoLetterbox() {
        let letter = CGRect(x: 10, y: 20, width: 400, height: 200)
        let crop = CropRect(x: 100, y: 50, width: 200, height: 100)
        let view = CropGeometry.viewRect(
            crop: crop,
            letter: letter,
            videoSize: CGSize(width: 800, height: 400)
        )
        XCTAssertEqual(view.minX, 10 + 50, accuracy: 0.001)
        XCTAssertEqual(view.minY, 20 + 25, accuracy: 0.001)
        XCTAssertEqual(view.width, 100, accuracy: 0.001)
        XCTAssertEqual(view.height, 50, accuracy: 0.001)
    }
}
