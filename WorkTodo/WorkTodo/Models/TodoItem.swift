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
        guard !isCompleted else { return false }
        return Calendar.current.startOfDay(for: dueDate) < Calendar.current.startOfDay(for: Date())
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var dueDateFormatted: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(dueDate) {
            return "Today, \(Self.timeFormatter.string(from: dueDate))"
        } else if calendar.isDateInTomorrow(dueDate) {
            return "Tomorrow, \(Self.timeFormatter.string(from: dueDate))"
        } else if calendar.isDateInYesterday(dueDate) {
            return "Yesterday, \(Self.timeFormatter.string(from: dueDate))"
        } else {
            return Self.dateFormatter.string(from: dueDate)
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
