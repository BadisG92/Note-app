import SwiftUI
import SwiftData

struct CalendarView: View {
    let todos: [TodoItem]
    let onToggle: (TodoItem) -> Void
    let onEdit: (TodoItem) -> Void
    let onDelete: (TodoItem) -> Void
    let onAddTask: (Date) -> Void

    @State private var displayedMonth = Date()
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @GestureState private var dragOffset: CGFloat = 0

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

    private var isCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
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

        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

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
                    .gesture(swipeGesture)
                Divider()
                    .padding(.top, Theme.spacingSM)
                selectedDaySection
            }
        }
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .updating($dragOffset) { value, state, _ in
                state = value.translation.width
            }
            .onEnded { value in
                let threshold: CGFloat = 50
                if value.translation.width < -threshold {
                    withAnimation(.easeInOut(duration: Theme.animDefault)) {
                        moveMonth(by: 1)
                    }
                } else if value.translation.width > threshold {
                    withAnimation(.easeInOut(duration: Theme.animDefault)) {
                        moveMonth(by: -1)
                    }
                }
            }
    }

    // MARK: - Calendar Header

    private var calendarHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: Theme.animDefault)) {
                    moveMonth(by: -1)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
            }
            .accessibilityLabel("Previous month")

            Spacer()

            VStack(spacing: 2) {
                Text(monthTitle)
                    .font(.headline)

                if !isCurrentMonth {
                    Button {
                        withAnimation(.easeInOut(duration: Theme.animDefault)) {
                            displayedMonth = Date()
                            selectedDate = todayStart
                        }
                    } label: {
                        Text("Today")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.tint)
                    }
                }
            }
            .accessibilityElement(children: .combine)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: Theme.animDefault)) {
                    moveMonth(by: 1)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: Theme.minTouchTarget, height: Theme.minTouchTarget)
            }
            .accessibilityLabel("Next month")
        }
        .padding(.horizontal)
        .padding(.top, Theme.spacingSM)
        .padding(.bottom, Theme.spacingXS)
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(adjustedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Theme.spacingSM)
        .padding(.bottom, Theme.spacingXS)
    }

    private var adjustedWeekdaySymbols: [String] {
        let first = calendar.firstWeekday - 1
        return Array(weekdaySymbols[first...]) + Array(weekdaySymbols[..<first])
    }

    // MARK: - Calendar Grid

    private struct CalendarSlot: Identifiable {
        let id: String
        let date: Date?

        init(index: Int, date: Date?) {
            if let date = date {
                self.id = "d-\(Int(date.timeIntervalSinceReferenceDate))"
            } else {
                self.id = "blank-\(index)"
            }
            self.date = date
        }
    }

    private var calendarSlots: [CalendarSlot] {
        daysInGrid.enumerated().map { CalendarSlot(index: $0.offset, date: $0.element) }
    }

    private var calendarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

        return LazyVGrid(columns: columns, spacing: Theme.spacingXS) {
            ForEach(calendarSlots) { slot in
                if let date = slot.date {
                    dayCell(for: date)
                } else {
                    Color.clear
                        .frame(height: 48)
                }
            }
        }
        .padding(.horizontal, Theme.spacingSM)
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
        let taskCount = dayTodos.count

        return Button {
            withAnimation(.easeInOut(duration: Theme.animFast)) {
                selectedDate = startOfDate
            }
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    // Selection / Today background
                    if isSelected {
                        Circle()
                            .fill(.tint)
                            .frame(width: 34, height: 34)
                    } else if isToday {
                        Circle()
                            .strokeBorder(.tint, lineWidth: 1.5)
                            .frame(width: 34, height: 34)
                    }

                    Text("\(day)")
                        .font(.subheadline)
                        .fontWeight(isToday || isSelected ? .bold : .regular)
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                .frame(width: 34, height: 34)

                // Task count badge
                if taskCount > 0 {
                    Text("\(taskCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 14, minHeight: 14)
                        .background(
                            badgeColor(hasOverdue: hasOverdue, allCompleted: allCompleted),
                            in: Capsule()
                        )
                } else {
                    Color.clear
                        .frame(height: 14)
                }
            }
            .frame(height: 52)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayCellAccessibilityLabel(date: date, todoCount: taskCount, isToday: isToday))
    }

    private func badgeColor(hasOverdue: Bool, allCompleted: Bool) -> Color {
        if hasOverdue { return Theme.danger }
        if allCompleted { return Theme.success }
        return Theme.amber
    }

    private func dayCellAccessibilityLabel(date: Date, todoCount: Int, isToday: Bool) -> String {
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
            HStack(spacing: Theme.spacingSM) {
                Text(selectedDateTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if !selectedDayTodos.isEmpty {
                    Text("\(selectedDayTodos.count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.tint, in: Capsule())
                }

                Spacer()

                Button {
                    let timeComponents = calendar.dateComponents([.hour, .minute], from: Date())
                    let taskDate = calendar.date(bySettingHour: timeComponents.hour ?? 9,
                                                  minute: timeComponents.minute ?? 0,
                                                  second: 0, of: selectedDate) ?? selectedDate
                    onAddTask(taskDate)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                }
                .accessibilityLabel("Add task for \(selectedDateTitle)")
            }
            .padding(.horizontal)
            .padding(.top, Theme.spacingMD)
            .padding(.bottom, Theme.spacingSM)

            if selectedDayTodos.isEmpty {
                VStack(spacing: Theme.spacingSM) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.title2)
                        .foregroundStyle(Theme.stone)
                    Text("No tasks for this day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.spacingXL)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(selectedDayTodos) { todo in
                        TodoRowView(todo: todo, onToggle: {
                            onToggle(todo)
                        }, onEdit: {
                            onEdit(todo)
                        })
                        .padding(.horizontal, Theme.spacingXS)
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

                        if todo.id != selectedDayTodos.last?.id {
                            Divider()
                                .padding(.leading, Theme.minTouchTarget)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                .padding(.horizontal)
            }
        }
        .padding(.bottom, Theme.spacingLG)
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

    // MARK: - Helpers

    private func moveMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
            // Keep selectedDate in sync with displayed month
            if let firstOfNewMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: newMonth)) {
                selectedDate = firstOfNewMonth
            }
        }
    }
}
