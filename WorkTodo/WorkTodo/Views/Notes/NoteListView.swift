import SwiftUI
import SwiftData

struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.updatedAt, order: .reverse) private var allNotes: [Note]

    @State private var searchText = ""
    @State private var newNote: Note?
    @State private var pendingCleanupNote: Note?
    @State private var noteToDelete: Note?
    @State private var showDeleteConfirmation = false

    private var filteredNotes: [Note] {
        if searchText.isEmpty {
            return allNotes
        }
        return allNotes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Partition filtered notes once to avoid recomputing filteredNotes
    /// multiple times per body evaluation.
    private var partitionedNotes: (pinned: [Note], unpinned: [Note]) {
        let filtered = filteredNotes
        let pinned = filtered.filter { $0.isPinned }
        let unpinned = filtered.filter { !$0.isPinned }
        return (pinned, unpinned)
    }

    var body: some View {
        NavigationStack {
            Group {
                if allNotes.isEmpty {
                    emptyState
                        .transition(.opacity)
                } else if filteredNotes.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .transition(.opacity)
                } else {
                    noteList
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.25), value: allNotes.isEmpty)
            .animation(.easeOut(duration: 0.25), value: filteredNotes.isEmpty)
            .navigationTitle("Notes")
            .searchable(text: $searchText, prompt: "Search notes...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: createNote) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel("New note")
                    .accessibilityHint("Creates a new blank note")
                }
            }
            .sheet(item: $newNote) { note in
                NoteEditorView(note: note, isNew: true)
                    .presentationDragIndicator(.visible)
            } onDismiss: {
                cleanupEmptyNewNote()
            }
            .confirmationDialog(
                "Delete Note",
                isPresented: $showDeleteConfirmation,
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
            Text("Tap the + button to write your first note.")
        } actions: {
            Button("New Note") {
                createNote()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var noteList: some View {
        let notes = partitionedNotes
        let pinned = notes.pinned
        let unpinned = notes.unpinned

        return List {
            if !pinned.isEmpty {
                Section {
                    ForEach(pinned) { note in
                        NavigationLink {
                            NoteEditorView(note: note)
                        } label: {
                            NoteRowView(note: note)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                noteToDelete = note
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                withAnimation { note.isPinned.toggle() }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                try? modelContext.save()
                            } label: {
                                Label(note.isPinned ? "Unpin" : "Pin",
                                      systemImage: note.isPinned ? "pin.slash" : "pin")
                            }
                            .tint(Theme.amber)
                        }
                        .contextMenu {
                            Button {
                                withAnimation { note.isPinned.toggle() }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                try? modelContext.save()
                            } label: {
                                Label(note.isPinned ? "Unpin" : "Pin",
                                      systemImage: note.isPinned ? "pin.slash" : "pin")
                            }
                            Divider()
                            Button(role: .destructive) {
                                noteToDelete = note
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .accessibilityAction(named: note.isPinned ? "Unpin" : "Pin") {
                            withAnimation { note.isPinned.toggle() }
                            try? modelContext.save()
                        }
                        .accessibilityAction(named: "Delete") {
                            noteToDelete = note
                            showDeleteConfirmation = true
                        }
                    }
                    .onDelete { offsets in
                        requestDeleteNotes(from: pinned, at: offsets)
                    }
                } header: {
                    Label("Pinned", systemImage: "pin.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            Section {
                ForEach(unpinned) { note in
                    NavigationLink {
                        NoteEditorView(note: note)
                    } label: {
                        NoteRowView(note: note)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            noteToDelete = note
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            withAnimation { note.isPinned.toggle() }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            try? modelContext.save()
                        } label: {
                            Label(note.isPinned ? "Unpin" : "Pin",
                                  systemImage: note.isPinned ? "pin.slash" : "pin")
                        }
                        .tint(Theme.amber)
                    }
                    .contextMenu {
                        Button {
                            withAnimation { note.isPinned.toggle() }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            try? modelContext.save()
                        } label: {
                            Label(note.isPinned ? "Unpin" : "Pin",
                                  systemImage: note.isPinned ? "pin.slash" : "pin")
                        }
                        Divider()
                        Button(role: .destructive) {
                            noteToDelete = note
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .accessibilityAction(named: note.isPinned ? "Unpin" : "Pin") {
                        withAnimation { note.isPinned.toggle() }
                        try? modelContext.save()
                    }
                    .accessibilityAction(named: "Delete") {
                        noteToDelete = note
                        showDeleteConfirmation = true
                    }
                }
                .onDelete { offsets in
                    requestDeleteNotes(from: unpinned, at: offsets)
                }
            } header: {
                if !pinned.isEmpty {
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
        guard newNote == nil else { return }
        let note = Note()
        modelContext.insert(note)
        pendingCleanupNote = note
        newNote = note
    }

    private func cleanupEmptyNewNote() {
        guard let note = pendingCleanupNote else { return }
        pendingCleanupNote = nil
        if note.modelContext != nil,
           note.title.isEmpty && note.content.isEmpty {
            modelContext.delete(note)
            try? modelContext.save()
        }
    }

    private func requestDeleteNotes(from source: [Note], at offsets: IndexSet) {
        guard let first = offsets.first else { return }
        noteToDelete = source[first]
        showDeleteConfirmation = true
    }
}
