import SwiftUI
import SwiftData

struct TodoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.dueDate) private var allTodos: [TodoItem]
    @Query(sort: \Project.name) private var projects: [Project]

    @State private var activeSheet: TodoSheetState?
    @State private var searchText = ""
    @State private var filterMode: FilterMode = .active
    @State private var sortMode: SortMode = .dueDate
    @State private var selectedProjectFilter: Project?
    @State private var todoToDelete: TodoItem?
    @State private var showDeleteConfirmation = false
    @State private var quickAddText = ""
    @FocusState private var isQuickAddFocused: Bool

    enum TodoSheetState: Identifiable {
        case add(UUID = UUID())
        case edit(TodoItem, UUID = UUID())

        var id: String {
            switch self {
            case .add(let token): return "add-\(token)"
            case .edit(_, let token): return "edit-\(token)"
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

    private var filteredTodos: [TodoItem] {
        var result = allTodos

        // Project filter
        if let projectFilter = selectedProjectFilter {
            result = result.filter { $0.project?.id == projectFilter.id }
        }

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
        let currentFiltered = filteredTodos
        NavigationStack {
            Group {
                if allTodos.isEmpty {
                    emptyState
                        .transition(.opacity)
                } else if currentFiltered.isEmpty {
                    filteredEmptyState
                        .transition(.opacity)
                } else {
                    todoListContent(currentFiltered)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.25), value: allTodos.isEmpty)
            .animation(.easeOut(duration: 0.25), value: currentFiltered.isEmpty)
            .animation(.default, value: filterMode)
            .animation(.default, value: sortMode)
            .animation(.default, value: selectedProjectFilter?.id)
            .navigationTitle("Tasks")
            .searchable(text: $searchText, prompt: "Search tasks...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { guard activeSheet == nil else { return }; activeSheet = .add }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel("New task")
                    .accessibilityHint("Opens form to create a new task")
                }
                ToolbarItem(placement: .topBarLeading) {
                    filterSortMenu
                        .accessibilityLabel(hasNonDefaultFilters
                            ? "Filter and sort, active: \(filterChipLabel)"
                            : "Filter and sort")
                }
            }
            .sheet(item: $activeSheet) { state in
                switch state {
                case .add:
                    TodoDetailView()
                        .presentationDragIndicator(.visible)
                case .edit(let todo, _):
                    TodoDetailView(todo: todo)
                        .presentationDragIndicator(.visible)
                }
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
                    Text("Are you sure you want to delete \"\(todo.title)\"? This cannot be undone.")
                }
            }
        }
    }

    // MARK: - Filter / Sort Menu

    private var hasNonDefaultFilters: Bool {
        filterMode != .active || sortMode != .dueDate || selectedProjectFilter != nil
    }

    private var filterSortMenu: some View {
        Menu {
            if !projects.isEmpty {
                Section("Project") {
                    Button {
                        selectedProjectFilter = nil
                    } label: {
                        HStack {
                            Text("All Projects")
                            if selectedProjectFilter == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    ForEach(projects) { project in
                        Button {
                            selectedProjectFilter = project
                        } label: {
                            HStack {
                                Label(project.name, systemImage: project.iconName)
                                if selectedProjectFilter?.id == project.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
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
                Image(systemName: hasNonDefaultFilters
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
                    .font(.body)

                if hasNonDefaultFilters {
                    Text(filterChipLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.chipBg, in: Capsule())
                }
            }
        }
    }

    private var filterChipLabel: String {
        var parts: [String] = []
        if let project = selectedProjectFilter {
            parts.append(project.name)
        }
        if filterMode != .active {
            parts.append(filterMode.rawValue)
        }
        if sortMode != .dueDate {
            parts.append(sortMode.rawValue)
        }
        return parts.joined(separator: " / ")
    }

    // MARK: - Subviews

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Tasks Yet", systemImage: "checklist")
        } description: {
            Text("Tap the + button to create your first task.")
        } actions: {
            Button("New Task") {
                activeSheet = .add
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var filteredEmptyState: some View {
        Group {
            if !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if filterMode == .active && allTodos.contains(where: { $0.isCompleted }) {
                // User completed everything
                VStack(spacing: 16) {
                    Image(systemName: "party.popper")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.celebration)

                    Text("All Done!")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(filteredEmptyDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
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
        let projectContext = selectedProjectFilter != nil
            ? " in \(selectedProjectFilter!.name)" : ""
        switch filterMode {
        case .completed:
            return "No completed tasks\(projectContext) yet."
        case .active:
            return "You have no active tasks\(projectContext). Nice work!"
        case .all:
            return "No tasks match the current filters."
        }
    }

    // MARK: - Quick Add

    private var quickAddRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle")
                .font(.title3)
                .foregroundStyle(.accentColor)

            TextField("Quick add task...", text: $quickAddText)
                .font(.body)
                .focused($isQuickAddFocused)
                .submitLabel(.done)
                .onSubmit {
                    quickAddTask()
                }
        }
        .padding(.vertical, 4)
    }

    private func quickAddTask() {
        let trimmed = quickAddText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let item = TodoItem(title: trimmed)
        item.project = selectedProjectFilter
        modelContext.insert(item)

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        try? modelContext.save()

        withAnimation(.snappy(duration: 0.3)) {
            quickAddText = ""
        }
    }

    // MARK: - Task List Content

    private func todoListContent(_ filtered: [TodoItem]) -> some View {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        let overdue = filtered.filter { $0.isOverdue }
        let today = filtered.filter {
            !$0.isCompleted && !$0.isOverdue
            && calendar.isDateInToday($0.dueDate)
        }
        let tomorrow = filtered.filter {
            !$0.isCompleted && !$0.isOverdue
            && calendar.isDateInTomorrow($0.dueDate)
        }
        let thisWeek = filtered.filter {
            guard !$0.isCompleted && !$0.isOverdue else { return false }
            let start = calendar.date(byAdding: .day, value: 2, to: startOfToday)!
            let end = calendar.date(byAdding: .day, value: 7, to: startOfToday)!
            return $0.dueDate >= start && $0.dueDate < end
        }
        let later = filtered.filter {
            guard !$0.isCompleted && !$0.isOverdue else { return false }
            let end = calendar.date(byAdding: .day, value: 7, to: startOfToday)!
            return $0.dueDate >= end
        }
        let completed = filtered.filter { $0.isCompleted }

        return List {
            // Quick add row
            if filterMode == .active {
                quickAddRow
            }

            if !overdue.isEmpty {
                Section {
                    ForEach(overdue) { todo in
                        todoRow(todo)
                            .listRowBackground(Theme.dangerBg)
                    }
                    .onDelete { offsets in
                        requestDeleteTodos(from: overdue, at: offsets)
                    }
                } header: {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.danger)
                        Text("Overdue")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                }
            }

            if !today.isEmpty {
                Section {
                    ForEach(today) { todo in
                        todoRow(todo)
                    }
                    .onDelete { offsets in
                        requestDeleteTodos(from: today, at: offsets)
                    }
                } header: {
                    Label("Today", systemImage: "sun.max")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            if !tomorrow.isEmpty {
                Section {
                    ForEach(tomorrow) { todo in
                        todoRow(todo)
                    }
                    .onDelete { offsets in
                        requestDeleteTodos(from: tomorrow, at: offsets)
                    }
                } header: {
                    Label("Tomorrow", systemImage: "sunrise")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            if !thisWeek.isEmpty {
                Section {
                    ForEach(thisWeek) { todo in
                        todoRow(todo)
                    }
                    .onDelete { offsets in
                        requestDeleteTodos(from: thisWeek, at: offsets)
                    }
                } header: {
                    Label("This Week", systemImage: "calendar")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            if !later.isEmpty {
                Section {
                    ForEach(later) { todo in
                        todoRow(todo)
                    }
                    .onDelete { offsets in
                        requestDeleteTodos(from: later, at: offsets)
                    }
                } header: {
                    Label("Later", systemImage: "calendar.badge.clock")
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
    }

    private func todoRow(_ todo: TodoItem) -> some View {
        TodoRowView(todo: todo, onToggle: {
            withAnimation(.snappy(duration: 0.35)) {
                todo.toggleCompleted()
            }
            UIImpactFeedbackGenerator(style: todo.isCompleted ? .heavy : .light)
                .impactOccurred()
            handleNotificationsAfterToggle(todo)
            try? modelContext.save()
        }, onEdit: {
            activeSheet = .edit(todo)
        })
        .contextMenu {
            Button {
                activeSheet = .edit(todo)
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                withAnimation(.snappy(duration: 0.35)) {
                    todo.toggleCompleted()
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                handleNotificationsAfterToggle(todo)
                try? modelContext.save()
            } label: {
                Label(
                    todo.isCompleted ? "Mark Active" : "Mark Complete",
                    systemImage: todo.isCompleted ? "arrow.uturn.backward" : "checkmark.circle"
                )
            }

            Divider()

            Button(role: .destructive) {
                todoToDelete = todo
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
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
                withAnimation(.snappy(duration: 0.35)) {
                    todo.toggleCompleted()
                }
                UIImpactFeedbackGenerator(style: todo.isCompleted ? .heavy : .light)
                    .impactOccurred()
                handleNotificationsAfterToggle(todo)
                try? modelContext.save()
            } label: {
                Label(
                    todo.isCompleted ? "Undo" : "Done",
                    systemImage: todo.isCompleted ? "arrow.uturn.backward" : "checkmark"
                )
            }
            .tint(todo.isCompleted ? Theme.amber : Theme.success)
        }
        .accessibilityAction(named: "Delete") {
            todoToDelete = todo
            showDeleteConfirmation = true
        }
        .accessibilityAction(named: todo.isCompleted ? "Mark incomplete" : "Mark complete") {
            todo.toggleCompleted()
            handleNotificationsAfterToggle(todo)
            try? modelContext.save()
        }
    }

    // MARK: - Actions

    private func handleNotificationsAfterToggle(_ todo: TodoItem) {
        if todo.isCompleted {
            NotificationManager.shared.removeNotifications(for: todo)
        } else {
            Task {
                await NotificationManager.shared.scheduleNotification(for: todo)
            }
        }
    }

    private func performDelete(_ todo: TodoItem) {
        let todoId = todo.id
        NotificationManager.shared.removeNotifications(forId: todoId)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        withAnimation(.snappy(duration: 0.25)) { modelContext.delete(todo) }
        try? modelContext.save()
    }

    private func requestDeleteTodos(from source: [TodoItem], at offsets: IndexSet) {
        guard let first = offsets.first else { return }
        todoToDelete = source[first]
        showDeleteConfirmation = true
    }
}
