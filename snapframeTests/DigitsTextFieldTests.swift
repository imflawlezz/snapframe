import XCTest
@testable import Snapframe

@MainActor
final class DigitsTextFieldTests: XCTestCase {
    func testFilterAllowsTimecodeSeparators() {
        let raw = "1:23;45.678,9-0/1 2"
        let filtered = DigitsTextField.filter(
            raw,
            allowsNegative: false,
            allowsTimecodeChars: true
        )
        XCTAssertEqual(filtered, raw)
    }

    func testFilterRejectsLettersWhenTimecode() {
        let filtered = DigitsTextField.filter(
            "1a:2b3",
            allowsNegative: false,
            allowsTimecodeChars: true
        )
        XCTAssertEqual(filtered, "1:23")
    }

    func testFilterDigitsOnlyByDefault() {
        let filtered = DigitsTextField.filter(
            "12:34.5",
            allowsNegative: false,
            allowsTimecodeChars: false
        )
        XCTAssertEqual(filtered, "12345")
    }
}
