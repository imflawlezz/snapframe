import Foundation

enum Timecode {
    static func display(seconds: Double, mode: JumpMode, fps: Double) -> String {
        switch mode {
        case .time:
            return format(seconds)
        case .frame:
            return "f\(frameIndex(at: seconds, fps: fps))"
        }
    }

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

    /// Parses a timecode typed in the seek or cue fields.
    ///
    /// Digit runs are read from the right, like an NLE:
    /// `1`/`12` → seconds, `123`/`1234` → `M:SS` / `MM:SS`,
    /// `12345`/`123456` → `H:MM:SS` / `HH:MM:SS`, extra digits → milliseconds
    /// (`1234567` → `12:34:56.700`).
    ///
    /// Separators `: ; . , - /` and spaces are interchangeable. A single
    /// `.` or `,` with no other separators is fractional seconds (`12.5`).
    static func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("#") || lower.hasPrefix("f") { return nil }

        let cleaned = trimmed.filter { $0.isNumber || Self.timecodeSeparatorChars.contains($0) }
        guard cleaned.contains(where: \.isNumber) else { return nil }

        let hasFieldSep = cleaned.contains(where: { Self.fieldSeparatorChars.contains($0) })
        let decimalCount = cleaned.reduce(0) { $1 == "." || $1 == "," ? $0 + 1 : $0 }

        if !hasFieldSep {
            if decimalCount == 0 {
                return parseCompactDigits(cleaned.filter(\.isNumber))
            }
            if decimalCount == 1 {
                return parseCompactWithDecimal(cleaned)
            }
            return parseFields(splitFields(cleaned, separators: Self.timecodeSeparatorChars))
        }

        return parseFields(splitFields(cleaned, separators: Self.fieldSeparatorChars))
    }

    private static let fieldSeparatorChars: Set<Character> = [":", ";", "/", "-", " ", "\t"]
    private static let timecodeSeparatorChars: Set<Character> = [":", ";", ".", ",", "/", "-", " ", "\t"]

    private static func splitFields(_ text: String, separators: Set<Character>) -> [String] {
        var parts: [String] = []
        var current = ""
        for ch in text {
            if separators.contains(ch) {
                parts.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        parts.append(current)
        return parts
    }

    private static func parseFields(_ rawParts: [String]) -> Double? {
        let parts = rawParts.map { $0.trimmingCharacters(in: .whitespaces) }
        let nonempty = parts.filter { !$0.isEmpty }
        let fields = nonempty.isEmpty ? parts : nonempty
        guard !fields.isEmpty else { return nil }

        switch fields.count {
        case 1:
            let token = fields[0]
            if token.contains(".") || token.contains(",") {
                return Double(token.replacingOccurrences(of: ",", with: "."))
            }
            return parseCompactDigits(token.filter(\.isNumber))
        case 2:
            guard let minutes = parseWhole(fields[0]), let seconds = parseFraction(fields[1]) else {
                return nil
            }
            return Double(minutes * 60) + seconds
        case 3:
            guard let hours = parseWhole(fields[0]),
                  let minutes = parseWhole(fields[1]),
                  let seconds = parseFraction(fields[2]) else {
                return nil
            }
            return Double(hours * 3600 + minutes * 60) + seconds
        case 4:
            guard let hours = parseWhole(fields[0]),
                  let minutes = parseWhole(fields[1]),
                  let seconds = parseWhole(fields[2]),
                  let fraction = parseMillisecondField(fields[3]) else {
                return nil
            }
            return Double(hours * 3600 + minutes * 60 + seconds) + fraction
        default:
            return nil
        }
    }

    private static func parseCompactWithDecimal(_ text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        guard let dot = normalized.firstIndex(of: ".") else { return nil }
        let left = String(normalized[..<dot]).filter(\.isNumber)
        let right = String(normalized[normalized.index(after: dot)...]).filter(\.isNumber)
        let base: Double
        if left.isEmpty {
            base = 0
        } else {
            guard let value = parseCompactDigits(left) else { return nil }
            base = value
        }
        if right.isEmpty { return base }
        guard let fraction = Double("0." + right) else { return nil }
        return base + fraction
    }

    private static func parseCompactDigits(_ digits: String) -> Double? {
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return nil }

        let hms: String
        let fraction: Double
        if digits.count <= 6 {
            hms = digits
            fraction = 0
        } else {
            let msCount = min(3, digits.count - 6)
            let msDigits = String(digits.suffix(msCount)).padding(toLength: 3, withPad: "0", startingAt: 0)
            guard let ms = Int(msDigits) else { return nil }
            fraction = Double(ms) / 1000
            hms = String(digits.dropLast(msCount))
        }

        let seconds: Int
        let minutes: Int
        let hours: Int
        switch hms.count {
        case 0:
            seconds = 0; minutes = 0; hours = 0
        case 1, 2:
            guard let s = Int(hms) else { return nil }
            seconds = s; minutes = 0; hours = 0
        case 3, 4:
            guard let s = Int(hms.suffix(2)), let m = Int(hms.dropLast(2)) else { return nil }
            seconds = s; minutes = m; hours = 0
        default:
            guard let s = Int(hms.suffix(2)),
                  let m = Int(hms.dropLast(2).suffix(2)),
                  let h = Int(hms.dropLast(4)) else { return nil }
            seconds = s; minutes = m; hours = h
        }
        return Double(hours * 3600 + minutes * 60 + seconds) + fraction
    }

    private static func parseWhole(_ text: String) -> Int? {
        let t = text.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return 0 }
        guard t.allSatisfy(\.isNumber) else { return nil }
        return Int(t)
    }

    private static func parseFraction(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        if t.isEmpty { return 0 }
        return Double(t)
    }

    private static func parseMillisecondField(_ text: String) -> Double? {
        let digits = text.filter(\.isNumber)
        guard !digits.isEmpty else { return 0 }
        let padded = String(digits.prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)
        guard let ms = Int(padded) else { return nil }
        return Double(ms) / 1000
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
