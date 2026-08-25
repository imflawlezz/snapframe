import Foundation

enum UpdateCheckResult: Equatable {
    case upToDate(current: String)
    case available(latest: String, releaseURL: URL, downloadURL: URL?)
    case failed(message: String)
}

enum GitHubUpdateChecker {
    private static let releasesURL = URL(string: "https://api.github.com/repos/imflawlezz/snapframe/releases/latest")!

    static func check(currentVersion: String = AppInfo.shortVersion) async -> UpdateCheckResult {
        do {
            let release = try await fetchLatestRelease()
            let latest = normalizeVersion(release.tagName)
            let current = normalizeVersion(currentVersion)
            guard !latest.isEmpty else {
                return .failed(message: "Latest release has no version tag.")
            }
            if compareVersions(current, latest) == .orderedAscending {
                return .available(
                    latest: latest,
                    releaseURL: release.htmlURL,
                    downloadURL: release.preferredDownloadURL
                )
            }
            return .upToDate(current: current.isEmpty ? currentVersion : current)
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }

    static func normalizeVersion(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("v") {
            value.removeFirst()
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = versionParts(lhs)
        let right = versionParts(rhs)
        let count = max(left.count, right.count)
        for index in 0..<count {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
        }
        return .orderedSame
    }

    private static func versionParts(_ version: String) -> [Int] {
        version.split(separator: ".").map { part in
            Int(part.filter(\.isNumber)) ?? 0
        }
    }

    private static func fetchLatestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: releasesURL)
        request.setValue("Snapframe/\(AppInfo.shortVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }

    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    var preferredDownloadURL: URL? {
        if let dmg = assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }) {
            return dmg.browserDownloadURL
        }
        return assets.first?.browserDownloadURL
    }
}
