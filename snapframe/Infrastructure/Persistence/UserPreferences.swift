import Foundation
import Observation

@Observable
@MainActor
final class UserPreferences {
    static let shared = UserPreferences()

    var exportFormat: ExportImageFormat {
        didSet { UserDefaults.standard.set(exportFormat.rawValue, forKey: Keys.exportFormat) }
    }

    var jpegQuality: Double {
        didSet { UserDefaults.standard.set(jpegQuality, forKey: Keys.jpegQuality) }
    }

    var markCueDoneOnSave: Bool {
        didSet { UserDefaults.standard.set(markCueDoneOnSave, forKey: Keys.markCueDone) }
    }

    var advanceToNextCueAfterSave: Bool {
        didSet { UserDefaults.standard.set(advanceToNextCueAfterSave, forKey: Keys.advanceCue) }
    }

    var autoImportSidecarCues: Bool {
        didSet { UserDefaults.standard.set(autoImportSidecarCues, forKey: Keys.autoImportCues) }
    }

    var snapToCuesOnSeek: Bool {
        didSet { UserDefaults.standard.set(snapToCuesOnSeek, forKey: Keys.snapToCues) }
    }

    var cueSnapToleranceFrames: Int {
        didSet { UserDefaults.standard.set(cueSnapToleranceFrames, forKey: Keys.snapTolerance) }
    }

    private enum Keys {
        static let exportFormat = "pref.exportFormat"
        static let jpegQuality = "pref.jpegQuality"
        static let markCueDone = "pref.markCueDoneOnSave"
        static let advanceCue = "pref.advanceToNextCueAfterSave"
        static let autoImportCues = "pref.autoImportSidecarCues"
        static let snapToCues = "pref.snapToCuesOnSeek"
        static let snapTolerance = "pref.cueSnapToleranceFrames"
    }

    private init() {
        let d = UserDefaults.standard
        exportFormat = ExportImageFormat(rawValue: d.string(forKey: Keys.exportFormat) ?? "") ?? .png
        jpegQuality = d.object(forKey: Keys.jpegQuality) as? Double ?? 0.92
        markCueDoneOnSave = d.object(forKey: Keys.markCueDone) as? Bool ?? true
        advanceToNextCueAfterSave = d.object(forKey: Keys.advanceCue) as? Bool ?? true
        autoImportSidecarCues = d.object(forKey: Keys.autoImportCues) as? Bool ?? true
        snapToCuesOnSeek = d.object(forKey: Keys.snapToCues) as? Bool ?? true
        cueSnapToleranceFrames = d.object(forKey: Keys.snapTolerance) as? Int ?? 4
    }

    func resetToDefaults() {
        exportFormat = .png
        jpegQuality = 0.92
        markCueDoneOnSave = true
        advanceToNextCueAfterSave = true
        autoImportSidecarCues = true
        snapToCuesOnSeek = true
        cueSnapToleranceFrames = 4
    }
}
