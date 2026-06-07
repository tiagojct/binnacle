import SwiftUI
import Foundation

@MainActor
@Observable
final class AppState {
    var tasks: [Task] = []
    var fileURL: URL?
    var selectedTaskID: String?
    var isFocusMode: Bool = false
    var columnWidth: ColumnWidth = .normal
    var theme: Theme = .system
    var isPaletteOpen: Bool = false
    var errorMessage: String?
    var fileWatcher: FileWatcher?

    private var autoSaveTask: Swift.Task<Void, Never>?

    // MARK: - Enums

    enum ColumnWidth: String, CaseIterable {
        case narrow  // 480
        case normal  // 640
        case wide    // 800

        var points: CGFloat {
            switch self {
            case .narrow: 480
            case .normal: 640
            case .wide:   800
            }
        }

        func next() -> ColumnWidth {
            switch self {
            case .narrow: .normal
            case .normal: .wide
            case .wide:   .narrow
            }
        }
    }

    enum Theme: String, CaseIterable {
        case system
        case navy
        case parchment

        func next() -> Theme {
            switch self {
            case .system:    .navy
            case .navy:      .parchment
            case .parchment: .system
            }
        }
    }

    // MARK: - Init

    init() {
        if let raw = UserDefaults.standard.string(forKey: "binnacle_theme"),
           let saved = Theme(rawValue: raw) {
            theme = saved
        }
    }

    // MARK: - File Operations

    func load(from url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        tasks = TaskFile.parse(content)
        fileURL = url

        // Persist for crash recovery
        UserDefaults.standard.set(url.path, forKey: "binnacle_lastFilePath")

        // Wire file watcher
        fileWatcher?.stop()
        fileWatcher = FileWatcher(fileURL: url)
        fileWatcher?.onFileChanged = { [weak self] in
            Swift.Task { @MainActor in
                try? self?.reload()
            }
        }

        if !tasks.isEmpty {
            selectedTaskID = tasks.first(where: { !$0.done })?.id ?? tasks.first?.id
        }
    }

    func save() throws {
        guard let url = fileURL else { return }
        let content = TaskFile.serialize(tasks)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func reload() throws {
        guard let url = fileURL else { return }
        try load(from: url)
    }

    // MARK: - Derived data

    var pendingTasks: [Task] {
        tasks.filter { !$0.done }
    }

    var completedTasks: [Task] {
        tasks.filter { $0.done }
    }

    var selectedTask: Task? {
        guard let id = selectedTaskID else { return nil }
        return tasks.first { $0.id == id }
    }

    // MARK: - Task Actions

    func addNewTask() {
        let task = Task.make()
        tasks.insert(task, at: 0)
        selectedTaskID = task.id
        scheduleAutoSave()
    }

    func toggleSelectedTask() {
        guard let id = selectedTaskID,
              let index = tasks.firstIndex(where: { $0.id == id }) else { return }

        tasks[index].done.toggle()

        if tasks[index].done {
            tasks[index].completionDate = Date()
            tasks[index].keyValues["done"] = dateString(from: Date())
            let task = tasks.remove(at: index)
            tasks.append(task)
        } else {
            tasks[index].completionDate = nil
            tasks[index].keyValues.removeValue(forKey: "done")
            let task = tasks.remove(at: index)
            tasks.insert(task, at: 0)
        }
        scheduleAutoSave()
    }

    func toggleTask(_ id: String) {
        selectedTaskID = id
        toggleSelectedTask()
    }

    func deleteSelectedTask() {
        guard let id = selectedTaskID,
              let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks.remove(at: index)

        if tasks.isEmpty {
            selectedTaskID = nil
        } else if index < tasks.count {
            selectedTaskID = tasks[index].id
        } else {
            selectedTaskID = tasks[tasks.count - 1].id
        }
        scheduleAutoSave()
    }

    func moveSelectedTaskUp() {
        guard let id = selectedTaskID,
              let index = tasks.firstIndex(where: { $0.id == id }),
              index > 0 else { return }
        tasks.swapAt(index, index - 1)
        scheduleAutoSave()
    }

    func moveSelectedTaskDown() {
        guard let id = selectedTaskID,
              let index = tasks.firstIndex(where: { $0.id == id }),
              index < tasks.count - 1 else { return }
        tasks.swapAt(index, index + 1)
        scheduleAutoSave()
    }

    func cycleColumnWidth() {
        columnWidth = columnWidth.next()
    }

    func cycleTheme() {
        theme = theme.next()
        UserDefaults.standard.set(theme.rawValue, forKey: "binnacle_theme")
    }

    // MARK: - Auto-save

    func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Swift.Task {
            try? await Swift.Task.sleep(for: .seconds(2))
            guard !Swift.Task.isCancelled else { return }
            do {
                try save()
            } catch {
                await MainActor.run {
                    self.errorMessage = "Save failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Focus navigation

    func focusNext() {
        guard let current = selectedTaskID,
              let idx = pendingTasks.firstIndex(where: { $0.id == current }),
              idx + 1 < pendingTasks.count else { return }
        selectedTaskID = pendingTasks[idx + 1].id
    }

    func focusPrevious() {
        guard let current = selectedTaskID,
              let idx = pendingTasks.firstIndex(where: { $0.id == current }),
              idx > 0 else { return }
        selectedTaskID = pendingTasks[idx - 1].id
    }

    func focusCompleteAndAdvance() {
        guard let current = selectedTaskID else { return }
        toggleTask(current)
        if !pendingTasks.isEmpty {
            selectedTaskID = pendingTasks.first?.id
        }
    }

    // MARK: - Helpers

    private func dateString(from date: Date) -> String {
        dateFormatter.string(from: date)
    }
}

private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()
