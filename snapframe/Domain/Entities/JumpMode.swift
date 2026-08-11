import Foundation

enum JumpMode: String, CaseIterable, Identifiable {
    case time
    case frame

    var id: String { rawValue }
    var label: String { self == .time ? "Time" : "Frame" }
}
