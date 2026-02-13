import SwiftUI
import SwiftData

struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.name) private var projects: [Project]

    @State private var activeSheet: SheetState?
    @State private var projectToDelete: Project?
    @State private var showDeleteConfirmation = false

    enum SheetState: Identifiable {
        case add(UUID = UUID())
        case edit(Project, UUID = UUID())

        var id: String {
            switch self {
            case .add(let token): return "add-\(token)"
            case .edit(_, let token): return "edit-\(token)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if projects.isEmpty {
                    emptyState
                } else {
                    projectList
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { guard activeSheet == nil else { return }; activeSheet = .add }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(item: $activeSheet) { state in
                switch state {
                case .add:
                    ProjectFormView()
                        .presentationDragIndicator(.visible)
                case .edit(let project, _):
                    ProjectFormView(project: project)
                        .presentationDragIndicator(.visible)
                }
            }
            .confirmationDialog(
                "Delete Project",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let project = projectToDelete {
                        performDelete(project)
                    }
                    projectToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    projectToDelete = nil
                }
            } message: {
                if let project = projectToDelete {
                    Text("Are you sure you want to delete \"\(project.name)\"? Tasks in this project will become ungrouped.")
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Projects", systemImage: "folder")
        } description: {
            Text("Create projects to organize your tasks into groups.")
        } actions: {
            Button("New Project") {
                activeSheet = .add
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var projectList: some View {
        List {
            ForEach(projects) { project in
                projectRow(project)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            projectToDelete = project
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            activeSheet = .edit(project)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
            }
            .onDelete { offsets in
                guard let first = offsets.first else { return }
                projectToDelete = projects[first]
                showDeleteConfirmation = true
            }
        }
        .listStyle(.insetGrouped)
    }

    private func projectRow(_ project: Project) -> some View {
        HStack(spacing: 12) {
            Image(systemName: project.iconName)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(project.color)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text(taskSummary(for: project))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if project.totalTodoCount > 0 {
                CircularProgressView(
                    progress: project.completionProgress,
                    color: project.color
                )
                .frame(width: 28, height: 28)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            activeSheet = .edit(project)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(project.name), \(taskSummary(for: project))")
    }

    private func taskSummary(for project: Project) -> String {
        let active = project.activeTodoCount
        let total = project.totalTodoCount
        if total == 0 {
            return "No tasks"
        }
        if active == 0 {
            return "All \(total) tasks completed"
        }
        return "\(active) active of \(total) tasks"
    }

    // MARK: - Actions

    private func performDelete(_ project: Project) {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        withAnimation { modelContext.delete(project) }
        try? modelContext.save()
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
