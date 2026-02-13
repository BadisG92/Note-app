import SwiftUI
import SwiftData

struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]

    @State private var searchText = ""
    @State private var newNote: Note?

    private var filteredNotes: [Note] {
        if searchText.isEmpty {
            return allNotes
        }
        return allNotes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var pinnedNotes: [Note] {
        filteredNotes.filter { $0.isPinned }
    }

    private var unpinnedNotes: [Note] {
        filteredNotes.filter { !$0.isPinned }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allNotes.isEmpty {
                    emptyState
                } else {
                    noteList
                }
            }
            .navigationTitle("Notes")
            .searchable(text: $searchText, prompt: "Search notes...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: createNote) {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                    }
                }
            }
            .sheet(item: $newNote) { note in
                NoteEditorView(note: note, isNew: true)
            } onDismiss: {
                cleanupEmptyNewNote()
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Notes", systemImage: "note.text")
        } description: {
            Text("Tap the pencil button to write your first note.")
        } actions: {
            Button("New Note") {
                createNote()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var noteList: some View {
        List {
            if !pinnedNotes.isEmpty {
                Section {
                    ForEach(pinnedNotes) { note in
                        NavigationLink {
                            NoteEditorView(note: note)
                        } label: {
                            NoteRowView(note: note)
                        }
                    }
                    .onDelete { offsets in
                        deleteNotes(from: pinnedNotes, at: offsets)
                    }
                } header: {
                    Label("Pinned", systemImage: "pin.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            Section {
                ForEach(unpinnedNotes) { note in
                    NavigationLink {
                        NoteEditorView(note: note)
                    } label: {
                        NoteRowView(note: note)
                    }
                }
                .onDelete { offsets in
                    deleteNotes(from: unpinnedNotes, at: offsets)
                }
            } header: {
                if !pinnedNotes.isEmpty {
                    Text("Notes")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

    private func createNote() {
        let note = Note()
        modelContext.insert(note)
        newNote = note
    }

    private func cleanupEmptyNewNote() {
        if let note = newNote, note.title.isEmpty && note.content.isEmpty {
            modelContext.delete(note)
        }
        newNote = nil
    }

    private func deleteNotes(from source: [Note], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(source[index])
        }
    }
}
