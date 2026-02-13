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

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var reminderFrequency: ReminderFrequency {
        get { ReminderFrequency(rawValue: reminderFrequencyRaw) ?? .none }
        set { reminderFrequencyRaw = newValue.rawValue }
    }

    var isOverdue: Bool {
        !isCompleted && dueDate < Date()
    }

    var dueDateFormatted: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(dueDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(dueDate) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(dueDate) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: dueDate)
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
        self.id = UUID()
        self.title = title
        self.details = details
        self.dueDate = dueDate
        self.isCompleted = false
        self.completedAt = nil
        self.priorityRaw = priority.rawValue
        self.reminderFrequencyRaw = reminderFrequency.rawValue
        self.customReminderDays = customReminderDays
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func toggleCompleted() {
        isCompleted.toggle()
        completedAt = isCompleted ? Date() : nil
        updatedAt = Date()
    }
}
