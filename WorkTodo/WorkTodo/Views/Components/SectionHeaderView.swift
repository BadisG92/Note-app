import SwiftUI

struct SectionHeaderView: View {
    let title: String
    let systemImage: String
    var tint: Color?
    var count: Int?

    var body: some View {
        HStack(spacing: Theme.spacingXS) {
            Image(systemName: systemImage)
                .foregroundStyle(tint ?? .secondary)
            Text(title)

            if let count, count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(tint ?? .secondary, in: Capsule())
            }
        }
        .font(.subheadline)
        .fontWeight(.semibold)
    }
}
