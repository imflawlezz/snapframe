import Foundation

@MainActor
protocol CueRepository: AnyObject {
    var cues: [Cue] { get }
    var activeID: String? { get set }
    var pending: [Cue] { get }
    var sourceFilename: String { get }

    func load(from url: URL) throws
    func cue(id: String) -> Cue?
    func markDone(_ id: String) throws
    func remove(_ id: String) throws
    func nearest(to seconds: Double, maxDelta: Double) -> Cue?
    func nextPending(after id: String?) -> Cue?
    func prevPending(before id: String?) -> Cue?
}
