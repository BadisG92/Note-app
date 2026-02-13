import SwiftUI
import SwiftData

struct TodoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.dueDate) private var allTodos: [TodoItem]

    @State private var activeSheet: TodoSheetState?
    @State private var searchText = ""
    @State private var filterMode: FilterMode = .active
    @State private var sortMode: SortMode = .dueDate
    @State private var todoToDelete: TodoItem?

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

    // MARK: - Computed Properties

    var activeTodoCount: Int {
        allTodos.filter { !$0.isCompleted }.count
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
                } else if filteredTodos.isEmpty {
                    filteredEmptyState
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
                ToolbarItem(placement: .topBarLeading) {
                    filterSortMenu
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
            .confirmationDialog(
                "Delete Task",
                isPresented: Binding(
                    get: { todoToDelete != nil },
                    set: { if !$0 { todoToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let todo = todoToDelete {
                        performDelete(todo)
                    }
                }
                Button("Cancel", role: .cancel) {
                    todoToDelete = nil
                }
            } message: {
                if let todo = todoToDelete {
                    Text("Are you sure you want to delete \"\(todo.title)\"? This cannot be undone.")
                }
            }
        }
    }

    // MARK: - Filter / Sort Menu with active-state indicators

    private var filterSortMenu: some View {
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
            HStack(spacing: 4) {
                Image(systemName: filterMode == .active && sortMode == .dueDate
                      ? "line.3.horizontal.decrease.circle"
                      : "line.3.horizontal.decrease.circle.fill")
                    .font(.body)

                if filterMode != .active || sortMode != .dueDate {
                    Text(filterChipLabel)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var filterChipLabel: String {
        if filterMode != .active && sortMode != .dueDate {
            return "\(filterMode.rawValue) / \(sortMode.rawValue)"
        } else if filterMode != .active {
            return filterMode.rawValue
        } else {
            return sortMode.rawValue
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

    private var filteredEmptyState: some View {
        Group {
            if !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ContentUnavailableView {
                    Label(filteredEmptyTitle, systemImage: filteredEmptyIcon)
                } description: {
                    Text(filteredEmptyDescription)
                }
            }
        }
    }

    private var filteredEmptyTitle: String {
        switch filterMode {
        case .completed: return "No Completed Tasks"
        case .active: return "All Done!"
        case .all: return "No Tasks"
        }
    }

    private var filteredEmptyIcon: String {
        switch filterMode {
        case .completed: return "checkmark.circle"
        case .active: return "party.popper"
        case .all: return "checklist"
        }
    }

    private var filteredEmptyDescription: String {
        switch filterMode {
        case .completed:
            return "Tasks you complete will appear here."
        case .active:
            return "You have no active tasks. Nice work!"
        case .all:
            return "No tasks match the current criteria."
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
                        requestDeleteTodos(from: overdue, at: offsets)
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
                        requestDeleteTodos(from: upcoming, at: offsets)
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
                        requestDeleteTodos(from: completed, at: offsets)
                    }
                } header: {
                    Label("Completed", systemImage: "checkmark.circle")
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

    private func todoRow(_ todo: TodoItem) -> some View {
        TodoRowView(todo: todo) {
            withAnimation {
                todo.toggleCompleted()
            }
            UIImpactFeedbackGenerator(style: todo.isCompleted ? .heavy : .light)
                .impactOccurred()
            handleNotificationsAfterToggle(todo)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            activeSheet = .edit(todo)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                todoToDelete = todo
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                withAnimation {
                    todo.toggleCompleted()
                }
                UIImpactFeedbackGenerator(style: todo.isCompleted ? .heavy : .light)
                    .impactOccurred()
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
            NotificationManager.shared.removeNotifications(for: todo)
        } else {
            NotificationManager.shared.scheduleNotification(for: todo)
        }
    }

    private func performDelete(_ todo: TodoItem) {
        let todoId = todo.id
        NotificationManager.shared.removeNotifications(forId: todoId)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        withAnimation { modelContext.delete(todo) }
        try? modelContext.save()
    }

    private func requestDeleteTodos(from source: [TodoItem], at offsets: IndexSet) {
        guard let first = offsets.first else { return }
        todoToDelete = source[first]
    }
}
