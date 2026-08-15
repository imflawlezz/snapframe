import AppKit
import Foundation

enum AppInfo {
    static let name = "Snapframe"
    static let developer = "imflawlezz"
    static let developerURL = URL(string: "https://github.com/imflawlezz")!
    static let repositoryURL = URL(string: "https://github.com/imflawlezz/snapframe")!
    static let licenseName = "MIT License"
    static let copyright = "Copyright © 2026 imflawlezz"

    static let aboutBlurb =
        "Scrub video frame by frame, mark cues to jump between moments, and export still crops next to the source file."
    static let aboutStack = "SwiftUI · AppKit · AVFoundation"

    static var shortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static var windowTitle: String {
        "\(name) \(shortVersion)"
    }

    static var versionLabel: String {
        "Version \(shortVersion) (\(buildNumber))"
    }

    @MainActor
    static func showAboutPanel() {
        AboutPanelController.show()
    }
}
