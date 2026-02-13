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

    private var editorContent: some View {
        VStack(spacing: 0) {
            TextField("Title", text: $note.title)
                .font(.title2)
                .fontWeight(.bold)
                .focused($isTitleFocused)
                .submitLabel(.next)
                .onSubmit {
                    isContentFocused = true
                }
                .padding(.horizontal)
                .padding(.top, 12)

            Divider()
                .padding(.horizontal)
                .padding(.vertical, 8)

            TextEditor(text: $note.content)
                .font(.body)
                .focused($isContentFocused)
                .padding(.horizontal, 12)
                .scrollContentBackground(.hidden)
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
                    note.updatedAt = Date()
                    if note.title.isEmpty && note.content.isEmpty {
                        modelContext.delete(note)
                    }
                    try? modelContext.save()
                    dismiss()
                }
                .fontWeight(.semibold)
            }

            ToolbarItem(placement: .secondaryAction) {
                Button {
                    note.isPinned.toggle()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label(
                        note.isPinned ? "Unpin" : "Pin",
                        systemImage: note.isPinned ? "pin.slash" : "pin"
                    )
                }
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    isTitleFocused = false
                    isContentFocused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                }
            }
        }
        .onAppear {
            if isNew {
                isTitleFocused = true
            }
        }
    }

    var body: some View {
        if isNew {
            NavigationStack {
                editorContent
            }
        } else {
            editorContent
        }
    }
}
