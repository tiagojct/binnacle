import Testing
@testable import Binnacle

struct TaskFileTests {

    // MARK: - Parsing

    @Test func parseEmptyString() {
        let tasks = TaskFile.parse("")
        #expect(tasks.count == 0)
    }

    @Test func parseSinglePendingTask() {
        let tasks = TaskFile.parse("Call Mom @phone due:2026-06-08")
        #expect(tasks.count == 1)
        #expect(tasks[0].description == "Call Mom")
        #expect(!tasks[0].done)
        #expect(tasks[0].contexts == ["phone"])
        #expect(tasks[0].keyValues["due"] == "2026-06-08")
    }

    @Test func parseCompletedTask() {
        let tasks = TaskFile.parse("x 2026-06-07 2026-06-05 Buy milk @errands")
        #expect(tasks.count == 1)
        #expect(tasks[0].done)
        #expect(tasks[0].completionDate != nil)
        #expect(tasks[0].contexts == ["errands"])
    }

    @Test func parsePriority() {
        let tasks = TaskFile.parse("(A) Important task +work")
        #expect(tasks.count == 1)
        #expect(tasks[0].priority == "A")
        #expect(tasks[0].projects == ["work"])
    }

    @Test func parseMultipleTasks() {
        let input = """
        (A) Call Mom @phone due:2026-06-08
        x 2026-06-07 2026-06-05 Buy milk @errands
        (B) Revise the paper +binnacle
        """
        let tasks = TaskFile.parse(input)
        #expect(tasks.count == 3)
        #expect(!tasks[0].done)
        #expect(tasks[1].done)
        #expect(tasks[2].priority == "B")
    }

    @Test func parseCommentLinesSkipped() {
        let input = """
        # This is a comment
        Call Mom
        # Another comment
        """
        let tasks = TaskFile.parse(input)
        #expect(tasks.count == 1)
        #expect(tasks[0].description == "Call Mom")
    }

    @Test func parseBlankLinesSkipped() {
        let tasks = TaskFile.parse("""

        Call Mom

        Buy milk

        """)
        #expect(tasks.count == 2)
    }

    @Test func parsePreservesID() {
        let tasks = TaskFile.parse("Call Mom id:abcd")
        #expect(tasks[0].id == "abcd")
    }

    @Test func parseGeneratesIDWhenMissing() {
        let tasks = TaskFile.parse("Call Mom")
        #expect(tasks[0].id.count == 4)
    }

    @Test func roundtrip() {
        let input = "(A) Call Mom @phone due:2026-06-08 +personal\nx 2026-06-07 Buy milk @errands\n"
        let tasks = TaskFile.parse(input)
        let output = TaskFile.serialize(tasks)

        let reparsed = TaskFile.parse(output)
        #expect(reparsed.count == tasks.count)
        for (original, roundtripped) in zip(tasks, reparsed) {
            #expect(original.description == roundtripped.description)
            #expect(original.done == roundtripped.done)
            #expect(original.contexts == roundtripped.contexts)
            #expect(original.projects == roundtripped.projects)
        }
    }

    @Test func parseTaskWithDescriptionOnly() {
        let tasks = TaskFile.parse("Just a simple task")
        #expect(tasks.count == 1)
        #expect(tasks[0].description == "Just a simple task")
        #expect(!tasks[0].done)
        #expect(tasks[0].priority == nil)
        #expect(tasks[0].contexts.isEmpty)
        #expect(tasks[0].projects.isEmpty)
    }

    @Test func parsePriorityB() {
        let tasks = TaskFile.parse("(B) Medium priority task")
        #expect(tasks[0].priority == "B")
    }

    @Test func parsePriorityZ() {
        let tasks = TaskFile.parse("(Z) Lowest priority")
        #expect(tasks[0].priority == "Z")
    }

    @Test func completedTaskHasDoneKV() {
        let input = "x 2026-06-07 Something I finished"
        let tasks = TaskFile.parse(input)
        let serialized = TaskFile.serialize(tasks)
        #expect(serialized.contains("done:"))
    }

    // MARK: - Serialization

    @Test func serializeMinimalTask() {
        let task = Task.make(description: "Hello", id: "test")
        let result = TaskFile.serialize([task])
        #expect(result.contains("Hello"))
        #expect(result.contains("id:test"))
    }

    @Test func serializeTaskWithAllFields() {
        let task = Task(
            id: "abcd",
            description: "Complex task",
            done: false,
            completionDate: nil,
            creationDate: nil,
            priority: "A",
            contexts: ["phone"],
            projects: ["work"],
            keyValues: ["due": "2026-12-31"]
        )
        let result = TaskFile.serialize([task])
        #expect(result.contains("(A)"))
        #expect(result.contains("Complex task"))
        #expect(result.contains("@phone"))
        #expect(result.contains("+work"))
        #expect(result.contains("due:2026-12-31"))
        #expect(result.contains("id:abcd"))
    }
}
