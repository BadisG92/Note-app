import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var note: Note
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isContentFocused: Bool

    private var isNew: Bool

    init(note: Note, isNew: Bool = false) {
        self.note = note
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Title field
                TextField("Title", text: $note.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .focused($isTitleFocused)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .onChange(of: note.title) {
                        note.updatedAt = Date()
                    }

                Divider()
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                // Content editor
                TextEditor(text: $note.content)
                    .font(.body)
                    .focused($isContentFocused)
                    .padding(.horizontal, 12)
                    .scrollContentBackground(.hidden)
                    .onChange(of: note.content) {
                        note.updatedAt = Date()
                    }
            }
            .navigationTitle(isNew ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isNew {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            modelContext.delete(note)
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if note.title.isEmpty && note.content.isEmpty {
                            modelContext.delete(note)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }

                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        note.isPinned.toggle()
                    } label: {
                        Label(
                            note.isPinned ? "Unpin" : "Pin",
                            systemImage: note.isPinned ? "pin.slash" : "pin"
                        )
                    }
                }
            }
            .onAppear {
                if isNew {
                    isTitleFocused = true
                }
            }
        }
    }
}
