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
        let currentFiltered = filteredNotes
        NavigationStack {
            Group {
                if allNotes.isEmpty {
                    emptyState
                        .transition(.opacity)
                } else if currentFiltered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .transition(.opacity)
                } else {
                    noteList
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: Theme.animDefault), value: allNotes.isEmpty)
            .animation(.easeOut(duration: Theme.animDefault), value: currentFiltered.isEmpty)
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
            .onAppear {
                // Clean up phantom empty notes left by interrupted creation (e.g., app kill)
                let emptyNotes = allNotes.filter { $0.title.isEmpty && $0.content.isEmpty }
                for note in emptyNotes {
                    modelContext.delete(note)
                }
                if !emptyNotes.isEmpty {
                    do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }
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
                        do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }
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
                .foregroundStyle(Theme.amber)
        } description: {
            Text("Capture your thoughts and ideas.\nTap the button below to start writing.")
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
                                do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }
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
                                do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }
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
                            do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }
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
                    SectionHeaderView(title: "Pinned", systemImage: "pin.fill", tint: Theme.amber)
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
                            do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }
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
                            do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }
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
                        do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }
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
                    SectionHeaderView(title: "Notes", systemImage: "note.text")
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
            do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }
        }
    }

    private func requestDeleteNotes(from source: [Note], at offsets: IndexSet) {
        guard let first = offsets.first, first < source.count else { return }
        noteToDelete = source[first]
        showDeleteConfirmation = true
    }
}
