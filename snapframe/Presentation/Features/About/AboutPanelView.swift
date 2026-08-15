import AppKit
import SwiftUI

struct AboutPanelView: View {
    @State private var theme = AppTheme.shared

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 72, height: 72)

                VStack(spacing: 2) {
                    Text(AppInfo.name)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(AppInfo.versionLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Text(AppInfo.aboutBlurb)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 240)

            VStack(spacing: 8) {
                Text(AppInfo.aboutStack)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                madeWithLine
            }

            Text("\(AppInfo.licenseName) · \(AppInfo.copyright)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary.opacity(0.85))
        }
        .padding(.horizontal, 28)
        .padding(.top, 36)
        .padding(.bottom, 22)
        .frame(width: 312)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(theme.swiftUIScheme)
    }

    private var madeWithLine: some View {
        HStack(spacing: 4) {
            Text("Made with")
                .foregroundStyle(.secondary)
            Image(systemName: "heart.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color(red: 0.86, green: 0.28, blue: 0.34))
                .accessibilityLabel("love")
            Text("by")
                .foregroundStyle(.secondary)
            Link(AppInfo.developer, destination: AppInfo.developerURL)
                .foregroundStyle(.primary)
                .underline(false)
        }
        .font(.system(size: 12, weight: .medium))
    }
}

@MainActor
enum AboutPanelController {
    private static var panel: NSPanel?
    private static var hosting: NSHostingController<AboutPanelView>?

    static func show() {
        NSApp.activate(ignoringOtherApps: true)

        if let panel, let hosting {
            hosting.rootView = AboutPanelView()
            panel.contentViewController = hosting
            panel.setContentSize(hosting.sizeThatFits(in: NSSize(width: 312, height: 2000)))
            panel.center()
            panel.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: AboutPanelView())
        hosting.sizingOptions = [.intrinsicContentSize]
        let fitting = hosting.sizeThatFits(in: NSSize(width: 312, height: 2000))

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: fitting),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = ""
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.contentViewController = hosting
        panel.center()
        panel.makeKeyAndOrderFront(nil)

        self.hosting = hosting
        self.panel = panel
    }
}
