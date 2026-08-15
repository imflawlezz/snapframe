import XCTest
@testable import Snapframe

@MainActor
final class TimecodeTests: XCTestCase {

    // MARK: - Compact digits

    func testParseCompactSeconds() {
        assertParse("1", 1)
        assertParse("12", 12)
        assertParse("90", 90)
        assertParse("00", 0)
    }

    func testParseCompactMinutesSeconds() {
        assertParse("123", hms(0, 1, 23))
        assertParse("1234", hms(0, 12, 34))
        assertParse("100", hms(0, 1, 0))
    }

    func testParseCompactHoursMinutesSeconds() {
        assertParse("12345", hms(1, 23, 45))
        assertParse("123456", hms(12, 34, 56))
    }

    func testParseCompactMilliseconds() {
        assertParse("1234567", hms(12, 34, 56.7))
        assertParse("12345678", hms(12, 34, 56.78))
        assertParse("123456789", hms(12, 34, 56.789))
    }

    // MARK: - Separated fields

    func testParseColonFields() {
        assertParse("1:23", hms(0, 1, 23))
        assertParse("1:23:45", hms(1, 23, 45))
        assertParse("01:23:45.678", hms(1, 23, 45.678))
        assertParse("00:00:01.000", 1)
        assertParse("1:23.5", hms(0, 1, 23.5))
        assertParse("12:34", hms(0, 12, 34))
    }

    func testParseLenientSeparators() {
        let expected = hms(1, 23, 45)
        assertParse("1.23.45", expected)
        assertParse("1,23,45", expected)
        assertParse("1-23-45", expected)
        assertParse("1 23 45", expected)
        assertParse("1;23;45", expected)
        assertParse("1/23/45", expected)
        assertParse("1:23:45:6", hms(1, 23, 45.6))
    }

    func testParseSingleDecimalIsFractionalSeconds() {
        assertParse("12.5", 12.5)
        assertParse("12,5", 12.5)
        assertParse("83.5", 83.5)
        assertParse(".5", 0.5)
    }

    func testParseCompactWithDecimal() {
        assertParse("1234.5", hms(0, 12, 34.5))
        assertParse("123456.789", hms(12, 34, 56.789))
    }

    func testParseTrimsWhitespaceAndEmptyFields() {
        assertParse("  12:34  ", hms(0, 12, 34))
        assertParse("1::45", hms(0, 1, 45))
    }

    func testParseRejectsInvalidInput() {
        XCTAssertNil(Timecode.parse(""))
        XCTAssertNil(Timecode.parse("   "))
        XCTAssertNil(Timecode.parse("abc"))
        XCTAssertNil(Timecode.parse("#12"))
        XCTAssertNil(Timecode.parse("f12"))
        XCTAssertNil(Timecode.parse("F12"))
        XCTAssertNil(Timecode.parse(":"))
        XCTAssertNil(Timecode.parse("..."))
    }

    // MARK: - Format

    func testFormat() {
        XCTAssertEqual(Timecode.format(0), "00:00:00.000")
        XCTAssertEqual(Timecode.format(1), "00:00:01.000")
        XCTAssertEqual(Timecode.format(hms(0, 12, 34)), "00:12:34.000")
        XCTAssertEqual(Timecode.format(hms(1, 23, 45.678)), "01:23:45.678")
        XCTAssertEqual(Timecode.format(-1), "00:00:00.000")
        XCTAssertEqual(Timecode.format(.nan), "00:00:00.000")
    }

    func testFormatParseRoundTrip() {
        let samples: [Double] = [0, 1, 12.5, 83, 754, 5025.678]
        for seconds in samples {
            assertParse(Timecode.format(seconds), seconds)
        }
    }

    func testDisplay() {
        XCTAssertEqual(Timecode.display(seconds: 5, mode: .time, fps: 24), "00:00:05.000")
        XCTAssertEqual(Timecode.display(seconds: 5, mode: .frame, fps: 24), "f120")
    }

    // MARK: - Frames

    func testParseFrame() {
        XCTAssertEqual(Timecode.parseFrame("12"), 12)
        XCTAssertEqual(Timecode.parseFrame("f12"), 12)
        XCTAssertEqual(Timecode.parseFrame("#12"), 12)
        XCTAssertEqual(Timecode.parseFrame("  F24  "), 24)
        XCTAssertNil(Timecode.parseFrame(""))
        XCTAssertNil(Timecode.parseFrame("12.5"))
        XCTAssertNil(Timecode.parseFrame("abc"))
    }

    func testFrameIndexAndSeconds() {
        XCTAssertEqual(Timecode.frameIndex(at: 1, fps: 24), 24)
        XCTAssertEqual(Timecode.frameIndex(at: 0.5, fps: 24), 12)
        XCTAssertEqual(Timecode.frameIndex(at: 1, fps: 0), 0)
        XCTAssertEqual(Timecode.seconds(forFrame: 24, fps: 24), 1, accuracy: 0.0001)
        XCTAssertEqual(Timecode.seconds(forFrame: -1, fps: 24), 0)
        XCTAssertEqual(Timecode.seconds(forFrame: 10, fps: 0), 0)
    }

    func testSnapped() {
        let frame24 = Timecode.seconds(forFrame: 24, fps: 24)
        let frame47 = Timecode.seconds(forFrame: 47, fps: 24)
        XCTAssertEqual(Timecode.snapped(seconds: 1.02, fps: 24), frame24, accuracy: 0.0001)
        XCTAssertEqual(Timecode.snapped(seconds: -1, fps: 24), 0, accuracy: 0.0001)
        XCTAssertEqual(Timecode.snapped(seconds: 100, fps: 24, duration: 2), frame47, accuracy: 0.0001)
        XCTAssertEqual(Timecode.snapped(seconds: 1.5, fps: 0), 1.5, accuracy: 0.0001)
    }

    private func hms(_ hours: Int, _ minutes: Int, _ seconds: Double) -> Double {
        Double(hours * 3600 + minutes * 60) + seconds
    }

    private func assertParse(
        _ input: String,
        _ expected: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let got = Timecode.parse(input) else {
            XCTFail("parse(\(input.debugDescription)) was nil, expected \(expected)", file: file, line: line)
            return
        }
        XCTAssertEqual(got, expected, accuracy: 0.0001, "parse(\(input.debugDescription))", file: file, line: line)
    }
}
