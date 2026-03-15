import SwiftUI
import SwiftData

struct TodoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.dueDate) private var allTodos: [TodoItem]
    @Query(sort: \Project.name) private var projects: [Project]
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var activeSheet: TodoSheetState?
    @State private var searchText = ""
    @State private var filterMode: FilterMode = .active
    @State private var sortMode: SortMode = .dueDate
    @State private var selectedProjectFilter: Project?
    @State private var selectedTagFilter: Tag?
    @State private var todoToDelete: TodoItem?
    @State private var showDeleteConfirmation = false
    @State private var quickAddText = ""
    @State private var showCalendar = false
    @FocusState private var isQuickAddFocused: Bool

    enum TodoSheetState: Identifiable {
        case add(UUID = UUID())
        case addForDate(Date, UUID = UUID())
        case edit(TodoItem, UUID = UUID())

        var id: String {
            switch self {
            case .add(let token): return "add-\(token)"
            case .addForDate(_, let token): return "addForDate-\(token)"
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

    /// Top-level tasks only (excludes subtasks from main list)
    private var topLevelTodos: [TodoItem] {
        allTodos.filter { !$0.isSubtask }
    }

    private var filteredTodos: [TodoItem] {
        var result = topLevelTodos

        // Project filter
        if let projectFilter = selectedProjectFilter {
            result = result.filter { $0.project?.id == projectFilter.id }
        }

        // Tag filter
        if let tagFilter = selectedTagFilter {
            result = result.filter { $0.tags.contains(where: { $0.id == tagFilter.id }) }
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
            result.sort {
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return $0.dueDate < $1.dueDate
            }
        case .created:
            result.sort { $0.createdAt > $1.createdAt }
        }

        return result
    }

    var body: some View {
        let currentFiltered = filteredTodos
        NavigationStack {
            Group {
                if topLevelTodos.isEmpty {
                    emptyState
                        .transition(.opacity)
                } else if showCalendar {
                    CalendarView(
                        todos: currentFiltered,
                        onToggle: { todo in
                            toggleTodoCompleted(todo)
                        },
                        onEdit: { todo in
                            activeSheet = .edit(todo)
                        },
                        onDelete: { todo in
                            todoToDelete = todo
                            showDeleteConfirmation = true
                        },
                        onAddTask: { date in
                            guard activeSheet == nil else { return }
                            activeSheet = .addForDate(date)
                        }
                    )
                    .transition(.opacity)
                } else if currentFiltered.isEmpty {
                    filteredEmptyState
                        .transition(.opacity)
                } else {
                    todoListContent(currentFiltered)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: Theme.animDefault), value: topLevelTodos.isEmpty)
            .animation(.easeOut(duration: Theme.animDefault), value: currentFiltered.isEmpty)
            .animation(.easeOut(duration: Theme.animDefault), value: showCalendar)
            .animation(.default, value: filterMode)
            .animation(.default, value: sortMode)
            .animation(.default, value: selectedProjectFilter?.id)
            .animation(.default, value: selectedTagFilter?.id)
            .onChange(of: projects.map(\.id)) { _, newIds in
                if let selected = selectedProjectFilter, !newIds.contains(selected.id) {
                    selectedProjectFilter = nil
                }
            }
            .onChange(of: allTags.map(\.id)) { _, newIds in
                if let selected = selectedTagFilter, !newIds.contains(selected.id) {
                    selectedTagFilter = nil
                }
            }
            .navigationTitle("Tasks")
            .searchable(text: $searchText, prompt: "Search tasks...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.easeInOut(duration: Theme.animDefault)) {
                                showCalendar.toggle()
                            }
                        } label: {
                            Image(systemName: showCalendar ? "list.bullet" : "calendar")
                                .font(.body)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .accessibilityLabel(showCalendar ? "Switch to list view" : "Switch to calendar view")

                        Button(action: { guard activeSheet == nil else { return }; activeSheet = .add }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .accessibilityLabel("New task")
                        .accessibilityHint("Opens form to create a new task")
                    }
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
                case .addForDate(let date, _):
                    TodoDetailView(dueDate: date)
                        .presentationDragIndicator(.visible)
                case .edit(let todo, _):
                    if todo.isDeleted {
                        Text("")
                            .onAppear { activeSheet = nil }
                    } else {
                        TodoDetailView(todo: todo)
                            .presentationDragIndicator(.visible)
                    }
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
        filterMode != .active || sortMode != .dueDate || selectedProjectFilter != nil || selectedTagFilter != nil
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
            if !allTags.isEmpty {
                Section("Tag") {
                    Button {
                        selectedTagFilter = nil
                    } label: {
                        HStack {
                            Text("All Tags")
                            if selectedTagFilter == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    ForEach(allTags) { tag in
                        Button {
                            selectedTagFilter = tag
                        } label: {
                            HStack {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(tag.color)
                                        .frame(width: 8, height: 8)
                                    Text(tag.name)
                                }
                                if selectedTagFilter?.id == tag.id {
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
        if let tag = selectedTagFilter {
            parts.append(tag.name)
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
                .foregroundStyle(Theme.amber)
        } description: {
            Text("Stay on top of your day.\nTap the button below to create your first task.")
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
            } else if filterMode == .active && topLevelTodos.contains(where: { $0.isCompleted }) {
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
        let projectContext: String
        if let project = selectedProjectFilter {
            projectContext = " in \(project.name)"
        } else {
            projectContext = ""
        }
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

        // Clear text immediately (outside animation) to prevent duplicate
        // submissions from rapid Return key taps
        quickAddText = ""

        let item = TodoItem(title: trimmed)
        item.project = selectedProjectFilter
        if let tagFilter = selectedTagFilter {
            item.tags = [tagFilter]
        }
        modelContext.insert(item)

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }
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
                    SectionHeaderView(
                        title: "Overdue",
                        systemImage: "exclamationmark.triangle.fill",
                        tint: Theme.danger,
                        count: overdue.count
                    )
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
                    SectionHeaderView(title: "Today", systemImage: "sun.max")
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
                    SectionHeaderView(title: "Tomorrow", systemImage: "sunrise")
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
                    SectionHeaderView(title: "This Week", systemImage: "calendar")
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
                    SectionHeaderView(title: "Later", systemImage: "calendar.badge.clock")
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
                    SectionHeaderView(title: "Completed", systemImage: "checkmark.circle", tint: Theme.success)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func todoRow(_ todo: TodoItem) -> some View {
        TodoRowView(todo: todo, onToggle: {
            toggleTodoCompleted(todo)
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
                toggleTodoCompleted(todo)
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
                toggleTodoCompleted(todo)
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
            toggleTodoCompleted(todo)
        }
    }

    // MARK: - Actions

    private func toggleTodoCompleted(_ todo: TodoItem) {
        withAnimation(.snappy(duration: Theme.animSmooth)) {
            todo.toggleCompleted()
        }
        UIImpactFeedbackGenerator(style: todo.isCompleted ? .heavy : .light)
            .impactOccurred()
        handleNotificationsAfterToggle(todo)

        // If completing a recurring task, create the next occurrence
        if todo.isCompleted, let nextOccurrence = todo.createNextOccurrence() {
            modelContext.insert(nextOccurrence)
            Task {
                await NotificationManager.shared.scheduleNotification(for: nextOccurrence)
            }
        }

        // If un-completing a recurring task, remove the auto-created next occurrence
        if !todo.isCompleted && todo.recurrenceRule != .none,
           let nextDate = todo.recurrenceRule.nextDate(from: todo.dueDate) {
            if let duplicate = allTodos.first(where: {
                $0.id != todo.id
                && $0.title == todo.title
                && $0.dueDate == nextDate
                && !$0.isCompleted
                && $0.project?.id == todo.project?.id
            }) {
                NotificationManager.shared.removeNotifications(for: duplicate)
                modelContext.delete(duplicate)
            }
        }

        do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }
    }

    private func handleNotificationsAfterToggle(_ todo: TodoItem) {
        if todo.isCompleted {
            NotificationManager.shared.removeNotifications(for: todo)
            for subtask in todo.subtasks {
                NotificationManager.shared.removeNotifications(for: subtask)
            }
        } else {
            Task {
                await NotificationManager.shared.scheduleNotification(for: todo)
            }
        }
    }

    private func performDelete(_ todo: TodoItem) {
        let todoId = todo.id
        NotificationManager.shared.removeNotifications(forId: todoId)
        for subtask in todo.subtasks {
            NotificationManager.shared.removeNotifications(forId: subtask.id)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        withAnimation(.snappy(duration: Theme.animDefault)) { modelContext.delete(todo) }
        do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }
    }

    private func requestDeleteTodos(from source: [TodoItem], at offsets: IndexSet) {
        guard let first = offsets.first, first < source.count else { return }
        todoToDelete = source[first]
        showDeleteConfirmation = true
    }
}
