import Foundation

enum Timecode {
    static func format(_ seconds: Double) -> String {
        var s = seconds
        if s.isNaN || s < 0 { s = 0 }
        let totalMs = Int((s * 1000).rounded())
        let ms = totalMs % 1000
        let totalS = totalMs / 1000
        let sec = totalS % 60
        let totalM = totalS / 60
        let min = totalM % 60
        let hour = totalM / 60
        return String(format: "%02d:%02d:%02d.%03d", hour, min, sec, ms)
    }

    static func parse(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return nil }
        if cleaned.hasPrefix("#") || cleaned.hasPrefix("f") {
            return nil
        }
        if !cleaned.contains(":") {
            return Double(cleaned)
        }
        let parts = cleaned.split(separator: ":").map(String.init)
        if parts.count == 2, let m = Int(parts[0]), let s = Double(parts[1]) {
            return Double(m) * 60 + s
        }
        if parts.count == 3, let h = Int(parts[0]), let m = Int(parts[1]), let s = Double(parts[2]) {
            return Double(h) * 3600 + Double(m) * 60 + s
        }
        return nil
    }

    static func parseFrame(_ text: String) -> Int? {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t.hasPrefix("#") { t.removeFirst() }
        if t.hasPrefix("f") { t.removeFirst() }
        guard !t.isEmpty, t.allSatisfy(\.isNumber) else { return nil }
        return Int(t)
    }

    static func frameIndex(at seconds: Double, fps: Double) -> Int {
        guard fps > 0 else { return 0 }
        return max(0, Int((seconds * fps).rounded()))
    }

    static func seconds(forFrame index: Int, fps: Double) -> Double {
        guard fps > 0, index >= 0 else { return 0 }
        return Double(index) / fps
    }

    static func snapped(seconds: Double, fps: Double, duration: Double = .infinity) -> Double {
        guard fps > 0 else { return max(0, seconds) }
        let maxFrame: Int
        if duration.isFinite, duration > 0 {
            maxFrame = max(0, Int(floor((duration - 1e-9) * fps)))
        } else {
            maxFrame = .max
        }
        let frame = min(maxFrame, max(0, frameIndex(at: seconds, fps: fps)))
        return Self.seconds(forFrame: frame, fps: fps)
    }
}
