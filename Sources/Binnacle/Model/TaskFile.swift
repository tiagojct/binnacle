import Foundation

// MARK: - Date helpers

private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()

private var datePattern: Regex<Substring> {
    try! Regex("^\\d{4}-\\d{2}-\\d{2}")
}

private func extractDate(from text: String) -> (date: Date, remaining: String)? {
    guard let match = text.firstMatch(of: datePattern) else { return nil }
    let dateStr = String(match.output)
    guard let date = dateFormatter.date(from: dateStr) else { return nil }
    let remaining = text[match.range.upperBound...]
        .trimmingCharacters(in: .whitespaces)
    return (date, remaining)
}

// MARK: - Priority helpers

private var priorityPattern: Regex<(Substring, Substring)> {
    try! Regex("^\\(([A-Z])\\)\\s")
}

private func extractPriority(from text: String) -> (priority: Character, remaining: String)? {
    guard let match = text.firstMatch(of: priorityPattern) else { return nil }
    let char = match.output.1.first!
    let remaining = text[match.range.upperBound...]
    return (char, String(remaining))
}

// MARK: - Metadata extraction

private func extractMetadata(from text: String) -> (
    description: String,
    contexts: [String],
    projects: [String],
    keyValues: [String: String]
) {
    var contexts: [String] = []
    var projects: [String] = []
    var keyValues: [String: String] = [:]
    var descriptionWords: [String] = []

    let words = text.split(separator: " ", omittingEmptySubsequences: false)

    for word in words {
        let w = String(word)
        if w.hasPrefix("@"), w.count > 1 {
            contexts.append(String(w.dropFirst()))
        } else if w.hasPrefix("+"), w.count > 1 {
            projects.append(String(w.dropFirst()))
        } else if w.contains(":"), !w.hasPrefix("http"), !w.hasPrefix("https") {
            let parts = w.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                keyValues[String(parts[0])] = String(parts[1])
            } else {
                descriptionWords.append(w)
            }
        } else {
            descriptionWords.append(w)
        }
    }

    return (
        description: descriptionWords.joined(separator: " "),
        contexts: contexts.sorted(),
        projects: projects.sorted(),
        keyValues: keyValues
    )
}

// MARK: - TaskFile

enum TaskFile {

    /// Parse a todo.txt string into an array of Tasks.
    static func parse(_ content: String) -> [Task] {
        var tasks: [Task] = []

        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = String(line).trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("#") { continue }

            var remaining = trimmed
            var done = false
            var completionDate: Date?
            var priority: Character?
            var creationDate: Date?

            // Step 1: Completion marker
            if remaining.hasPrefix("x ") {
                done = true
                remaining = String(remaining.dropFirst(2))

                // Step 2: Completion date
                if let result = extractDate(from: remaining) {
                    completionDate = result.date
                    remaining = result.remaining
                }
            }

            // Step 3: Priority
            if let result = extractPriority(from: remaining) {
                priority = result.priority
                remaining = result.remaining
            }

            // Step 4: Creation date (only for non-completed tasks)
            if !done {
                if let result = extractDate(from: remaining) {
                    creationDate = result.date
                    remaining = result.remaining
                }
            }

            // Step 5: Metadata
            let (description, contexts, projects, keyValues) = extractMetadata(from: remaining)

            let id = keyValues["id"] ?? Task.generateID()

            let task = Task(
                id: id,
                description: description.trimmingCharacters(in: .whitespaces),
                done: done,
                completionDate: completionDate,
                creationDate: creationDate,
                priority: priority,
                contexts: contexts,
                projects: projects,
                keyValues: keyValues
            )
            tasks.append(task)
        }

        return tasks
    }

    /// Serialise an array of Tasks back to a todo.txt string.
    static func serialize(_ tasks: [Task]) -> String {
        var lines: [String] = []
        for task in tasks {
            lines.append(serializeTask(task))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func serializeTask(_ task: Task) -> String {
        var parts: [String] = []

        // Completion marker + date
        if task.done {
            parts.append("x")
            if let cd = task.completionDate {
                parts.append(dateFormatter.string(from: cd))
            }
        }

        // Priority (only for incomplete tasks)
        if let p = task.priority, !task.done {
            parts.append("(\(p))")
        }

        // Creation date (only for incomplete tasks)
        if let crd = task.creationDate, !task.done {
            parts.append(dateFormatter.string(from: crd))
        }

        // Description
        if !task.description.isEmpty {
            parts.append(task.description)
        }

        // Contexts
        for ctx in task.contexts.sorted() {
            parts.append("@\(ctx)")
        }

        // Projects
        for proj in task.projects.sorted() {
            parts.append("+\(proj)")
        }

        // Key:value (excluding id — it's always last)
        let sortedKeys = task.keyValues.keys.sorted().filter { $0 != "id" }
        for key in sortedKeys {
            guard let value = task.keyValues[key] else { continue }
            parts.append("\(key):\(value)")
        }

        // id always last
        parts.append("id:\(task.id)")

        return parts.joined(separator: " ")
    }
}
