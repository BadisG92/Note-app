import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var project: Project
    @Query(sort: \TodoItem.dueDate) private var allTodos: [TodoItem]

    @State private var activeSheet: SheetState?
    @State private var todoToDelete: TodoItem?
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false

    enum SheetState: Identifiable {
        case add(UUID = UUID())
        case edit(TodoItem, UUID = UUID())

        var id: String {
            switch self {
            case .add(let token): return "add-\(token)"
            case .edit(_, let token): return "edit-\(token)"
            }
        }
    }

    private var topLevelTodos: [TodoItem] {
        project.todos.filter { !$0.isSubtask }
    }

    private var activeTodos: [TodoItem] {
        topLevelTodos
            .filter { !$0.isCompleted }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var completedTodos: [TodoItem] {
        topLevelTodos
            .filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
    }

    var body: some View {
        Group {
            if topLevelTodos.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
        .navigationTitle(project.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil.circle")
                            .font(.body)
                    }
                    .accessibilityLabel("Edit project")

                    Button {
                        guard activeSheet == nil else { return }
                        activeSheet = .add
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel("Add task to project")
                }
            }
        }
        .sheet(item: $activeSheet) { state in
            switch state {
            case .add:
                TodoDetailView(project: project)
                    .presentationDragIndicator(.visible)
            case .edit(let todo, _):
                TodoDetailView(todo: todo)
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            ProjectFormView(project: project)
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Delete Task",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let todo = todoToDelete {
                    performDelete(todo)
                }
                todoToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                todoToDelete = nil
            }
        } message: {
            if let todo = todoToDelete {
                Text("Are you sure you want to delete \"\(todo.title)\"?")
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Tasks", systemImage: project.iconName)
                .foregroundStyle(project.color)
        } description: {
            Text("Add your first task to \"\(project.name)\".")
        } actions: {
            Button("New Task") {
                activeSheet = .add
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var taskList: some View {
        List {
            // Progress header
            if project.totalTodoCount > 0 {
                Section {
                    HStack(spacing: 16) {
                        CircularProgressView(
                            progress: project.completionProgress,
                            color: project.color
                        )
                        .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(project.completedTodoCount) of \(project.totalTodoCount) completed")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(project.activeTodoCount) remaining")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Active tasks
            if !activeTodos.isEmpty {
                Section {
                    ForEach(activeTodos) { todo in
                        todoRow(todo)
                    }
                } header: {
                    SectionHeaderView(title: "Active", systemImage: "circle", count: activeTodos.count)
                }
            }

            // Completed tasks
            if !completedTodos.isEmpty {
                Section {
                    ForEach(completedTodos) { todo in
                        todoRow(todo)
                    }
                } header: {
                    SectionHeaderView(title: "Completed", systemImage: "checkmark.circle", tint: Theme.success)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func todoRow(_ todo: TodoItem) -> some View {
        TodoRowView(todo: todo, onToggle: {
            toggleTodo(todo)
        }, onEdit: {
            activeSheet = .edit(todo)
        })
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                todoToDelete = todo
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                toggleTodo(todo)
            } label: {
                Label(
                    todo.isCompleted ? "Undo" : "Done",
                    systemImage: todo.isCompleted ? "arrow.uturn.backward" : "checkmark"
                )
            }
            .tint(todo.isCompleted ? Theme.amber : Theme.success)
        }
    }

    private func toggleTodo(_ todo: TodoItem) {
        withAnimation(.snappy(duration: Theme.animSmooth)) {
            todo.toggleCompleted()
        }
        UIImpactFeedbackGenerator(style: todo.isCompleted ? .heavy : .light)
            .impactOccurred()
        if todo.isCompleted {
            NotificationManager.shared.removeNotifications(for: todo)
            // Create next occurrence for recurring tasks
            if let nextOccurrence = todo.createNextOccurrence() {
                modelContext.insert(nextOccurrence)
                Task {
                    await NotificationManager.shared.scheduleNotification(for: nextOccurrence)
                }
            }
        } else {
            Task {
                await NotificationManager.shared.scheduleNotification(for: todo)
            }
            // Remove the auto-created next occurrence when un-completing a recurring task
            if todo.recurrenceRule != .none,
               let nextDate = todo.recurrenceRule.nextDate(from: todo.dueDate) {
                if let duplicate = allTodos.first(where: {
                    $0.id != todo.id
                    && $0.title == todo.title
                    && $0.dueDate == nextDate
                    && !$0.isCompleted
                }) {
                    NotificationManager.shared.removeNotifications(for: duplicate)
                    modelContext.delete(duplicate)
                }
            }
        }
        do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }
    }

    // MARK: - Actions

    private func performDelete(_ todo: TodoItem) {
        let todoId = todo.id
        NotificationManager.shared.removeNotifications(forId: todoId)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        withAnimation(.snappy(duration: Theme.animDefault)) { modelContext.delete(todo) }
        do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }
    }
}
