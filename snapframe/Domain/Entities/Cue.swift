import Foundation

struct Cue: Identifiable, Equatable, Hashable {
    var id: String
    var t: Double
    var label: String
    var done: Bool

    var timecode: String { Timecode.format(t) }
}

enum CueError: LocalizedError {
    case readFailed(String)
    case unknownFormat(String)
    case missingSource
    case sourceMismatch(expected: String, got: String)
    case badCue(Int, String)

    var errorDescription: String? {
        switch self {
        case .readFailed(let s): return "Cannot read JSON: \(s)"
        case .unknownFormat(let f): return "Unknown format \(f)"
        case .missingSource: return "Missing required field 'source'"
        case .sourceMismatch(let e, let g): return "Cues are for \(g), but open video is \(e)"
        case .badCue(let i, let m): return "cues[\(i)]: \(m)"
        }
    }
}
