import SwiftUI
import SwiftData

struct CalendarView: View {
    let todos: [TodoItem]
    let onToggle: (TodoItem) -> Void
    let onEdit: (TodoItem) -> Void
    let onDelete: (TodoItem) -> Void

    @State private var displayedMonth = Date()
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())

    private let calendar = Calendar.current
    private let weekdaySymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.shortWeekdaySymbols.map { String($0.prefix(2)) }
    }()

    // MARK: - Computed

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var daysInGrid: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }

        // Pad to fill last row
        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    /// Map: startOfDay -> todos for that day
    private var todosByDay: [Date: [TodoItem]] {
        Dictionary(grouping: todos) { todo in
            calendar.startOfDay(for: todo.dueDate)
        }
    }

    private var selectedDayTodos: [TodoItem] {
        (todosByDay[selectedDate] ?? []).sorted { $0.dueDate < $1.dueDate }
    }

    private var todayStart: Date {
        calendar.startOfDay(for: Date())
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                calendarHeader
                weekdayHeader
                calendarGrid
                selectedDaySection
            }
        }
    }

    // MARK: - Calendar Header

    private var calendarHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    moveMonth(by: -1)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Previous month")

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    displayedMonth = Date()
                    selectedDate = todayStart
                }
            } label: {
                Text(monthTitle)
                    .font(.headline)
            }
            .accessibilityLabel("Go to today, currently showing \(monthTitle)")

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    moveMonth(by: 1)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Next month")
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(adjustedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    private var adjustedWeekdaySymbols: [String] {
        let first = calendar.firstWeekday - 1
        return Array(weekdaySymbols[first...]) + Array(weekdaySymbols[..<first])
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(daysInGrid.enumerated()), id: \.offset) { _, date in
                if let date = date {
                    dayCell(for: date)
                } else {
                    Color.clear
                        .frame(height: 44)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private func dayCell(for date: Date) -> some View {
        let day = calendar.component(.day, from: date)
        let startOfDate = calendar.startOfDay(for: date)
        let isSelected = startOfDate == selectedDate
        let isToday = calendar.isDateInToday(date)
        let dayTodos = todosByDay[startOfDate] ?? []
        let hasOverdue = dayTodos.contains { $0.isOverdue }
        let activeTodos = dayTodos.filter { !$0.isCompleted }
        let allCompleted = !dayTodos.isEmpty && activeTodos.isEmpty

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = startOfDate
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.subheadline)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(dayTextColor(isSelected: isSelected, isToday: isToday))
                    .frame(width: 32, height: 32)
                    .background {
                        if isSelected {
                            Circle()
                                .fill(.tint)
                        } else if isToday {
                            Circle()
                                .strokeBorder(.tint, lineWidth: 1.5)
                        }
                    }

                // Task indicators
                HStack(spacing: 3) {
                    if !dayTodos.isEmpty {
                        if hasOverdue {
                            Circle()
                                .fill(Theme.danger)
                                .frame(width: 5, height: 5)
                        } else if allCompleted {
                            Circle()
                                .fill(Theme.success)
                                .frame(width: 5, height: 5)
                        } else {
                            let count = min(activeTodos.count, 3)
                            ForEach(0..<count, id: \.self) { _ in
                                Circle()
                                    .fill(Theme.amber)
                                    .frame(width: 5, height: 5)
                            }
                        }
                    }
                }
                .frame(height: 5)
            }
            .frame(height: 44)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayCellAccessibilityLabel(day: day, date: date, todoCount: dayTodos.count, isToday: isToday))
    }

    private func dayTextColor(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected {
            return .white
        }
        return .primary
    }

    private func dayCellAccessibilityLabel(day: Int, date: Date, todoCount: Int, isToday: Bool) -> String {
        var label = date.formatted(date: .long, time: .omitted)
        if isToday { label += ", today" }
        if todoCount > 0 {
            label += ", \(todoCount) task\(todoCount == 1 ? "" : "s")"
        }
        return label
    }

    // MARK: - Selected Day Section

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 6) {
                Text(selectedDateTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if !selectedDayTodos.isEmpty {
                    Text("\(selectedDayTodos.count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.tint, in: Capsule())
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)

            if selectedDayTodos.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("No tasks for this day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(selectedDayTodos) { todo in
                        calendarTodoRow(todo)
                        if todo.id != selectedDayTodos.last?.id {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 16)
    }

    private var selectedDateTitle: String {
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(selectedDate) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            return selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide))
        }
    }

    private func calendarTodoRow(_ todo: TodoItem) -> some View {
        HStack(spacing: 12) {
            Button { onToggle(todo) } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(todo.isCompleted ? Theme.success : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 3) {
                Text(todo.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(todo.dueDate.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(todo.isOverdue ? Theme.danger : .secondary)

                    if let project = todo.project {
                        Text("\u{00B7}")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                        Label(project.name, systemImage: project.iconName)
                            .font(.caption)
                            .foregroundStyle(project.color)
                    }
                }
            }

            Spacer()

            PriorityBadge(priority: todo.priority)
                .opacity(todo.isCompleted ? 0.7 : 1.0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { onEdit(todo) }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { onDelete(todo) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button { onEdit(todo) } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button { onToggle(todo) } label: {
                Label(
                    todo.isCompleted ? "Mark Active" : "Mark Complete",
                    systemImage: todo.isCompleted ? "arrow.uturn.backward" : "checkmark.circle"
                )
            }
            Divider()
            Button(role: .destructive) { onDelete(todo) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers

    private func moveMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}
