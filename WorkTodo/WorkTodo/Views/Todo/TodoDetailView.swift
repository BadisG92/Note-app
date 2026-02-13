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
    @State private var isSaving = false
    @State private var showDiscardConfirmation = false
    @FocusState private var focusedField: Field?

    @Query(sort: \Project.name) private var projects: [Project]

    private var existingItem: TodoItem?
    private var isEditing: Bool

    private enum Field: Hashable {
        case title
        case details
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
                || selectedProject?.id != existing.project?.id
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

                ReminderFrequencyPicker(
                    frequency: $reminderFrequency,
                    customDays: $customReminderDays
                )
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
            .task {
                if !isEditing {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    focusedField = .title
                }
            }
        }
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { isSaving = false; return }

        let itemToSchedule: TodoItem

        if let existing = existingItem {
            existing.title = trimmedTitle
            existing.details = details
            existing.dueDate = dueDate
            existing.priority = priority
            existing.reminderFrequency = reminderFrequency
            existing.customReminderDays = customReminderDays
            existing.project = selectedProject
            existing.updatedAt = Date()
            itemToSchedule = existing
        } else {
            let item = TodoItem(
                title: trimmedTitle,
                details: details,
                dueDate: dueDate,
                priority: priority,
                reminderFrequency: reminderFrequency,
                customReminderDays: customReminderDays
            )
            item.project = selectedProject
            modelContext.insert(item)
            itemToSchedule = item
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Save model context before dismissing
        try? modelContext.save()

        // Schedule notification before dismiss so the model object is still valid
        await NotificationManager.shared.scheduleNotification(for: itemToSchedule)

        dismiss()
    }
}
