import Foundation
import Observation

struct CueListFile: Codable {
    var format: String?
    var version: Int?
    var source: String
    var cues: [CueDTO]
}

struct CueDTO: Codable {
    var id: String?
    var t: Double?
    var timecode: String?
    var seconds: Double?
    var label: String?
    var done: Bool?
}

@Observable
@MainActor
final class CueStore: CueRepository {
    static let legacyFormat = "mkv-cropper-cues"
    static let formatID = "snapframe-cues"

    private(set) var cues: [Cue] = []

    let sourceFilename: String
    private(set) var fileURL: URL?

    var pending: [Cue] { cues.filter { !$0.done } }

    init(sourceFilename: String) {
        self.sourceFilename = sourceFilename
    }

    func bindFileURL(_ url: URL) {
        if fileURL == nil { fileURL = url }
    }

    @discardableResult
    func add(at seconds: Double, label: String = "") throws -> Cue {
        let t = (seconds * 1000).rounded() / 1000
        let cue = Cue(
            id: "cue_\(UUID().uuidString.prefix(8))",
            t: t,
            label: label,
            done: false
        )
        cues.append(cue)
        cues.sort { $0.t < $1.t }
        try save()
        return cue
    }

    func load(from url: URL) throws {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw CueError.readFailed(error.localizedDescription)
        }
        let file: CueListFile
        do {
            file = try JSONDecoder().decode(CueListFile.self, from: data)
        } catch {
            throw CueError.readFailed(error.localizedDescription)
        }
        if let fmt = file.format, fmt != Self.formatID && fmt != Self.legacyFormat {
            throw CueError.unknownFormat(fmt)
        }
        let src = (file.source as NSString).lastPathComponent
        if src != sourceFilename {
            throw CueError.sourceMismatch(expected: sourceFilename, got: file.source)
        }

        var parsed: [Cue] = []
        for (i, dto) in file.cues.enumerated() {
            let t: Double
            if let v = dto.t {
                t = v
            } else if let tc = dto.timecode, let v = Timecode.parse(tc) {
                t = v
            } else if let v = dto.seconds {
                t = v
            } else {
                throw CueError.badCue(i, "needs 't' or 'timecode'")
            }
            let id = dto.id ?? "cue_\(String(format: "%03d", i + 1))_\(UUID().uuidString.prefix(6))"
            parsed.append(Cue(id: id, t: t, label: dto.label ?? "", done: dto.done ?? false))
        }
        parsed.sort { $0.t < $1.t }
        cues = parsed
        fileURL = url
    }

    func save() throws {
        guard let fileURL else { return }
        let dtos = cues.map { c in
            CueDTO(
                id: c.id,
                t: (c.t * 1000).rounded() / 1000,
                timecode: c.timecode,
                seconds: nil,
                label: c.label,
                done: c.done
            )
        }
        let file = CueListFile(format: Self.formatID, version: 1, source: sourceFilename, cues: dtos)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try enc.encode(file)
        try data.write(to: fileURL, options: .atomic)
    }

    func cue(id: String) -> Cue? { cues.first { $0.id == id } }

    func markDone(_ id: String) throws {
        try setDone(id, done: true)
    }

    func setDone(_ id: String, done: Bool) throws {
        guard let i = cues.firstIndex(where: { $0.id == id }) else { return }
        cues[i].done = done
        try save()
    }

    func updateLabel(_ id: String, label: String) throws {
        guard let i = cues.firstIndex(where: { $0.id == id }) else { return }
        cues[i].label = label
        try save()
    }

    func updateTime(_ id: String, seconds: Double) throws {
        guard let i = cues.firstIndex(where: { $0.id == id }) else { return }
        cues[i].t = (max(0, seconds) * 1000).rounded() / 1000
        cues.sort { $0.t < $1.t }
        try save()
    }

    func remove(_ id: String) throws {
        cues.removeAll { $0.id == id }
        try save()
    }

    func nearest(to seconds: Double, maxDelta: Double = 0.35) -> Cue? {
        var best: Cue?
        var bestD = maxDelta
        for c in cues {
            let d = abs(c.t - seconds)
            if d <= bestD {
                best = c
                bestD = d
            }
        }
        return best
    }

    func cue(onSameFrameAs seconds: Double, fps: Double) -> Cue? {
        guard fps > 0 else { return nil }
        let frame = Timecode.frameIndex(at: seconds, fps: fps)
        return cues.first { Timecode.frameIndex(at: $0.t, fps: fps) == frame }
    }

    func nextPending(after id: String?) -> Cue? {
        let pend = pending
        guard !pend.isEmpty else { return nil }
        guard let id else { return pend[0] }
        var seen = false
        for c in cues {
            if c.id == id { seen = true; continue }
            if seen && !c.done { return c }
        }
        return pend[0]
    }
}
