import SwiftUI
import SwiftData

struct ProjectFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String
    @State private var selectedColorHex: String
    @State private var selectedIcon: String
    @State private var isSaving = false
    @State private var showDiscardConfirmation = false

    private var existingProject: Project?
    private var isEditing: Bool

    // Create new
    init() {
        self.existingProject = nil
        self.isEditing = false
        _name = State(initialValue: "")
        _selectedColorHex = State(initialValue: "C4704B")
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

    private var hasUnsavedChanges: Bool {
        if isEditing, let existing = existingProject {
            return name != existing.name
                || selectedColorHex != existing.colorHex
                || selectedIcon != existing.iconName
        }
        return !name.isEmpty
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
                            Button {
                                selectedColorHex = colorOption.hex
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Circle()
                                    .fill(Color(hex: colorOption.hex))
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        if selectedColorHex == colorOption.hex {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                                .transition(.scale.combined(with: .opacity))
                                        }
                                    }
                                    .scaleEffect(selectedColorHex == colorOption.hex ? 1.12 : 1.0)
                                    .animation(.snappy(duration: 0.25), value: selectedColorHex)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(colorOption.name)
                            .accessibilityAddTraits(selectedColorHex == colorOption.hex ? .isSelected : [])
                            .accessibilityHint("Double tap to select this color")
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(Project.availableIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(selectedIcon == icon ? .white : Color(hex: selectedColorHex))
                                    .background {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedIcon == icon ? Color(hex: selectedColorHex) : Color(hex: selectedColorHex).opacity(0.12))
                                    }
                                    .scaleEffect(selectedIcon == icon ? 1.06 : 1.0)
                                    .animation(.snappy(duration: 0.25), value: selectedIcon)
                                    .animation(.snappy(duration: 0.25), value: selectedColorHex)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Self.iconLabel(for: icon))
                            .accessibilityAddTraits(selectedIcon == icon ? .isSelected : [])
                            .accessibilityHint("Double tap to select this icon")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(isEditing ? "Edit Project" : "New Project")
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
                    Button(isEditing ? "Save" : "Create") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid || isSaving)
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

    private static func iconLabel(for icon: String) -> String {
        let map: [String: String] = [
            "folder.fill": "Folder",
            "briefcase.fill": "Briefcase",
            "house.fill": "House",
            "heart.fill": "Heart",
            "star.fill": "Star",
            "book.fill": "Book",
            "graduationcap.fill": "Graduation cap",
            "cart.fill": "Shopping cart",
            "car.fill": "Car",
            "airplane": "Airplane",
            "gamecontroller.fill": "Game controller",
            "music.note": "Music",
            "hammer.fill": "Hammer",
            "lightbulb.fill": "Light bulb",
            "leaf.fill": "Leaf",
            "figure.run": "Running"
        ]
        return map[icon] ?? icon
    }
}
