import Foundation

enum ReminderFrequency: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Every 2 Weeks"
    case monthly = "Monthly"
    case custom = "Custom"

    var id: String { rawValue }

    var calendarComponent: Calendar.Component? {
        switch self {
        case .none: return nil
        case .daily: return .day
        case .weekly: return .weekOfYear
        case .biweekly: return .weekOfYear
        case .monthly: return .month
        case .custom: return .day
        }
    }

    var intervalValue: Int {
        switch self {
        case .none: return 0
        case .daily: return 1
        case .weekly: return 1
        case .biweekly: return 2
        case .monthly: return 1
        case .custom: return 1
        }
    }

    var systemImage: String {
        switch self {
        case .none: return "bell.slash"
        case .daily: return "sun.max"
        case .weekly: return "calendar.badge.clock"
        case .biweekly: return "calendar"
        case .monthly: return "calendar.circle"
        case .custom: return "gearshape"
        }
    }
}
