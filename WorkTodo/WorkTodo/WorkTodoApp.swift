import SwiftUI
import SwiftData
import WidgetKit

@main
struct WorkTodoApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TodoItem.self,
            Note.self,
            Project.self,
            Tag.self
        ])
        let modelConfiguration: ModelConfiguration
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.WorkTodo") {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                url: containerURL.appending(path: "WorkTodo.store"),
                isStoredInMemoryOnly: false
            )
        } else {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
        }

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Attempt recovery: delete corrupt store and retry
            print("ModelContainer creation failed: \(error). Attempting recovery...")
            let url = modelConfiguration.url
            let relatedFiles = [
                url,
                url.appendingPathExtension("wal"),
                url.appendingPathExtension("shm")
            ]
            for file in relatedFiles {
                try? FileManager.default.removeItem(at: file)
            }

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after recovery: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onOpenURL { url in
                    if url.scheme == "worktodo" && url.host == "today" {
                        UserDefaults.standard.set(0, forKey: "selectedTab")
                    }
                }
                .task {
                    await NotificationManager.shared.requestAuthorization()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        NotificationManager.clearBadge()
                        Task { @MainActor in
                            await NotificationManager.shared.checkAuthorizationStatus()
                            // Top up finite recurring notifications that may have been
                            // exhausted (60-day scheduling window)
                            await refreshNotifications()
                        }
                    case .background:
                        do { try sharedModelContainer.mainContext.save() } catch { print("[WorkTodo] background save failed: \(error)") }
                        WidgetCenter.shared.reloadAllTimelines()
                    default:
                        break
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Re-schedule notifications for active tasks with reminders, topping up
    /// the 60-day finite window so recurring reminders never silently stop.
    @MainActor
    private func refreshNotifications() async {
        guard NotificationManager.shared.isAuthorized else { return }
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<TodoItem>(
            sortBy: [SortDescriptor(\TodoItem.dueDate)]
        )
        guard let todos = try? context.fetch(descriptor) else { return }
        let active = todos.filter { !$0.isCompleted && $0.parentTask == nil && $0.reminderFrequency != .none }
        for todo in active {
            await NotificationManager.shared.scheduleNotification(for: todo)
        }
    }
}
