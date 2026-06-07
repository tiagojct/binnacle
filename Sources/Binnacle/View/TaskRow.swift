import SwiftUI

struct TaskRow: View {
    let task: Task
    let isSelected: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void
    let onEdit: (String) -> Void

    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var colorScheme
    @State private var isEditing = false
    @State private var editText = ""

    private var fg: Color {
        PequodTheme.foreground(theme: state.theme, colorScheme: colorScheme)
    }

    var body: some View {
        HStack(spacing: 8) {
            checkbox
            taskText
            Spacer()
            metadataText
        }
        .padding(.vertical, PequodTheme.rowPadding)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? PequodTheme.amber.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            startEditing()
        }
        .onTapGesture(count: 1) {
            onSelect()
        }
    }

    // MARK: - Checkbox

    private var checkbox: some View {
        Button(action: onToggle) {
            RoundedRectangle(cornerRadius: 3)
                .stroke(PequodTheme.amber, lineWidth: PequodTheme.checkboxStroke)
                .frame(width: PequodTheme.checkboxSize, height: PequodTheme.checkboxSize)
                .overlay {
                    if task.done {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(PequodTheme.amber.opacity(0.3))
                            .frame(width: PequodTheme.checkboxSize, height: PequodTheme.checkboxSize)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Task text

    @ViewBuilder
    private var taskText: some View {
        if isEditing {
            TextField("", text: $editText)
                .textFieldStyle(.plain)
                .font(PequodTheme.taskFont())
                .foregroundColor(fg)
                .onSubmit {
                    onEdit(editText)
                    isEditing = false
                }
                .onKeyPress(.escape) {
                    isEditing = false
                    return .handled
                }
        } else {
            Text(task.description.isEmpty ? "New task" : task.description)
                .font(PequodTheme.taskFont())
                .foregroundColor(
                    task.done
                        ? PequodTheme.completedForeground(theme: state.theme)
                        : (task.description.isEmpty ? PequodTheme.amber.opacity(0.3) : fg)
                )
                .strikethrough(task.done, color: PequodTheme.completedForeground(theme: state.theme))
                .lineLimit(1)
        }
    }

    // MARK: - Metadata

    @ViewBuilder
    private var metadataText: some View {
        HStack(spacing: 6) {
            if let priority = task.priority {
                Text("(\(String(priority)))")
                    .font(PequodTheme.metadataFont())
                    .foregroundColor(PequodTheme.amber)
            }
            if let due = task.keyValues["due"] {
                Text(due)
                    .font(PequodTheme.metadataFont())
                    .foregroundColor(PequodTheme.mutedForeground(theme: state.theme, colorScheme: colorScheme))
            }
            ForEach(task.contexts, id: \.self) { ctx in
                Text("@\(ctx)")
                    .font(PequodTheme.metadataFont())
                    .foregroundColor(PequodTheme.mutedForeground(theme: state.theme, colorScheme: colorScheme))
            }
            ForEach(task.projects, id: \.self) { proj in
                Text("+\(proj)")
                    .font(PequodTheme.metadataFont())
                    .foregroundColor(PequodTheme.mutedForeground(theme: state.theme, colorScheme: colorScheme))
            }
        }
    }

    // MARK: - Editing

    private func startEditing() {
        editText = task.description
        isEditing = true
    }
}
