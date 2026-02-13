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
                    .foregroundStyle(todo.isCompleted ? Theme.success : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Completion")
            .accessibilityValue(todo.isCompleted ? "Completed" : "Not completed")
            .accessibilityHint(todo.isCompleted ? "Double tap to mark incomplete" : "Double tap to mark complete")

            VStack(alignment: .leading, spacing: 6) {
                Text(todo.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    // Due date
                    if todo.isOverdue {
                        Label(todo.dueDateFormatted, systemImage: "calendar.badge.exclamationmark")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.danger)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.danger.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Label(todo.dueDateFormatted, systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(todo.isCompleted ? .secondary : .secondary)
                    }

                    // Recurrence indicator
                    if todo.recurrenceRule != .none {
                        Text("\u{00B7}")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                        Label(todo.recurrenceRule.label, systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(todo.isCompleted ? .secondary : Theme.mauve)
                    }

                    // Reminder indicator
                    if todo.reminderFrequency != .none {
                        Text("\u{00B7}")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                        Label(todo.reminderFrequency.label, systemImage: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(todo.isCompleted ? .secondary : Theme.amber)
                    }

                    // Project indicator
                    if let project = todo.project {
                        Text("\u{00B7}")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                        Label(project.name, systemImage: project.iconName)
                            .font(.caption)
                            .foregroundStyle(todo.isCompleted ? .secondary : project.color)
                    }
                }

                // Tags
                if !todo.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(todo.tags.prefix(4)) { tag in
                            Text(tag.name)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(tag.color.opacity(0.15))
                                .foregroundStyle(tag.color)
                                .clipShape(Capsule())
                        }
                        if todo.tags.count > 4 {
                            Text("+\(todo.tags.count - 4)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Subtasks progress
                if !todo.subtasks.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet")
                            .font(.caption2)
                        Text("\(todo.completedSubtaskCount)/\(todo.subtasks.count)")
                            .font(.caption)
                        ProgressView(value: todo.subtaskProgress)
                            .tint(todo.subtaskProgress >= 1.0 ? Theme.success : Theme.amber)
                            .frame(maxWidth: 60)
                    }
                    .foregroundStyle(todo.isCompleted ? .secondary : .tertiary)
                }

                // Details hint
                if !todo.details.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "text.alignleft")
                            .font(.caption2)
                        Text(todo.details)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(todo.isCompleted ? .secondary : .tertiary)
                }
            }

            Spacer()

            PriorityBadge(priority: todo.priority)
                .opacity(todo.isCompleted ? 0.7 : 1.0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit?()
        }
        .animation(.snappy(duration: Theme.animSmooth), value: todo.isCompleted)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(onEdit != nil ? "Double tap to edit task" : "")
    }

    private var accessibilityDescription: String {
        var parts = [todo.title]
        parts.append(todo.isCompleted ? "completed" : "active")
        parts.append("priority \(todo.priority.label)")
        parts.append("due \(todo.dueDateFormatted)")
        if todo.isOverdue { parts.append("overdue") }
        if let project = todo.project { parts.append("project \(project.name)") }
        if todo.recurrenceRule != .none { parts.append("repeats \(todo.recurrenceRule.label)") }
        if !todo.tags.isEmpty {
            parts.append("tags: \(todo.tags.map(\.name).joined(separator: ", "))")
        }
        if !todo.subtasks.isEmpty {
            parts.append("\(todo.completedSubtaskCount) of \(todo.subtasks.count) subtasks done")
        }
        return parts.joined(separator: ", ")
    }
}
