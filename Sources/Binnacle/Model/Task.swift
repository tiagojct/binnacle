import Foundation

struct Task: Identifiable, Equatable, Sendable {
    let id: String
    var description: String
    var done: Bool
    var completionDate: Date?
    var creationDate: Date?
    var priority: Character?
    var contexts: [String]
    var projects: [String]
    var keyValues: [String: String]

    static func generateID() -> String {
        let chars = Array("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return String((0..<4).map { _ in chars.randomElement()! })
    }

    static func make(
        description: String = "",
        done: Bool = false,
        priority: Character? = nil,
        contexts: [String] = [],
        projects: [String] = [],
        keyValues: [String: String] = [:],
        id: String? = nil
    ) -> Task {
        Task(
            id: id ?? generateID(),
            description: description,
            done: done,
            completionDate: done ? Date() : nil,
            creationDate: nil,
            priority: priority,
            contexts: contexts.sorted(),
            projects: projects.sorted(),
            keyValues: keyValues
        )
    }
}
