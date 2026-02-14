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
        todos.filter { !$0.isSubtask && !$0.isCompleted }.count
    }

    var completedTodoCount: Int {
        todos.filter { !$0.isSubtask && $0.isCompleted }.count
    }

    var totalTodoCount: Int {
        todos.filter { !$0.isSubtask }.count
    }

    var completionProgress: Double {
        guard totalTodoCount > 0 else { return 0 }
        return Double(completedTodoCount) / Double(totalTodoCount)
    }

    init(
        name: String,
        colorHex: String = "C4704B",
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
        ("Terracotta", "C4704B"),
        ("Sage", "7D9B6B"),
        ("Dusty Rose", "B5727A"),
        ("Amber", "C8923C"),
        ("Slate", "728B8E"),
        ("Mauve", "9678A8"),
        ("Sand", "B5A073"),
        ("Clay", "A07558"),
        ("Storm", "6B7B8B"),
        ("Espresso", "5C524A")
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
