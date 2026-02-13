import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    private init() {}

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
        } catch {
            print("Notification authorization error: \(error)")
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Schedule Notifications for a TodoItem

    func scheduleNotification(for item: TodoItem) {
        removeNotifications(for: item)

        guard item.reminderFrequency != .none, !item.isCompleted else { return }

        switch item.reminderFrequency {
        case .none:
            break
        case .daily:
            scheduleDailyRepeating(for: item)
        case .weekly:
            scheduleWeeklyRepeating(for: item)
        case .biweekly, .monthly, .custom:
            let component: Calendar.Component
            let value: Int
            if item.reminderFrequency == .custom {
                component = .day
                value = max(1, item.customReminderDays)
            } else if let comp = item.reminderFrequency.calendarComponent {
                component = comp
                value = item.reminderFrequency.intervalValue
            } else {
                return
            }
            scheduleFiniteRecurring(for: item, component: component, value: value)
        }
    }

    private func scheduleDailyRepeating(for item: TodoItem) {
        let content = makeContent(for: item)
        let dateComponents = Calendar.current.dateComponents(
            [.hour, .minute],
            from: item.dueDate
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "\(item.id.uuidString)-repeating",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Failed to schedule daily notification: \(error)") }
        }
    }

    private func scheduleWeeklyRepeating(for item: TodoItem) {
        let content = makeContent(for: item)
        let dateComponents = Calendar.current.dateComponents(
            [.weekday, .hour, .minute],
            from: item.dueDate
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "\(item.id.uuidString)-repeating",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Failed to schedule weekly notification: \(error)") }
        }
    }

    private func scheduleFiniteRecurring(for item: TodoItem, component: Calendar.Component, value: Int) {
        let content = makeContent(for: item)
        let now = Date()
        var scheduledCount = 0
        let maxSlots = 10

        if item.dueDate > now {
            let dateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: item.dueDate
            )

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: "\(item.id.uuidString)-initial",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error { print("Failed to schedule initial notification: \(error)") }
            }
            scheduledCount += 1
        }

        for i in 1...maxSlots {
            guard scheduledCount < maxSlots else { break }

            guard let nextDate = Calendar.current.date(
                byAdding: component,
                value: value * i,
                to: item.dueDate
            ) else { continue }

            guard nextDate > now else { continue }

            if nextDate.timeIntervalSinceNow > 60 * 24 * 3600 { break }

            let recurringComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: nextDate
            )

            let recurringTrigger = UNCalendarNotificationTrigger(
                dateMatching: recurringComponents,
                repeats: false
            )

            let recurringRequest = UNNotificationRequest(
                identifier: "\(item.id.uuidString)-recurring-\(i)",
                content: content,
                trigger: recurringTrigger
            )

            UNUserNotificationCenter.current().add(recurringRequest) { error in
                if let error { print("Failed to schedule recurring notification \(i): \(error)") }
            }
            scheduledCount += 1
        }
    }

    private func makeContent(for item: TodoItem) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = item.title
        content.sound = .default

        if !item.details.isEmpty {
            content.subtitle = String(item.details.prefix(50))
        }

        return content
    }

    func removeNotifications(for item: TodoItem) {
        removeNotifications(forId: item.id)
    }

    nonisolated func removeNotifications(forId id: UUID) {
        var identifiers = [
            "\(id.uuidString)-initial",
            "\(id.uuidString)-repeating"
        ]
        for i in 1...10 {
            identifiers.append("\(id.uuidString)-recurring-\(i)")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    nonisolated static func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error { print("Failed to clear badge: \(error)") }
        }
    }
}
