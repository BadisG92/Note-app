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

        var id: String {
            switch self {
            case .add(let token): return "add-\(token)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if projects.isEmpty {
                    emptyState
                        .transition(.opacity)
                } else {
                    projectList
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.25), value: projects.isEmpty)
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { guard activeSheet == nil else { return }; activeSheet = .add }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel("New project")
                    .accessibilityHint("Opens form to create a new project")
                }
            }
            .sheet(item: $activeSheet) { state in
                switch state {
                case .add:
                    ProjectFormView()
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
            Label("No Projects", systemImage: "folder.fill")
        } description: {
            Text("Projects group related tasks together. Create a project, then assign tasks to it when creating or editing a task.")
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
                NavigationLink {
                    ProjectDetailView(project: project)
                } label: {
                    projectRowLabel(project)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        projectToDelete = project
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        projectToDelete = project
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .accessibilityAction(named: "Delete") {
                    projectToDelete = project
                    showDeleteConfirmation = true
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

    private func projectRowLabel(_ project: Project) -> some View {
        HStack(spacing: 12) {
            Image(systemName: project.iconName)
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(project.color)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
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
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(projectAccessibilityLabel(project))
    }

    private func projectAccessibilityLabel(_ project: Project) -> String {
        var label = "\(project.name), \(taskSummary(for: project))"
        if project.totalTodoCount > 0 {
            label += ", \(Int(project.completionProgress * 100)) percent complete"
        }
        return label
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
        withAnimation(.snappy(duration: 0.25)) { modelContext.delete(project) }
        try? modelContext.save()
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    let color: Color

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 3)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.snappy(duration: 0.4)) {
                animatedProgress = newValue
            }
        }
    }
}
