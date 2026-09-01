import SwiftUI

enum SnapMotion {
    static let fast = Animation.easeOut(duration: 0.14)
    static let cropBar = Animation.easeOut(duration: 0.08)
    static let cropBarDelayNs: UInt64 = 80_000_000
    static let standard = Animation.easeInOut(duration: 0.22)
    static let spring = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let inspector = Animation.spring(response: 0.22, dampingFraction: 0.94)
    static let scroll = Animation.spring(response: 0.26, dampingFraction: 0.9)
}
