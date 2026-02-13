import SwiftUI
import SwiftData

@main
struct WorkTodoApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TodoItem.self,
            Note.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

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
                .task {
                    await NotificationManager.shared.requestAuthorization()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        NotificationManager.clearBadge()
                        Task {
                            await NotificationManager.shared.checkAuthorizationStatus()
                        }
                    case .background:
                        try? sharedModelContainer.mainContext.save()
                    default:
                        break
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
