import SwiftUI

@MainActor
enum SnapTheme {
    static var ink: Color          { AppTheme.shared.ink }
    static var inkSecondary: Color { AppTheme.shared.inkSecondary }
    static var mist: Color         { AppTheme.shared.mist }
    static var chip: Color         { AppTheme.shared.chip }
    static var slate: Color        { AppTheme.shared.slate }
    static var panel: Color        { AppTheme.shared.panel }
    static var accent: Color       { AppTheme.shared.accent }
    static var accentSoft: Color   { AppTheme.shared.accentSoft }
    static var warn: Color         { AppTheme.shared.warn }
    static var warnSoft: Color     { AppTheme.shared.warnSoft }
    static var cue: Color          { AppTheme.shared.cue }
    static var cuePending: Color   { AppTheme.shared.cuePending }
    static var crop: Color         { AppTheme.shared.crop }
    static var good: Color         { AppTheme.shared.good }
    static var videoWell: Color    { AppTheme.shared.videoWell }
    static var stroke: Color       { AppTheme.shared.stroke }
    static var fieldBg: Color      { AppTheme.shared.fieldBg }
    static var fieldText: Color    { AppTheme.shared.fieldText }
    static var timelineSurface: Color { AppTheme.shared.timelineSurface }
    static var timelineTrack: Color   { AppTheme.shared.timelineTrack }
    static var timelineGrid: Color    { AppTheme.shared.timelineGrid }
    static var timelineGridMinor: Color { AppTheme.shared.timelineGridMinor }
    static var timelineGridMajor: Color { AppTheme.shared.timelineGridMajor }
    static var timelinePlayheadStem: Color { AppTheme.shared.timelinePlayheadStem }

    static let displayFont = Font.custom("Avenir Next Condensed", size: 42).weight(.semibold)
    static let titleFont   = Font.custom("Avenir Next", size: 14).weight(.semibold)
    static let bodyFont    = Font.custom("Avenir Next", size: 13).weight(.medium)
    static let mono        = Font.system(size: 12, weight: .medium, design: .monospaced)
}
