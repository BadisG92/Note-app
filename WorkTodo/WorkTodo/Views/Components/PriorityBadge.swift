import SwiftUI

struct PriorityBadge: View {
    let priority: Priority

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
        .background(priority.color.opacity(0.15))
        .foregroundStyle(priority.color)
        .clipShape(Capsule())
    }
}
