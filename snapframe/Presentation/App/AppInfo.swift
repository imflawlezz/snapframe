import Foundation

enum AppInfo {
    static var shortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static var windowTitle: String {
        "Snapframe \(shortVersion)"
    }

    static var versionLabel: String {
        "Version \(shortVersion) (build \(buildNumber))"
    }
}
