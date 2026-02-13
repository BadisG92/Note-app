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
}
