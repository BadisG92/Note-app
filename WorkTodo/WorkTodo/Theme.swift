import SwiftUI

/// Warm beige / terracotta palette — inspired by Claude's aesthetic.
/// Replaces generic iOS system blues with an organic, cohesive feel.
enum Theme {

    // MARK: - Semantic Colors

    /// Muted sage — task completed, swipe "Done"
    static let success = Color(hex: "7D9B6B")

    /// Warm rust — overdue, high priority
    static let danger = Color(hex: "BF5B3F")

    /// Warm amber — reminders, pins, medium-high priority
    static let amber = Color(hex: "C2923A")

    /// Soft stone — low priority, neutral
    static let stone = Color(hex: "9B8F85")

    /// Muted mauve — medium priority
    static let mauve = Color(hex: "8B7BA0")

    // MARK: - Background Tints

    /// Overdue row background
    static let dangerBg = Color(hex: "BF5B3F").opacity(0.06)

    /// Active filter chip background
    static let chipBg = Color(hex: "C4704B").opacity(0.12)

    /// Celebration icon
    static let celebration = Color(hex: "C8923C")

    /// Calendar selected day tint
    static let calendarDot = Color(hex: "C4704B").opacity(0.15)

    // MARK: - Spacing Scale (8-point grid)

    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 24
    static let spacingXXL: CGFloat = 32

    // MARK: - Corner Radius

    static let radiusXS: CGFloat = 4
    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 10
    static let radiusLG: CGFloat = 12

    // MARK: - Animation Durations

    static let animFast: Double = 0.2
    static let animDefault: Double = 0.25
    static let animSmooth: Double = 0.35

    // MARK: - Component Sizes

    static let minTouchTarget: CGFloat = 44
    static let iconContainerSize: CGFloat = 36
    static let progressCircleSize: CGFloat = 36
}
