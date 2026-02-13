import SwiftUI
import SwiftData

struct MainTabView: View {
    @AppStorage("selectedTab") private var selectedTab = 0
    @Query(sort: \TodoItem.dueDate) private var allTodos: [TodoItem]

    private var badgeCount: Int {
        allTodos.filter { !$0.isCompleted }.count
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
        }
        .tint(.accentColor)
    }
}
