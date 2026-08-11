import Foundation

enum CueSnapper {
    static func toleranceSeconds(fps: Double, frames: Int) -> Double {
        Double(max(1, frames)) / max(fps, 1)
    }

    static func snap(
        _ seconds: Double,
        cues: CueRepository?,
        enabled: Bool,
        tolerance: Double
    ) -> Double {
        guard enabled, let cues else { return seconds }
        return cues.nearest(to: seconds, maxDelta: tolerance)?.t ?? seconds
    }
}
