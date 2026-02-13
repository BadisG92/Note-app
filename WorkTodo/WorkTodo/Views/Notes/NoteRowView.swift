import SwiftUI

struct NoteRowView: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.amber)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityLabel("Pinned")
                }

                Text(note.title.isEmpty ? "Untitled Note" : note.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                if hasMarkdown {
                    Image(systemName: "text.badge.star")
                        .font(.caption2)
                        .foregroundStyle(Theme.mauve)
                        .accessibilityLabel("Markdown")
                }

                Text(note.updatedFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .animation(.snappy(duration: 0.3), value: note.isPinned)

            if !note.preview.isEmpty {
                Text(note.preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(noteAccessibilityLabel)
    }

    private var hasMarkdown: Bool {
        let c = note.content
        return c.contains("**") || c.contains("# ") || c.contains("```") || c.contains("~~")
    }

    private var noteAccessibilityLabel: String {
        var parts = [note.title.isEmpty ? "Untitled Note" : note.title]
        if note.isPinned { parts.append("pinned") }
        if !note.preview.isEmpty { parts.append(note.preview) }
        parts.append("updated \(note.updatedFormatted)")
        return parts.joined(separator: ", ")
    }
}
