import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var note: Note
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isContentFocused: Bool
    @State private var originalTitle: String
    @State private var originalContent: String
    @State private var showMarkdownPreview = false

    private var isNew: Bool

    init(note: Note, isNew: Bool = false) {
        self.note = note
        self.isNew = isNew
        _originalTitle = State(initialValue: note.title)
        _originalContent = State(initialValue: note.content)
    }

    private var hasMarkdownContent: Bool {
        let c = note.content
        return c.contains("**") || c.contains("```") || c.contains("~~")
            || c.range(of: #"^#{1,3}\s"#, options: [.regularExpression, .anchorsMatchLines]) != nil
            || c.range(of: #"^[-*]\s"#, options: [.regularExpression, .anchorsMatchLines]) != nil
            || c.range(of: #"^>\s"#, options: [.regularExpression, .anchorsMatchLines]) != nil
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

            if showMarkdownPreview {
                MarkdownRendererView(content: note.content)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                TextEditor(text: $note.content)
                    .font(.body)
                    .focused($isContentFocused)
                    .padding(.horizontal, 12)
                    .scrollContentBackground(.hidden)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .navigationTitle(isNew ? "New Note" : "Edit Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        note.title = ""
                        note.content = ""
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    if note.title != originalTitle || note.content != originalContent {
                        note.updatedAt = Date()
                    }
                    do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }
                    originalTitle = note.title
                    originalContent = note.content
                    dismiss()
                }
                .fontWeight(.semibold)
            }

            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Button {
                        note.isPinned.toggle()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }
                    } label: {
                        Label(
                            note.isPinned ? "Unpin" : "Pin",
                            systemImage: note.isPinned ? "pin.slash" : "pin"
                        )
                    }

                    if hasMarkdownContent || showMarkdownPreview {
                        Button {
                            withAnimation(.easeInOut(duration: Theme.animDefault)) {
                                showMarkdownPreview.toggle()
                            }
                        } label: {
                            Label(
                                showMarkdownPreview ? "Edit" : "Preview",
                                systemImage: showMarkdownPreview ? "pencil" : "eye"
                            )
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            ToolbarItemGroup(placement: .keyboard) {
                // Markdown formatting quick buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        markdownButton("**B**", insert: "****", accessibilityName: "Bold")
                        markdownButton("*I*", insert: "**", accessibilityName: "Italic")
                        markdownButton("~~S~~", insert: "~~~~", accessibilityName: "Strikethrough")
                        markdownButton("`C`", insert: "``", accessibilityName: "Code")
                        markdownButton("H1", insert: "# ", accessibilityName: "Heading")
                        markdownButton("- ", insert: "- ", accessibilityName: "Bullet")
                        markdownButton("> ", insert: "> ", accessibilityName: "Quote")
                    }
                }

                Spacer()

                Button {
                    isTitleFocused = false
                    isContentFocused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                }
                .accessibilityLabel("Dismiss keyboard")
            }
        }
        .task(id: isNew) {
            if isNew {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                isTitleFocused = true
            }
        }
        .onDisappear {
            if !isNew,
               note.title != originalTitle || note.content != originalContent {
                note.updatedAt = Date()
                do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }
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

    // MARK: - Markdown Formatting Buttons

    private func markdownButton(_ title: String, insert: String, accessibilityName: String) -> some View {
        Button {
            note.content += insert
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(title)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .accessibilityLabel(accessibilityName)
    }
}
