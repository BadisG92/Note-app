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

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var reminderFrequency: ReminderFrequency {
        get { ReminderFrequency(rawValue: reminderFrequencyRaw) ?? .none }
        set { reminderFrequencyRaw = newValue.rawValue }
    }

    var isOverdue: Bool {
        guard !isCompleted else { return false }
        return Calendar.current.startOfDay(for: dueDate) < Calendar.current.startOfDay(for: Date())
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

    init(
        title: String,
        details: String = "",
        dueDate: Date = Date(),
        priority: Priority = .medium,
        reminderFrequency: ReminderFrequency = .none,
        customReminderDays: Int = 1
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
        self.createdAt = now
        self.updatedAt = now
    }

    func toggleCompleted() {
        isCompleted.toggle()
        completedAt = isCompleted ? Date() : nil
        updatedAt = Date()
    }
}
