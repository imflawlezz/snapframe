import CoreGraphics
import XCTest
@testable import Snapframe

@MainActor
final class CropRectTests: XCTestCase {
    private let video = CGSize(width: 1920, height: 1080)

    func testCenterPlacesRectInMiddle() {
        var crop = CropRect(x: 0, y: 0, width: 200, height: 100)
        crop.center(in: video)
        XCTAssertEqual(crop.x, (1920 - 200) / 2)
        XCTAssertEqual(crop.y, (1080 - 100) / 2)
        XCTAssertEqual(crop.width, 200)
        XCTAssertEqual(crop.height, 100)
    }

    func testClampKeepsRectInsideVideo() {
        var crop = CropRect(x: 1900, y: 1000, width: 200, height: 200)
        crop.clamp(in: video)
        XCTAssertEqual(crop.width, 200)
        XCTAssertEqual(crop.height, 200)
        XCTAssertEqual(crop.x, 1720)
        XCTAssertEqual(crop.y, 880)
    }

    func testClampShrinksWhenLargerThanVideo() {
        var crop = CropRect(x: 0, y: 0, width: 5000, height: 4000)
        crop.clamp(in: video)
        XCTAssertEqual(crop.width, 1920)
        XCTAssertEqual(crop.height, 1080)
        XCTAssertEqual(crop.x, 0)
        XCTAssertEqual(crop.y, 0)
    }

    func testSetWidthFree() {
        var crop = CropRect(x: 100, y: 100, width: 200, height: 150)
        crop.setWidth(300, in: video, lock: .free)
        XCTAssertEqual(crop.width, 300)
        XCTAssertEqual(crop.height, 150)
        XCTAssertEqual(crop.centerX, 100 + 200 / 2)
    }

    func testSetHeightSquareLock() {
        var crop = CropRect(x: 100, y: 100, width: 200, height: 150)
        crop.setHeight(240, in: video, lock: .square)
        XCTAssertEqual(crop.width, 240)
        XCTAssertEqual(crop.height, 240)
    }

    func testSetWidthAspectLockKeepsRatio() {
        var crop = CropRect(x: 100, y: 100, width: 200, height: 100)
        crop.setWidth(400, in: video, lock: .ratio(width: 2, height: 1))
        XCTAssertEqual(crop.width, 400)
        XCTAssertEqual(crop.height, 200)
    }

    func testAspectLockStopsAtVideoBounds() {
        var crop = CropRect(x: 0, y: 0, width: 100, height: 100)
        crop.setWidth(5000, in: video, lock: .ratio(width: 1, height: 1))
        XCTAssertEqual(crop.width, crop.height)
        XCTAssertLessThanOrEqual(crop.width, 1080)
        XCTAssertLessThanOrEqual(crop.height, 1080)
    }

    func testCenterOffsetRoundTrip() {
        var crop = CropRect(x: 0, y: 0, width: 320, height: 240)
        crop.center(in: video)
        let offset = crop.centerOffset(in: video)
        crop.setCenterOffset(dx: offset.dx + 40, dy: offset.dy - 20, in: video)
        let again = crop.centerOffset(in: video)
        XCTAssertEqual(again.dx, offset.dx + 40)
        XCTAssertEqual(again.dy, offset.dy - 20)
    }

    func testScaledToImageMapsVideoCoords() {
        let crop = CropRect(x: 100, y: 50, width: 200, height: 100)
        let rect = crop.scaledToImage(
            imageWidth: 960,
            imageHeight: 540,
            videoWidth: 1920,
            videoHeight: 1080
        )
        XCTAssertEqual(rect, CGRect(x: 50, y: 25, width: 100, height: 50))
    }

    func testScaledToImageRejectsOutOfBounds() {
        let crop = CropRect(x: 1800, y: 0, width: 200, height: 100)
        let rect = crop.scaledToImage(
            imageWidth: 100,
            imageHeight: 100,
            videoWidth: 1920,
            videoHeight: 1080
        )
        XCTAssertNil(rect)
    }

    func testMinimumSideIsSixteen() {
        var crop = CropRect(x: 10, y: 10, width: 100, height: 100)
        crop.setWidth(1, in: video, lock: .free)
        XCTAssertEqual(crop.width, 16)
    }
}
