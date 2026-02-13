import Foundation

enum RecurrenceRule: String, Codable, CaseIterable, Identifiable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Never"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 Weeks"
        case .monthly: return "Monthly"
        }
    }

    var systemImage: String {
        switch self {
        case .none: return "arrow.triangle.2.circlepath.circle"
        case .daily: return "arrow.triangle.2.circlepath"
        case .weekly: return "arrow.triangle.2.circlepath"
        case .biweekly: return "arrow.triangle.2.circlepath"
        case .monthly: return "arrow.triangle.2.circlepath"
        }
    }

    func nextDate(from date: Date) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .none:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        }
    }
}
