import SwiftUI
import SwiftData

struct TodoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.dueDate) private var allTodos: [TodoItem]

    @State private var showingAddSheet = false
    @State private var selectedTodo: TodoItem?
    @State private var searchText = ""
    @State private var filterMode: FilterMode = .active
    @State private var sortMode: SortMode = .dueDate

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

        // Filter
        switch filterMode {
        case .active:
            result = result.filter { !$0.isCompleted }
        case .completed:
            result = result.filter { $0.isCompleted }
        case .all:
            break
        }

        // Search
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.details.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort
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

    private var overdueTodos: [TodoItem] {
        filteredTodos.filter { $0.isOverdue }
    }

    private var upcomingTodos: [TodoItem] {
        filteredTodos.filter { !$0.isOverdue && !$0.isCompleted }
    }

    private var completedTodos: [TodoItem] {
        filteredTodos.filter { $0.isCompleted }
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
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        // Filter
                        Section("Filter") {
                            Picker("Filter", selection: $filterMode) {
                                ForEach(FilterMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                        }
                        // Sort
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
            .sheet(isPresented: $showingAddSheet) {
                TodoDetailView()
            }
            .sheet(item: $selectedTodo) { todo in
                TodoDetailView(todo: todo)
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
                showingAddSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var todoList: some View {
        List {
            if !overdueTodos.isEmpty {
                Section {
                    ForEach(overdueTodos) { todo in
                        todoRow(todo)
                    }
                    .onDelete { offsets in
                        deleteTodos(from: overdueTodos, at: offsets)
                    }
                } header: {
                    Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            if !upcomingTodos.isEmpty {
                Section {
                    ForEach(upcomingTodos) { todo in
                        todoRow(todo)
                    }
                    .onDelete { offsets in
                        deleteTodos(from: upcomingTodos, at: offsets)
                    }
                } header: {
                    Label("Upcoming", systemImage: "clock")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            if !completedTodos.isEmpty && filterMode != .active {
                Section {
                    ForEach(completedTodos) { todo in
                        todoRow(todo)
                    }
                    .onDelete { offsets in
                        deleteTodos(from: completedTodos, at: offsets)
                    }
                } header: {
                    Label("Completed", systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: filteredTodos.count)
    }

    private func todoRow(_ todo: TodoItem) -> some View {
        TodoRowView(todo: todo) {
            withAnimation {
                todo.toggleCompleted()
                if todo.isCompleted {
                    Task {
                        await NotificationManager.shared.removeNotifications(for: todo)
                    }
                } else {
                    Task {
                        await NotificationManager.shared.scheduleNotification(for: todo)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTodo = todo
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

    private func deleteTodo(_ todo: TodoItem) {
        Task {
            await NotificationManager.shared.removeNotifications(for: todo)
        }
        modelContext.delete(todo)
    }

    private func deleteTodos(from source: [TodoItem], at offsets: IndexSet) {
        for index in offsets {
            deleteTodo(source[index])
        }
    }
}
