import SwiftUI

struct NoteRowView: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Text(note.title.isEmpty ? "Untitled Note" : note.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(note.updatedFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !note.preview.isEmpty {
                Text(note.preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
