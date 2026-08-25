import XCTest
@testable import Snapframe

final class GitHubUpdateCheckerTests: XCTestCase {
    func testNormalizeVersionStripsPrefix() {
        XCTAssertEqual(GitHubUpdateChecker.normalizeVersion("v1.3.0"), "1.3.0")
        XCTAssertEqual(GitHubUpdateChecker.normalizeVersion("V1.2.0"), "1.2.0")
        XCTAssertEqual(GitHubUpdateChecker.normalizeVersion(" 1.0.0 "), "1.0.0")
    }

    func testCompareVersions() {
        XCTAssertEqual(GitHubUpdateChecker.compareVersions("1.2.0", "1.3.0"), .orderedAscending)
        XCTAssertEqual(GitHubUpdateChecker.compareVersions("1.3.0", "1.2.0"), .orderedDescending)
        XCTAssertEqual(GitHubUpdateChecker.compareVersions("1.3.0", "1.3.0"), .orderedSame)
        XCTAssertEqual(GitHubUpdateChecker.compareVersions("1.3", "1.3.0"), .orderedSame)
        XCTAssertEqual(GitHubUpdateChecker.compareVersions("1.10.0", "1.9.0"), .orderedDescending)
    }
}
