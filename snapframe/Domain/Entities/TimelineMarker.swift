import Foundation

struct TimelineMarker: Identifiable, Equatable {
    enum Kind: Equatable { case cuePending, cueDone, cueActive, crop }

    var id: String
    var t: Double
    var kind: Kind
    var cueID: String?
}
