import SwiftUI

struct PriorityBadge: View {
    let priority: Priority
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: priority.systemImage)
                .font(.caption2)
            Text(priority.label)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(badgeBackground)
        .foregroundStyle(badgeForeground)
        .clipShape(Capsule())
        .accessibilityLabel("Priority: \(priority.label)")
    }

    /// In dark mode, use a slightly higher-opacity background so the text
    /// maintains a WCAG AA contrast ratio against the dark surface.
    private var badgeBackground: Color {
        priority.color.opacity(colorScheme == .dark ? 0.25 : 0.15)
    }

    /// In dark mode, lighten low-priority gray so it doesn't disappear.
    private var badgeForeground: Color {
        if priority == .low && colorScheme == .dark {
            return Color(white: 0.75)
        }
        return priority.color
    }
}
