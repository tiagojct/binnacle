import SwiftUI

struct PaletteView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText: String = ""
    @FocusState private var isFocused: Bool

    private var results: [PaletteResult] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        if query.isEmpty { return [] }

        var items: [PaletteResult] = []

        // Match tasks by description, context, project
        for task in state.tasks {
            let matches = task.description.lowercased().contains(query) ||
                task.contexts.contains(where: { $0.lowercased().contains(query) }) ||
                task.projects.contains(where: { $0.lowercased().contains(query) }) ||
                (task.priority.map { String($0).lowercased() }?.contains(query) ?? false)

            if matches {
                items.append(.task(task))
            }
        }

        return items
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(PequodTheme.amber.opacity(0.4))
                TextField("Search tasks, projects, contexts...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(PequodTheme.taskFont(size: 14))
                    .foregroundColor(PequodTheme.cream)
                    .focused($isFocused)
                    .onAppear {
                        isFocused = true
                        searchText = ""
                    }
                    .onSubmit {
                        selectFirst()
                    }
            }
            .padding(12)
            .background(PequodTheme.amber.opacity(0.05))

            Divider()
                .overlay(PequodTheme.amber.opacity(0.1))

            // Results
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    ForEach(Array(results.enumerated()), id: \.offset) { idx, result in
                        paletteRow(result, isSelected: idx == selectedResultIndex)
                            .onTapGesture {
                                selectResult(result)
                            }
                    }

                    if results.isEmpty && !searchText.isEmpty {
                        Text("No matches.")
                            .font(PequodTheme.metadataFont())
                            .foregroundColor(PequodTheme.amber.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                    }
                }
            }
        }
        .frame(width: 420, height: 320)
        .background(PequodTheme.navy)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.6), radius: 24, x: 0, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(PequodTheme.amber.opacity(0.1), lineWidth: 1)
        )
        .onKeyPress(.escape) {
            state.isPaletteOpen = false
            return .handled
        }
        .onKeyPress(.downArrow) {
            selectNext()
            return .handled
        }
        .onKeyPress(.upArrow) {
            selectPrevious()
            return .handled
        }
        .onKeyPress(.return) {
            selectFirst()
            return .handled
        }
    }

    // MARK: - Selection

    @State private var selectedResultIndex: Int = 0

    private func selectResult(_ result: PaletteResult) {
        state.selectedTaskID = result.taskID
        state.isPaletteOpen = false
        if state.isFocusMode {
            // Ensure we're looking at a pending task in focus mode
            if let task = state.selectedTask, task.done {
                state.isFocusMode = false
            }
        }
    }

    private func selectFirst() {
        guard !results.isEmpty else { return }
        selectResult(results[0])
    }

    private func selectNext() {
        guard !results.isEmpty else { return }
        let next = min(selectedResultIndex + 1, results.count - 1)
        selectedResultIndex = next
    }

    private func selectPrevious() {
        guard !results.isEmpty else { return }
        let prev = max(selectedResultIndex - 1, 0)
        selectedResultIndex = prev
    }

    // MARK: - Row

    @ViewBuilder
    private func paletteRow(_ result: PaletteResult, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            // Indicator icon
            Group {
                if result.isDone {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 11))
                        .foregroundColor(PequodTheme.amber.opacity(0.3))
                } else if result.priority != nil {
                    Text("(\(String(result.priority!)))")
                        .font(PequodTheme.metadataFont())
                        .foregroundColor(PequodTheme.amber)
                } else {
                    Circle()
                        .stroke(PequodTheme.amber.opacity(0.2), lineWidth: 1)
                        .frame(width: 11, height: 11)
                }
            }

            // Description
            Text(result.displayText)
                .font(PequodTheme.taskFont())
                .foregroundColor(
                    isSelected
                        ? PequodTheme.cream
                        : (result.isDone
                            ? PequodTheme.amber.opacity(0.35)
                            : PequodTheme.cream.opacity(0.7))
                )
                .strikethrough(result.isDone, color: PequodTheme.amber.opacity(0.3))
                .lineLimit(1)

            Spacer()

            // Project badge
            if let project = result.projects.first {
                Text("+\(project)")
                    .font(PequodTheme.metadataFont())
                    .foregroundColor(PequodTheme.amber.opacity(0.3))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? PequodTheme.amber.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Palette Result

private struct PaletteResult {
    let taskID: String
    let displayText: String
    let isDone: Bool
    let priority: Character?
    let projects: [String]

    static func task(_ task: Task) -> PaletteResult {
        PaletteResult(
            taskID: task.id,
            displayText: task.description.isEmpty ? "(empty)" : task.description,
            isDone: task.done,
            priority: task.priority,
            projects: task.projects
        )
    }
}
