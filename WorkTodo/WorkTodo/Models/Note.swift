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
        let lines = content.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
        let text = lines.first.map(String.init) ?? ""
        if text.count > 100 {
            return String(text.prefix(100)) + "..."
        }
        return text
    }

    var updatedFormatted: String {
        updatedAt.formatted(.relative(presentation: .named))
    }

    init(title: String = "", content: String = "") {
        let now = Date()
        self.id = UUID()
        self.title = title
        self.content = content
        self.isPinned = false
        self.createdAt = now
        self.updatedAt = now
    }
}
