import Foundation
import SwiftData
import SwiftUI

@Model
final class Project {
    var id: UUID
    var name: String
    var colorHex: String
    var iconName: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \TodoItem.project)
    var todos: [TodoItem]

    var color: Color {
        Color(hex: colorHex)
    }

    var activeTodoCount: Int {
        todos.filter { !$0.isCompleted }.count
    }

    var completedTodoCount: Int {
        todos.filter { $0.isCompleted }.count
    }

    var totalTodoCount: Int {
        todos.count
    }

    var completionProgress: Double {
        guard totalTodoCount > 0 else { return 0 }
        return Double(completedTodoCount) / Double(totalTodoCount)
    }

    init(
        name: String,
        colorHex: String = "007AFF",
        iconName: String = "folder.fill"
    ) {
        let now = Date()
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.createdAt = now
        self.updatedAt = now
        self.todos = []
    }

    static let availableColors: [(name: String, hex: String)] = [
        ("Blue", "007AFF"),
        ("Purple", "AF52DE"),
        ("Pink", "FF2D55"),
        ("Red", "FF3B30"),
        ("Orange", "FF9500"),
        ("Yellow", "FFCC00"),
        ("Green", "34C759"),
        ("Teal", "5AC8FA"),
        ("Indigo", "5856D6"),
        ("Gray", "8E8E93")
    ]

    static let availableIcons: [String] = [
        "folder.fill",
        "briefcase.fill",
        "house.fill",
        "heart.fill",
        "star.fill",
        "book.fill",
        "graduationcap.fill",
        "cart.fill",
        "car.fill",
        "airplane",
        "gamecontroller.fill",
        "music.note",
        "hammer.fill",
        "lightbulb.fill",
        "leaf.fill",
        "figure.run"
    ]
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}
