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
        // Remove any existing notifications for this item
        removeNotifications(for: item)

        guard item.reminderFrequency != .none, !item.isCompleted else { return }

        switch item.reminderFrequency {
        case .none:
            break
        case .custom:
            scheduleRepeating(for: item, component: .day, value: item.customReminderDays)
        default:
            if let component = item.reminderFrequency.calendarComponent {
                scheduleRepeating(for: item, component: component, value: item.reminderFrequency.intervalValue)
            }
        }
    }

    private func scheduleRepeating(for item: TodoItem, component: Calendar.Component, value: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = item.title
        content.sound = .default
        content.badge = 1

        if !item.details.isEmpty {
            content.subtitle = String(item.details.prefix(50))
        }

        // Schedule the first notification at the due date
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

        UNUserNotificationCenter.current().add(request)

        // Schedule recurring reminders (up to 10 future occurrences)
        var nextDate = item.dueDate
        for i in 1...10 {
            guard let next = Calendar.current.date(
                byAdding: component,
                value: value * i,
                to: item.dueDate
            ) else { continue }

            nextDate = next

            // Don't schedule notifications more than 60 days out
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

            UNUserNotificationCenter.current().add(recurringRequest)
        }
    }

    func removeNotifications(for item: TodoItem) {
        var identifiers = ["\(item.id.uuidString)-initial"]
        for i in 1...10 {
            identifiers.append("\(item.id.uuidString)-recurring-\(i)")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
