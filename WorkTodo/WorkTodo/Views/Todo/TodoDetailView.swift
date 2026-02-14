import SwiftUI
import SwiftData

struct TodoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title: String
    @State private var details: String
    @State private var dueDate: Date
    @State private var priority: Priority
    @State private var reminderFrequency: ReminderFrequency
    @State private var customReminderDays: Int
    @State private var selectedProject: Project?
    @State private var recurrenceRule: RecurrenceRule
    @State private var selectedTags: Set<UUID>
    @State private var newSubtaskTitle = ""
    @State private var isSaving = false
    @State private var showDiscardConfirmation = false
    @State private var showNewTagSheet = false
    @FocusState private var focusedField: Field?

    @Query(sort: \Project.name) private var projects: [Project]
    @Query(sort: \Tag.name) private var allTags: [Tag]

    private var existingItem: TodoItem?
    private var isEditing: Bool

    private enum Field: Hashable {
        case title
        case details
        case subtask
    }

    // Create new
    init(project: Project? = nil, dueDate: Date = Date()) {
        self.existingItem = nil
        self.isEditing = false
        _title = State(initialValue: "")
        _details = State(initialValue: "")
        _dueDate = State(initialValue: dueDate)
        _priority = State(initialValue: .medium)
        _reminderFrequency = State(initialValue: .none)
        _customReminderDays = State(initialValue: 1)
        _selectedProject = State(initialValue: project)
        _recurrenceRule = State(initialValue: .none)
        _selectedTags = State(initialValue: [])
    }

    // Edit existing
    init(todo: TodoItem) {
        self.existingItem = todo
        self.isEditing = true
        _title = State(initialValue: todo.title)
        _details = State(initialValue: todo.details)
        _dueDate = State(initialValue: todo.dueDate)
        _priority = State(initialValue: todo.priority)
        _reminderFrequency = State(initialValue: todo.reminderFrequency)
        _customReminderDays = State(initialValue: todo.customReminderDays)
        _selectedProject = State(initialValue: todo.project)
        _recurrenceRule = State(initialValue: todo.recurrenceRule)
        _selectedTags = State(initialValue: Set(todo.tags.map(\.id)))
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasUnsavedChanges: Bool {
        if isEditing, let existing = existingItem {
            return title != existing.title
                || details != existing.details
                || dueDate != existing.dueDate
                || priority != existing.priority
                || reminderFrequency != existing.reminderFrequency
                || customReminderDays != existing.customReminderDays
                || selectedProject?.id != existing.project?.id
                || recurrenceRule != existing.recurrenceRule
                || selectedTags != Set(existing.tags.map(\.id))
        }
        return !title.isEmpty || !details.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task title", text: $title)
                        .font(.headline)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .details
                        }

                    TextField("Details (optional)", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($focusedField, equals: .details)
                        .submitLabel(.done)
                        .onSubmit {
                            focusedField = nil
                        }
                } header: {
                    Text("Task")
                }

                if !projects.isEmpty {
                    Section("Project") {
                        Picker("Project", selection: $selectedProject) {
                            Text("None")
                                .tag(nil as Project?)
                            ForEach(projects) { project in
                                Label(project.name, systemImage: project.iconName)
                                    .foregroundStyle(project.color)
                                    .tag(project as Project?)
                            }
                        }
                    }
                }

                Section("Due Date") {
                    DatePicker(
                        "Due",
                        selection: $dueDate,
                        in: (isEditing ? .distantPast : Date())...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: - Recurrence

                Section {
                    Picker("Repeat", selection: $recurrenceRule) {
                        ForEach(RecurrenceRule.allCases) { rule in
                            Text(rule.label).tag(rule)
                        }
                    }
                } header: {
                    Text("Recurrence")
                } footer: {
                    if recurrenceRule != .none {
                        Text("A new task will be created automatically when you complete this one.")
                    }
                }

                ReminderFrequencyPicker(
                    frequency: $reminderFrequency,
                    customDays: $customReminderDays
                )

                // MARK: - Tags

                Section {
                    if allTags.isEmpty {
                        Button {
                            showNewTagSheet = true
                        } label: {
                            Label("Create your first tag", systemImage: "plus.circle")
                        }
                    } else {
                        ForEach(allTags) { tag in
                            Button {
                                toggleTag(tag)
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(tag.color)
                                        .frame(width: 12, height: 12)
                                    Text(tag.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedTags.contains(tag.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                        Button {
                            showNewTagSheet = true
                        } label: {
                            Label("New Tag", systemImage: "plus.circle")
                                .font(.subheadline)
                        }
                    }
                } header: {
                    Text("Tags")
                }

                // MARK: - Subtasks (only when editing)

                if isEditing, let existing = existingItem {
                    Section {
                        ForEach(existing.subtasks.sorted(by: { ($0.isCompleted ? 1 : 0) < ($1.isCompleted ? 1 : 0) })) { subtask in
                            HStack(spacing: 10) {
                                Button {
                                    withAnimation(.snappy(duration: Theme.animSmooth)) {
                                        subtask.toggleCompleted()
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }
                                } label: {
                                    Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(subtask.isCompleted ? Theme.success : .secondary)
                                        .contentTransition(.symbolEffect(.replace))
                                }
                                .buttonStyle(.borderless)

                                Text(subtask.title)
                                    .strikethrough(subtask.isCompleted)
                                    .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
                            }
                        }
                        .onDelete { offsets in
                            let sorted = existing.subtasks.sorted(by: { ($0.isCompleted ? 1 : 0) < ($1.isCompleted ? 1 : 0) })
                            for index in offsets {
                                modelContext.delete(sorted[index])
                            }
                            do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }
                        }

                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.tint)
                            TextField("Add subtask...", text: $newSubtaskTitle)
                                .focused($focusedField, equals: .subtask)
                                .submitLabel(.done)
                                .onSubmit {
                                    addSubtask(to: existing)
                                }
                        }
                    } header: {
                        HStack {
                            Text("Subtasks")
                            if !existing.subtasks.isEmpty {
                                Spacer()
                                Text("\(existing.completedSubtaskCount)/\(existing.subtasks.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid || isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        focusedField = nil
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                    .accessibilityLabel("Dismiss keyboard")
                }
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .confirmationDialog(
                "Discard Changes?",
                isPresented: $showDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard Changes", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) { }
            }
            .sheet(isPresented: $showNewTagSheet) {
                NewTagSheet { tag in
                    selectedTags.insert(tag.id)
                }
            }
            .task {
                if !isEditing {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    focusedField = .title
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleTag(_ tag: Tag) {
        if selectedTags.contains(tag.id) {
            selectedTags.remove(tag.id)
        } else {
            selectedTags.insert(tag.id)
        }
    }

    private func addSubtask(to parent: TodoItem) {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let subtask = TodoItem(title: trimmed, dueDate: parent.dueDate)
        subtask.assignParent(parent)
        subtask.project = parent.project
        modelContext.insert(subtask)

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }

        newSubtaskTitle = ""
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let itemToSchedule: TodoItem

        if let existing = existingItem {
            existing.title = trimmedTitle
            existing.details = details
            existing.dueDate = dueDate
            existing.priority = priority
            existing.reminderFrequency = reminderFrequency
            existing.customReminderDays = customReminderDays
            existing.project = selectedProject
            existing.recurrenceRule = recurrenceRule
            existing.tags = allTags.filter { selectedTags.contains($0.id) }
            existing.updatedAt = Date()
            itemToSchedule = existing
        } else {
            let item = TodoItem(
                title: trimmedTitle,
                details: details,
                dueDate: dueDate,
                priority: priority,
                reminderFrequency: reminderFrequency,
                customReminderDays: customReminderDays,
                recurrenceRule: recurrenceRule
            )
            item.project = selectedProject
            item.tags = allTags.filter { selectedTags.contains($0.id) }
            modelContext.insert(item)
            itemToSchedule = item
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Save model context before dismissing
        do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }

        // Schedule notification before dismiss so the model object is still valid
        await NotificationManager.shared.scheduleNotification(for: itemToSchedule)

        dismiss()
    }
}

// MARK: - New Tag Sheet

struct NewTagSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var selectedColorHex = "C4704B"

    var onCreated: ((Tag) -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Tag name", text: $name)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(Tag.availableColors, id: \.hex) { colorOption in
                            Button {
                                selectedColorHex = colorOption.hex
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Circle()
                                    .fill(Color(hex: colorOption.hex))
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if selectedColorHex == colorOption.hex {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .scaleEffect(selectedColorHex == colorOption.hex ? 1.12 : 1.0)
                                    .animation(.snappy(duration: 0.25), value: selectedColorHex)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(colorOption.name)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let tag = Tag(name: trimmed, colorHex: selectedColorHex)
                        modelContext.insert(tag)
                        do { try modelContext.save() } catch { print("[WorkTodo] save failed: \(error)") }
                        onCreated?(tag)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
