import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodoListView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
                .tag(0)

            NoteListView()
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
                .tag(1)
        }
        .tint(.blue)
    }
}
