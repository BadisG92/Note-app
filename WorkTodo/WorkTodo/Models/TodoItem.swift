import Foundation
import SwiftData

@Model
final class TodoItem {
    var id: UUID
    var title: String
    var details: String
    var dueDate: Date
    var isCompleted: Bool
    var completedAt: Date?
    var priorityRaw: Int
    var reminderFrequencyRaw: String
    var customReminderDays: Int
    var createdAt: Date
    var updatedAt: Date

    var project: Project?

    // MARK: - Subtasks

    var parentTask: TodoItem?

    @Relationship(deleteRule: .cascade, inverse: \TodoItem.parentTask)
    var subtasks: [TodoItem]

    // MARK: - Recurrence

    var recurrenceRuleRaw: String

    // MARK: - Tags

    @Relationship(deleteRule: .nullify, inverse: \Tag.todos)
    var tags: [Tag]

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var reminderFrequency: ReminderFrequency {
        get { ReminderFrequency(rawValue: reminderFrequencyRaw) ?? .none }
        set { reminderFrequencyRaw = newValue.rawValue }
    }

    var recurrenceRule: RecurrenceRule {
        get { RecurrenceRule(rawValue: recurrenceRuleRaw) ?? .none }
        set { recurrenceRuleRaw = newValue.rawValue }
    }

    var isOverdue: Bool {
        guard !isCompleted else { return false }
        let cal = Calendar.current
        return cal.startOfDay(for: dueDate) < cal.startOfDay(for: Date())
    }

    var dueDateFormatted: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(dueDate) {
            return "Today, \(dueDate.formatted(date: .omitted, time: .shortened))"
        } else if calendar.isDateInTomorrow(dueDate) {
            return "Tomorrow, \(dueDate.formatted(date: .omitted, time: .shortened))"
        } else if calendar.isDateInYesterday(dueDate) {
            return "Yesterday, \(dueDate.formatted(date: .omitted, time: .shortened))"
        } else {
            return dueDate.formatted(date: .abbreviated, time: .shortened)
        }
    }

    var isSubtask: Bool {
        parentTask != nil
    }

    var activeSubtaskCount: Int {
        subtasks.filter { !$0.isCompleted }.count
    }

    var completedSubtaskCount: Int {
        subtasks.filter { $0.isCompleted }.count
    }

    var subtaskProgress: Double {
        guard !subtasks.isEmpty else { return 0 }
        return Double(completedSubtaskCount) / Double(subtasks.count)
    }

    init(
        title: String,
        details: String = "",
        dueDate: Date = Date(),
        priority: Priority = .medium,
        reminderFrequency: ReminderFrequency = .none,
        customReminderDays: Int = 1,
        recurrenceRule: RecurrenceRule = .none
    ) {
        let now = Date()
        self.id = UUID()
        self.title = title
        self.details = details
        self.dueDate = dueDate
        self.isCompleted = false
        self.completedAt = nil
        self.priorityRaw = priority.rawValue
        self.reminderFrequencyRaw = reminderFrequency.rawValue
        self.customReminderDays = max(1, customReminderDays)
        self.recurrenceRuleRaw = recurrenceRule.rawValue
        self.createdAt = now
        self.updatedAt = now
        self.subtasks = []
        self.tags = []
    }

    func toggleCompleted() {
        isCompleted.toggle()
        completedAt = isCompleted ? Date() : nil
        updatedAt = Date()
    }

    /// Safely assigns a parent task, preventing self-referential cycles.
    func assignParent(_ parent: TodoItem?) {
        guard let parent = parent else {
            self.parentTask = nil
            return
        }
        guard parent.id != self.id else { return }
        // Walk up the ancestor chain to prevent deeper cycles
        var ancestor: TodoItem? = parent
        while let a = ancestor {
            if a.id == self.id { return }
            ancestor = a.parentTask
        }
        self.parentTask = parent
    }

    /// Creates the next occurrence of a recurring task. Returns nil if not recurring.
    func createNextOccurrence() -> TodoItem? {
        guard recurrenceRule != .none else { return nil }
        guard let nextDate = recurrenceRule.nextDate(from: dueDate) else { return nil }

        let next = TodoItem(
            title: title,
            details: details,
            dueDate: nextDate,
            priority: priority,
            reminderFrequency: reminderFrequency,
            customReminderDays: customReminderDays,
            recurrenceRule: recurrenceRule
        )
        next.project = project
        next.tags = tags

        // Copy subtasks so recurring checklists repeat
        for subtask in subtasks {
            let copy = TodoItem(
                title: subtask.title,
                details: subtask.details,
                dueDate: nextDate,
                priority: subtask.priority,
                reminderFrequency: subtask.reminderFrequency,
                customReminderDays: subtask.customReminderDays
            )
            copy.parentTask = next
            next.subtasks.append(copy)
        }

        return next
    }
}
