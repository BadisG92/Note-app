import Foundation
import SwiftData
import SwiftUI

@Model
final class Tag {
    var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date

    var todos: [TodoItem]

    var color: Color {
        Color(hex: colorHex)
    }

    init(name: String, colorHex: String = "C4704B") {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
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
        ("Storm", "6B7B8B"),
    ]
}
