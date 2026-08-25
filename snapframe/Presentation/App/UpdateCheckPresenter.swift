import AppKit

@MainActor
enum UpdateCheckPresenter {
    private static var isChecking = false

    static func checkForUpdates() {
        guard !isChecking else { return }
        isChecking = true

        Task {
            let result = await GitHubUpdateChecker.check()
            isChecking = false
            present(result)
        }
    }

    private static func present(_ result: UpdateCheckResult) {
        NSApp.activate(ignoringOtherApps: true)

        switch result {
        case .upToDate(let current):
            let alert = NSAlert()
            alert.messageText = "You’re up to date"
            alert.informativeText = "\(AppInfo.name) \(current) is the latest release."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()

        case .available(let latest, let releaseURL, let downloadURL):
            let alert = NSAlert()
            alert.messageText = "Update available"
            alert.informativeText = """
            \(AppInfo.name) \(latest) is available.
            You have \(AppInfo.shortVersion).
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Download")
            alert.addButton(withTitle: "View Release")
            alert.addButton(withTitle: "Later")
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                NSWorkspace.shared.open(downloadURL ?? releaseURL)
            case .alertSecondButtonReturn:
                NSWorkspace.shared.open(releaseURL)
            default:
                break
            }

        case .failed(let message):
            let alert = NSAlert()
            alert.messageText = "Couldn’t check for updates"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Open Releases")
            if alert.runModal() == .alertSecondButtonReturn {
                NSWorkspace.shared.open(AppInfo.repositoryURL.appendingPathComponent("releases"))
            }
        }
    }
}
