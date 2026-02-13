import SwiftUI
import SwiftData

struct ProjectFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String
    @State private var selectedColorHex: String
    @State private var selectedIcon: String
    @State private var isSaving = false

    private var existingProject: Project?
    private var isEditing: Bool

    // Create new
    init() {
        self.existingProject = nil
        self.isEditing = false
        _name = State(initialValue: "")
        _selectedColorHex = State(initialValue: "007AFF")
        _selectedIcon = State(initialValue: "folder.fill")
    }

    // Edit existing
    init(project: Project) {
        self.existingProject = project
        self.isEditing = true
        _name = State(initialValue: project.name)
        _selectedColorHex = State(initialValue: project.colorHex)
        _selectedIcon = State(initialValue: project.iconName)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Project name", text: $name)
                        .font(.headline)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(Project.availableColors, id: \.hex) { colorOption in
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
                                .onTapGesture {
                                    selectedColorHex = colorOption.hex
                                }
                                .accessibilityLabel(colorOption.name)
                                .accessibilityAddTraits(selectedColorHex == colorOption.hex ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(Project.availableIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .foregroundStyle(selectedIcon == icon ? .white : Color(hex: selectedColorHex))
                                .background {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedIcon == icon ? Color(hex: selectedColorHex) : Color(hex: selectedColorHex).opacity(0.12))
                                }
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                                .accessibilityLabel(icon)
                                .accessibilityAddTraits(selectedIcon == icon ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                if isEditing, let project = existingProject {
                    Section {
                        HStack {
                            Text("Active tasks")
                            Spacer()
                            Text("\(project.activeTodoCount)")
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Completed tasks")
                            Spacer()
                            Text("\(project.completedTodoCount)")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Stats")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Project" : "New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid || isSaving)
                }
            }
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { isSaving = false; return }

        if let existing = existingProject {
            existing.name = trimmedName
            existing.colorHex = selectedColorHex
            existing.iconName = selectedIcon
            existing.updatedAt = Date()
        } else {
            let project = Project(
                name: trimmedName,
                colorHex: selectedColorHex,
                iconName: selectedIcon
            )
            modelContext.insert(project)
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        try? modelContext.save()
        dismiss()
    }
}
