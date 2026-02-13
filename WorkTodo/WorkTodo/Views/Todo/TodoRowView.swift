import SwiftUI

struct TodoRowView: View {
    @Bindable var todo: TodoItem
    let onToggle: () -> Void
    var onEdit: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
                    .symbolEffect(.bounce, value: todo.isCompleted)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(todo.isCompleted ? "Mark incomplete" : "Mark complete")

            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .tertiary : .primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // Due date -- bold red with background when overdue
                    if todo.isOverdue {
                        Label(todo.dueDateFormatted, systemImage: "calendar.badge.exclamationmark")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Label(todo.dueDateFormatted, systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(todo.isCompleted ? .tertiary : .secondary)
                    }

                    // Reminder indicator
                    if todo.reminderFrequency != .none {
                        Label(todo.reminderFrequency.label, systemImage: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(todo.isCompleted ? .tertiary : .orange)
                    }

                    // Project indicator
                    if let project = todo.project {
                        Label(project.name, systemImage: project.iconName)
                            .font(.caption)
                            .foregroundStyle(todo.isCompleted ? .tertiary : project.color)
                    }
                }

                if !todo.details.isEmpty {
                    Text(todo.details)
                        .font(.caption)
                        .foregroundStyle(todo.isCompleted ? .tertiary : .secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            PriorityBadge(priority: todo.priority)
                .opacity(todo.isCompleted ? 0.5 : 1.0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit?()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = [todo.title]
        parts.append(todo.isCompleted ? "completed" : "active")
        parts.append("priority \(todo.priority.label)")
        parts.append("due \(todo.dueDateFormatted)")
        if todo.isOverdue { parts.append("overdue") }
        if let project = todo.project { parts.append("project \(project.name)") }
        return parts.joined(separator: ", ")
    }
}
