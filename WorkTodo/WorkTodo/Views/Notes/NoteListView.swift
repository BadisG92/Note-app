import SwiftUI
import SwiftData

struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]

    @State private var searchText = ""
    @State private var newNote: Note?
    @State private var noteToDelete: Note?

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
                } else if filteredNotes.isEmpty {
                    ContentUnavailableView.search(text: searchText)
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
            .confirmationDialog(
                "Delete Note",
                isPresented: Binding(
                    get: { noteToDelete != nil },
                    set: { if !$0 { noteToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let note = noteToDelete {
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        withAnimation { modelContext.delete(note) }
                        try? modelContext.save()
                    }
                    noteToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    noteToDelete = nil
                }
            } message: {
                if let note = noteToDelete {
                    Text("Are you sure you want to delete \"\(note.title.isEmpty ? "Untitled Note" : note.title)\"? This cannot be undone.")
                }
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
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                noteToDelete = note
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                withAnimation { note.isPinned.toggle() }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Label(note.isPinned ? "Unpin" : "Pin",
                                      systemImage: note.isPinned ? "pin.slash" : "pin")
                            }
                            .tint(.orange)
                        }
                    }
                    .onDelete { offsets in
                        requestDeleteNotes(from: pinnedNotes, at: offsets)
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
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            noteToDelete = note
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            withAnimation { note.isPinned.toggle() }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Label(note.isPinned ? "Unpin" : "Pin",
                                  systemImage: note.isPinned ? "pin.slash" : "pin")
                        }
                        .tint(.orange)
                    }
                }
                .onDelete { offsets in
                    requestDeleteNotes(from: unpinnedNotes, at: offsets)
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
        .refreshable {
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
    }

    // MARK: - Actions

    private func createNote() {
        let note = Note()
        modelContext.insert(note)
        newNote = note
    }

    private func cleanupEmptyNewNote() {
        if let note = newNote, !note.isDeleted,
           note.title.isEmpty && note.content.isEmpty {
            modelContext.delete(note)
        }
        newNote = nil
    }

    private func requestDeleteNotes(from source: [Note], at offsets: IndexSet) {
        guard let first = offsets.first else { return }
        noteToDelete = source[first]
    }
}
