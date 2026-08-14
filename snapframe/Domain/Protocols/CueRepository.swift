import Foundation

@MainActor
protocol CueRepository: AnyObject {
    var cues: [Cue] { get }
    var pending: [Cue] { get }
    var sourceFilename: String { get }

    func bindFileURL(_ url: URL)
    @discardableResult
    func add(at seconds: Double, label: String) throws -> Cue
    func load(from url: URL) throws
    func cue(id: String) -> Cue?
    func markDone(_ id: String) throws
    func setDone(_ id: String, done: Bool) throws
    func updateLabel(_ id: String, label: String) throws
    func updateTime(_ id: String, seconds: Double) throws
    func remove(_ id: String) throws
    func nearest(to seconds: Double, maxDelta: Double) -> Cue?
    func nextPending(after id: String?) -> Cue?
}
