import SwiftUI

struct ToolButton: View {
    var systemName: String
    var kind: ToolButtonStyle.Kind = .normal
    var tooltip: String = ""
    var shortcut: String = ""
    var action: () -> Void

    init(systemName: String, kind: ToolButtonStyle.Kind = .normal,
         tooltip: String = "", shortcut: String = "", help: String = "",
         action: @escaping () -> Void) {
        self.systemName = systemName
        self.kind = kind
        self.tooltip = tooltip.isEmpty ? help : tooltip
        self.shortcut = shortcut
        self.action = action
    }

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
            .contentShape(Rectangle())
    }
}
