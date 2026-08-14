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

    var inspectorWidth: Double {
        didSet { UserDefaults.standard.set(inspectorWidth, forKey: Keys.inspectorWidth) }
    }

    var cuesPaneFraction: Double {
        didSet { UserDefaults.standard.set(cuesPaneFraction, forKey: Keys.cuesPaneFraction) }
    }

    var volume: Double {
        didSet { UserDefaults.standard.set(volume, forKey: Keys.volume) }
    }

    var pauseOnFocusLoss: Bool {
        didSet { UserDefaults.standard.set(pauseOnFocusLoss, forKey: Keys.pauseOnFocusLoss) }
    }

    var snapToCues: Bool {
        didSet { UserDefaults.standard.set(snapToCues, forKey: Keys.snapToCues) }
    }

    var cueSnapToleranceSeconds: Double {
        didSet { UserDefaults.standard.set(cueSnapToleranceSeconds, forKey: Keys.cueSnapSeconds) }
    }

    var cueSnapToleranceFrames: Int {
        didSet { UserDefaults.standard.set(cueSnapToleranceFrames, forKey: Keys.cueSnapFrames) }
    }

    private enum Keys {
        static let exportFormat = "pref.exportFormat"
        static let jpegQuality = "pref.jpegQuality"
        static let markCueDone = "pref.markCueDoneOnSave"
        static let advanceCue = "pref.advanceToNextCueAfterSave"
        static let autoImportCues = "pref.autoImportSidecarCues"
        static let inspectorWidth = "pref.inspectorWidth"
        static let cuesPaneFraction = "pref.cuesPaneFraction"
        static let volume = "pref.volume"
        static let pauseOnFocusLoss = "pref.pauseOnFocusLoss"
        static let snapToCues = "pref.snapToCuesOnSeek"
        static let cueSnapSeconds = "pref.cueSnapToleranceSeconds"
        static let cueSnapFrames = "pref.cueSnapToleranceFrames"

        static let obsolete = [
            "pref.playbackPreviewRate",
            "pref.playbackPreviewResolution",
        ]
    }

    private init() {
        Self.removeObsoleteKeys()
        let d = UserDefaults.standard
        exportFormat = ExportImageFormat(rawValue: d.string(forKey: Keys.exportFormat) ?? "") ?? .png
        jpegQuality = d.object(forKey: Keys.jpegQuality) as? Double ?? 0.92
        markCueDoneOnSave = d.object(forKey: Keys.markCueDone) as? Bool ?? true
        advanceToNextCueAfterSave = d.object(forKey: Keys.advanceCue) as? Bool ?? true
        autoImportSidecarCues = d.object(forKey: Keys.autoImportCues) as? Bool ?? true
        let savedInspectorWidth = d.object(forKey: Keys.inspectorWidth) as? Double ?? 304
        inspectorWidth = min(480, max(240, savedInspectorWidth))
        cuesPaneFraction = d.object(forKey: Keys.cuesPaneFraction) as? Double ?? 0.42
        volume = d.object(forKey: Keys.volume) as? Double ?? 100
        pauseOnFocusLoss = d.object(forKey: Keys.pauseOnFocusLoss) as? Bool ?? true
        snapToCues = d.object(forKey: Keys.snapToCues) as? Bool ?? false
        let savedSnapSeconds = d.object(forKey: Keys.cueSnapSeconds) as? Double ?? 0.35
        cueSnapToleranceSeconds = min(2, max(0.05, savedSnapSeconds))
        let savedSnapFrames = d.object(forKey: Keys.cueSnapFrames) as? Int ?? 5
        cueSnapToleranceFrames = min(30, max(1, savedSnapFrames))
    }

    func resetToDefaults() {
        exportFormat = .png
        jpegQuality = 0.92
        markCueDoneOnSave = true
        advanceToNextCueAfterSave = true
        autoImportSidecarCues = true
        inspectorWidth = 304
        cuesPaneFraction = 0.42
        volume = 100
        pauseOnFocusLoss = true
        snapToCues = false
        cueSnapToleranceSeconds = 0.35
        cueSnapToleranceFrames = 5
        Self.removeObsoleteKeys()
    }

    private static func removeObsoleteKeys() {
        let d = UserDefaults.standard
        for key in Keys.obsolete {
            d.removeObject(forKey: key)
        }
    }
}
