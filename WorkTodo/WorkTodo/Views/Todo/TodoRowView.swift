import SwiftUI

struct TodoRowView: View {
    @Bindable var todo: TodoItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)

                HStack(spacing: 8) {
                    // Due date
                    Label(todo.dueDateFormatted, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(todo.isOverdue ? .red : .secondary)

                    // Reminder indicator
                    if todo.reminderFrequency != .none {
                        Label(todo.reminderFrequency.label, systemImage: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                if !todo.details.isEmpty {
                    Text(todo.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            PriorityBadge(priority: todo.priority)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
