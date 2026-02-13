import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID
    var title: String
    var content: String
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date

    var preview: String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        let text = lines.first.map(String.init) ?? ""
        if text.count > 100 {
            return String(text.prefix(100)) + "..."
        }
        return text
    }

    var updatedFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: updatedAt, relativeTo: Date())
    }

    init(title: String = "", content: String = "") {
        self.id = UUID()
        self.title = title
        self.content = content
        self.isPinned = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
