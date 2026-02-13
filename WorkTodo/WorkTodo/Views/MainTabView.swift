import SwiftUI
import SwiftData

struct MainTabView: View {
    @AppStorage("selectedTab") private var selectedTab = 0
    @Query(sort: \TodoItem.dueDate) private var allTodos: [TodoItem]

    /// Badge shows only overdue + due today top-level tasks (actionable items)
    private var badgeCount: Int {
        let calendar = Calendar.current
        return allTodos.filter { todo in
            !todo.isSubtask && !todo.isCompleted && (
                todo.isOverdue ||
                calendar.isDateInToday(todo.dueDate)
            )
        }.count
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodoListView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
                .tag(0)
                .badge(badgeCount)

            NoteListView()
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
                .tag(1)

            ProjectListView()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }
                .tag(2)
        }
        .tint(.accentColor)
    }
}
