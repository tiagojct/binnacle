import SwiftUI

struct TaskListView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if state.pendingTasks.isEmpty && state.completedTasks.isEmpty {
                        EmptyStateView()
                    } else {
                        pendingSection
                        if !state.completedTasks.isEmpty {
                            completedDivider
                            completedSection
                        }
                    }
                }
            }
            .background(
                PequodTheme.background(theme: state.theme, colorScheme: colorScheme)
            )
            .onChange(of: state.selectedTaskID) { _, newID in
                if let id = newID {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var pendingSection: some View {
        ForEach(state.pendingTasks) { task in
            TaskRow(
                task: task,
                isSelected: state.selectedTaskID == task.id,
                onToggle: { state.toggleTask(task.id) },
                onSelect: { state.selectedTaskID = task.id },
                onEdit: { newText in
                    updateTask(task, description: newText)
                }
            )
            .id(task.id)
        }
    }

    private var completedDivider: some View {
        HStack {
            Rectangle()
                .fill(PequodTheme.amber.opacity(0.08))
                .frame(height: 1)
            Text("Completed")
                .font(PequodTheme.metadataFont())
                .foregroundColor(PequodTheme.amber.opacity(0.25))
            Rectangle()
                .fill(PequodTheme.amber.opacity(0.08))
                .frame(height: 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var completedSection: some View {
        ForEach(state.completedTasks) { task in
            TaskRow(
                task: task,
                isSelected: state.selectedTaskID == task.id,
                onToggle: { state.toggleTask(task.id) },
                onSelect: { state.selectedTaskID = task.id },
                onEdit: { _ in }
            )
            .id(task.id)
        }
    }

    // MARK: - Helpers

    private func updateTask(_ task: Task, description: String) {
        guard let index = state.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        state.tasks[index].description = description
        state.scheduleAutoSave()
    }
}
