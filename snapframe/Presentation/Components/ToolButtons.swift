import SwiftUI

struct ToolButton: View {
    var systemName: String
    var kind: ToolButtonStyle.Kind = .normal
    var tooltip: String = ""
    var shortcut: String = ""
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
        }
        .buttonStyle(ToolButtonStyle(kind: kind))
        .snapTooltip(tooltip, shortcut: shortcut)
    }
}

struct ToolButtonStyle: ButtonStyle {
    enum Kind { case normal, accent, danger }

    static let size: CGFloat = 32
    var kind: Kind = .normal
    var width: CGFloat = size
    var height: CGFloat = size

    func makeBody(configuration: Configuration) -> some View {
        let fill: Color = switch kind {
        case .normal: SnapTheme.chip
        case .accent: SnapTheme.accent
        case .danger: SnapTheme.chip
        }
        let fg: Color = switch kind {
        case .normal: SnapTheme.ink
        case .accent: .white
        case .danger: Color(red: 0.72, green: 0.18, blue: 0.16)
        }

        configuration.label
            .foregroundStyle(fg)
            .frame(width: width, height: height)
            .background(RoundedRectangle(cornerRadius: 6).fill(fill.opacity(configuration.isPressed ? 0.8 : 1)))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(
                kind == .normal || kind == .danger ? SnapTheme.stroke : .clear, lineWidth: 1
            ))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(SnapMotion.fast, value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

struct FrameSkipButton: View {
    enum Direction { case backward, forward }

    let count: Int
    let direction: Direction
    var tooltip: String = ""
    var shortcut: String = ""
    let action: () -> Void

    private var systemName: String {
        switch (count, direction) {
        case (10, .backward): "chevron.backward.2"
        case (_, .backward): "chevron.backward"
        case (10, .forward): "chevron.forward.2"
        default: "chevron.forward"
        }
    }

    var body: some View {
        ToolButton(systemName: systemName, tooltip: tooltip, shortcut: shortcut, action: action)
    }
}
