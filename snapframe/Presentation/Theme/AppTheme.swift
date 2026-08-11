import AppKit
import SwiftUI
import Observation

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark:  return "Dark"
        }
    }
}

@Observable
@MainActor
final class AppTheme {
    static let shared = AppTheme()

    var scheme: AppColorScheme {
        didSet {
            UserDefaults.standard.set(scheme.rawValue, forKey: "colorScheme")
            applyToWindows()
        }
    }

    var ink: Color           { isDark ? Color(white: 0.92)                         : Color(red: 0.08, green: 0.10, blue: 0.12) }
    var inkSecondary: Color  { isDark ? Color(white: 0.55)                         : Color(red: 0.28, green: 0.32, blue: 0.36) }
    var mist: Color          { isDark ? Color(red: 0.13, green: 0.14, blue: 0.16)  : Color(red: 0.88, green: 0.90, blue: 0.92) }
    var chip: Color          { isDark ? Color(red: 0.24, green: 0.26, blue: 0.29)  : Color(red: 0.82, green: 0.85, blue: 0.88) }
    var slate: Color         { isDark ? Color(white: 0.38)                         : Color(red: 0.62, green: 0.66, blue: 0.70) }
    var panel: Color         { isDark ? Color(red: 0.17, green: 0.18, blue: 0.20)  : Color(red: 0.965, green: 0.97, blue: 0.975) }
    var accent: Color        { Color(red: 0.34, green: 0.61, blue: 0.58) }
    var accentSoft: Color    { accent.opacity(0.20) }
    var warn: Color          { Color(red: 0.82, green: 0.40, blue: 0.12) }
    var good: Color          { Color(red: 0.18, green: 0.55, blue: 0.34) }
    var videoWell: Color     { Color(red: 0.06, green: 0.07, blue: 0.08) }
    var stroke: Color        { isDark ? Color(white: 1.0).opacity(0.10)            : Color(red: 0.08, green: 0.10, blue: 0.12).opacity(0.18) }
    var fieldBg: Color       { isDark ? Color(red: 0.10, green: 0.11, blue: 0.13)  : Color.white }
    var fieldText: Color     { isDark ? Color(white: 0.88)                         : Color.black }

    let displayFont = Font.custom("Avenir Next Condensed", size: 42).weight(.semibold)
    let titleFont   = Font.custom("Avenir Next", size: 14).weight(.semibold)
    let bodyFont    = Font.custom("Avenir Next", size: 13).weight(.medium)
    let mono        = Font.system(size: 12, weight: .medium, design: .monospaced)

    var swiftUIScheme: ColorScheme? {
        switch resolvedScheme {
        case .light: return .light
        case .dark:  return .dark
        case .system: return nil
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "colorScheme") ?? "system"
        scheme = AppColorScheme(rawValue: saved) ?? .system
    }

    private var isDark: Bool {
        switch scheme {
        case .dark: return true
        case .light: return false
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }

    private var resolvedScheme: AppColorScheme {
        if scheme == .system { return isDark ? .dark : .light }
        return scheme
    }

    func applyToWindows() {
        let appearance: NSAppearance? = switch resolvedScheme {
        case .dark:  NSAppearance(named: .darkAqua)
        case .light: NSAppearance(named: .aqua)
        case .system: nil
        }
        NSApp.appearance = appearance
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .shared
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
