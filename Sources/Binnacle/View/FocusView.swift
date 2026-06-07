import SwiftUI

struct FocusView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            PequodTheme.navy
                .ignoresSafeArea()

            if let task = state.selectedTask, !task.done {
                VStack(spacing: 20) {
                    Spacer()

                    // Priority badge
                    if let priority = task.priority {
                        Text("(\(String(priority)))")
                            .font(PequodTheme.taskFont(size: 14))
                            .foregroundColor(PequodTheme.amber)
                            .padding(.bottom, -8)
                    }

                    // Task description — large, centred, cream
                    Text(task.description.isEmpty ? "New task" : task.description)
                        .font(PequodTheme.focusFont())
                        .foregroundColor(PequodTheme.cream)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 500)
                        .padding(.horizontal, 40)

                    // Metadata row
                    metadataRow(task)

                    Spacer()

                    // Counter + hint
                    VStack(spacing: 6) {
                        if let idx = focusIndex {
                            Text("\(idx + 1) of \(state.pendingTasks.count)")
                                .font(PequodTheme.metadataFont())
                                .foregroundColor(PequodTheme.amber.opacity(0.3))
                        }
                        Text("\u{2318}\u{21A9} complete  \u{2318}\u{2193} next  \u{2318}\u{2191} previous  Esc exit")
                            .font(PequodTheme.metadataFont())
                            .foregroundColor(PequodTheme.amber.opacity(0.15))
                    }
                    .padding(.bottom, 40)
                }
            } else {
                // No pending task selected — show next pending or "all done"
                VStack(spacing: 16) {
                    Spacer()

                    if state.pendingTasks.isEmpty {
                        Text("All tasks completed.")
                            .font(PequodTheme.taskFont(size: 16))
                            .foregroundColor(PequodTheme.amber.opacity(0.4))
                    } else {
                        Text("Select a task to focus.")
                            .font(PequodTheme.taskFont(size: 16))
                            .foregroundColor(PequodTheme.amber.opacity(0.4))
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - Metadata

    private func metadataRow(_ task: Task) -> some View {
        HStack(spacing: 12) {
            ForEach(task.contexts, id: \.self) { ctx in
                Text("@\(ctx)")
                    .font(PequodTheme.metadataFont())
                    .foregroundColor(PequodTheme.amber.opacity(0.45))
            }
            ForEach(task.projects, id: \.self) { proj in
                Text("+\(proj)")
                    .font(PequodTheme.metadataFont())
                    .foregroundColor(PequodTheme.amber.opacity(0.45))
            }
            if let due = task.keyValues["due"] {
                Text("due:\(due)")
                    .font(PequodTheme.metadataFont())
                    .foregroundColor(PequodTheme.amber.opacity(0.5))
            }
        }
    }

    private var focusIndex: Int? {
        guard let task = state.selectedTask, !task.done else { return nil }
        return state.pendingTasks.firstIndex { $0.id == task.id }
    }
}
