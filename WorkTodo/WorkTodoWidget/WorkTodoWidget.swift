import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Provider

struct TodoWidgetProvider: TimelineProvider {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([TodoItem.self, Project.self, Tag.self, Note.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        self.modelContainer = (try? ModelContainer(for: schema, configurations: [config]))
            ?? (try! ModelContainer(for: schema))
    }

    func placeholder(in context: Context) -> TodoWidgetEntry {
        TodoWidgetEntry(
            date: Date(),
            todayTasks: [
                .init(title: "Design review", isCompleted: false, priority: 2, isOverdue: false),
                .init(title: "Team standup", isCompleted: true, priority: 1, isOverdue: false),
                .init(title: "Ship feature", isCompleted: false, priority: 3, isOverdue: true),
            ],
            overdueCount: 1,
            todayActiveCount: 1,
            totalActiveCount: 5
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoWidgetEntry) -> Void) {
        let entry = fetchEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoWidgetEntry>) -> Void) {
        let entry = fetchEntry()
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    @MainActor
    private func fetchEntry() -> TodoWidgetEntry {
        let context = modelContainer.mainContext
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate<TodoItem> { item in
                item.parentTask == nil
            },
            sortBy: [SortDescriptor(\TodoItem.dueDate)]
        )

        let allTodos = (try? context.fetch(descriptor)) ?? []

        let activeTodos = allTodos.filter { !$0.isCompleted }

        let todayTodos = activeTodos.filter { todo in
            todo.dueDate >= startOfToday && todo.dueDate < endOfToday
        }

        let overdueTodos = activeTodos.filter { todo in
            calendar.startOfDay(for: todo.dueDate) < startOfToday
        }

        let displayTasks: [WidgetTask] = (overdueTodos + todayTodos).prefix(6).map { todo in
            WidgetTask(
                title: todo.title,
                isCompleted: todo.isCompleted,
                priority: todo.priorityRaw,
                isOverdue: todo.isOverdue
            )
        }

        return TodoWidgetEntry(
            date: Date(),
            todayTasks: displayTasks,
            overdueCount: overdueTodos.count,
            todayActiveCount: todayTodos.count,
            totalActiveCount: activeTodos.count
        )
    }
}

// MARK: - Entry

struct WidgetTask: Identifiable {
    let id = UUID()
    let title: String
    let isCompleted: Bool
    let priority: Int
    let isOverdue: Bool
}

struct TodoWidgetEntry: TimelineEntry {
    let date: Date
    let todayTasks: [WidgetTask]
    let overdueCount: Int
    let todayActiveCount: Int
    let totalActiveCount: Int
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: TodoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "checklist")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "C8923C"))
                Text("WorkTodo")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            if entry.totalActiveCount == 0 {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "party.popper")
                            .font(.title2)
                            .foregroundStyle(Color(hex: "C8923C"))
                        Text("All Done!")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.totalActiveCount)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("active tasks")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if entry.overdueCount > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: "BF5B3F"))
                            .frame(width: 6, height: 6)
                        Text("\(entry.overdueCount) overdue")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(Color(hex: "BF5B3F"))
                    }
                }

                if entry.todayActiveCount > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: "C8923C"))
                            .frame(width: 6, height: 6)
                        Text("\(entry.todayActiveCount) due today")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(Color(hex: "C8923C"))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: TodoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "checklist")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "C8923C"))
                Text("Today's Tasks")
                    .font(.caption)
                    .fontWeight(.semibold)

                Spacer()

                if entry.overdueCount > 0 {
                    Text("\(entry.overdueCount) overdue")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "BF5B3F").opacity(0.15))
                        .foregroundStyle(Color(hex: "BF5B3F"))
                        .clipShape(Capsule())
                }

                Text("\(entry.totalActiveCount) active")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if entry.todayTasks.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.title3)
                            .foregroundStyle(Color(hex: "7D9B6B"))
                        Text("Nothing due today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.todayTasks.prefix(4)) { task in
                    HStack(spacing: 8) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundStyle(task.isCompleted
                                ? Color(hex: "7D9B6B")
                                : task.isOverdue ? Color(hex: "BF5B3F") : .secondary)

                        Text(task.title)
                            .font(.caption)
                            .lineLimit(1)
                            .strikethrough(task.isCompleted)
                            .foregroundStyle(task.isCompleted ? .secondary : .primary)

                        Spacer()

                        if task.isOverdue {
                            Text("overdue")
                                .font(.system(size: 9))
                                .foregroundStyle(Color(hex: "BF5B3F"))
                        }
                    }
                }

                if entry.todayTasks.count > 4 {
                    Text("+\(entry.todayTasks.count - 4) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Lock Screen Widget View (Accessory)

struct AccessoryWidgetView: View {
    let entry: TodoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                    .font(.caption)
                Text("\(entry.totalActiveCount)")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            Text("tasks")
                .font(.caption2)
        }
    }
}

// MARK: - Widget Definition

struct WorkTodoWidget: Widget {
    let kind: String = "WorkTodoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoWidgetProvider()) { entry in
            Group {
                if #available(iOSApplicationExtension 17.0, *) {
                    widgetContent(for: entry)
                        .containerBackground(.fill.tertiary, for: .widget)
                } else {
                    widgetContent(for: entry)
                        .padding()
                        .background()
                }
            }
        }
        .configurationDisplayName("Tasks")
        .description("See your tasks at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }

    @ViewBuilder
    private func widgetContent(for entry: TodoWidgetEntry) -> some View {
        SmallWidgetView(entry: entry)
    }
}

struct WorkTodoMediumWidget: Widget {
    let kind: String = "WorkTodoMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoWidgetProvider()) { entry in
            Group {
                if #available(iOSApplicationExtension 17.0, *) {
                    MediumWidgetView(entry: entry)
                        .containerBackground(.fill.tertiary, for: .widget)
                } else {
                    MediumWidgetView(entry: entry)
                        .padding()
                        .background()
                }
            }
        }
        .configurationDisplayName("Today's Tasks")
        .description("See today's task list.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct WorkTodoWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkTodoWidget()
        WorkTodoMediumWidget()
    }
}

// MARK: - Color Extension (Widget-local)

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
