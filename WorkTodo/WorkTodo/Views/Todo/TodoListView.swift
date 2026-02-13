import SwiftUI
import SwiftData

struct TodoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.dueDate) private var allTodos: [TodoItem]

    @State private var activeSheet: TodoSheetState?
    @State private var searchText = ""
    @State private var filterMode: FilterMode = .active
    @State private var sortMode: SortMode = .dueDate

    enum TodoSheetState: Identifiable {
        case add
        case edit(TodoItem)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let todo): return todo.id.uuidString
            }
        }
    }

    enum FilterMode: String, CaseIterable {
        case active = "Active"
        case completed = "Completed"
        case all = "All"
    }

    enum SortMode: String, CaseIterable {
        case dueDate = "Due Date"
        case priority = "Priority"
        case created = "Created"
    }

    private var filteredTodos: [TodoItem] {
        var result = allTodos

        switch filterMode {
        case .active:
            result = result.filter { !$0.isCompleted }
        case .completed:
            result = result.filter { $0.isCompleted }
        case .all:
            break
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.details.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortMode {
        case .dueDate:
            result.sort { $0.dueDate < $1.dueDate }
        case .priority:
            result.sort { $0.priority > $1.priority }
        case .created:
            result.sort { $0.createdAt > $1.createdAt }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if allTodos.isEmpty {
                    emptyState
                } else {
                    todoList
                }
            }
            .navigationTitle("Tasks")
            .searchable(text: $searchText, prompt: "Search tasks...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { activeSheet = .add }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Section("Filter") {
                            Picker("Filter", selection: $filterMode) {
                                ForEach(FilterMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                        }
                        Section("Sort by") {
                            Picker("Sort", selection: $sortMode) {
                                ForEach(SortMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(item: $activeSheet) { state in
                switch state {
                case .add:
                    TodoDetailView()
                case .edit(let todo):
                    TodoDetailView(todo: todo)
                        .id(todo.id)
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Tasks Yet", systemImage: "checklist")
        } description: {
            Text("Tap the + button to create your first task.")
        } actions: {
            Button("Add Task") {
                activeSheet = .add
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var todoList: some View {
        let filtered = filteredTodos
        let overdue = filtered.filter { $0.isOverdue }
        let upcoming = filtered.filter { !$0.isOverdue && !$0.isCompleted }
        let completed = filtered.filter { $0.isCompleted }

        return List {
            if !overdue.isEmpty {
                Section {
                    ForEach(overdue) { todo in
                        todoRow(todo)
                    }
                    .onDelete { offsets in
                        deleteTodos(from: overdue, at: offsets)
                    }
                } header: {
                    Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            if !upcoming.isEmpty {
                Section {
                    ForEach(upcoming) { todo in
                        todoRow(todo)
                    }
                    .onDelete { offsets in
                        deleteTodos(from: upcoming, at: offsets)
                    }
                } header: {
                    Label("Upcoming", systemImage: "clock")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            if !completed.isEmpty && filterMode != .active {
                Section {
                    ForEach(completed) { todo in
                        todoRow(todo)
                    }
                    .onDelete { offsets in
                        deleteTodos(from: completed, at: offsets)
                    }
                } header: {
                    Label("Completed", systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func todoRow(_ todo: TodoItem) -> some View {
        TodoRowView(todo: todo) {
            withAnimation {
                todo.toggleCompleted()
            }
            handleNotificationsAfterToggle(todo)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            activeSheet = .edit(todo)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteTodo(todo)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation {
                    todo.toggleCompleted()
                }
                handleNotificationsAfterToggle(todo)
            } label: {
                Label(
                    todo.isCompleted ? "Undo" : "Done",
                    systemImage: todo.isCompleted ? "arrow.uturn.backward" : "checkmark"
                )
            }
            .tint(todo.isCompleted ? .orange : .green)
        }
    }

    // MARK: - Actions

    private func handleNotificationsAfterToggle(_ todo: TodoItem) {
        if todo.isCompleted {
            Task { await NotificationManager.shared.removeNotifications(for: todo) }
        } else {
            Task { await NotificationManager.shared.scheduleNotification(for: todo) }
        }
    }

    private func deleteTodo(_ todo: TodoItem) {
        let todoId = todo.id
        Task { await NotificationManager.shared.removeNotifications(forId: todoId) }
        withAnimation { modelContext.delete(todo) }
    }

    private func deleteTodos(from source: [TodoItem], at offsets: IndexSet) {
        for index in offsets {
            deleteTodo(source[index])
        }
    }
}
