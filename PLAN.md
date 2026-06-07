# Binnacle — Implementation Plan

> **For Basílio:** Use `subagent-driven-development` skill to implement this plan task-by-task. Each task targets 2–5 minutes of focused work.

**Goal:** Build a native macOS task manager that reads and writes todo.txt files, with Pequod theme, focus mode, and keyboard-driven interaction.

**Architecture:** SwiftUI for views, AppKit bridge for keyboard events and file watching, `@Observable` AppState as the single source of truth, `TaskFile` for parsing/serialising todo.txt. No CoreData. No CloudKit. No WebView.

**Tech Stack:** Swift 6.3, SwiftUI, AppKit (NSEvent, NSFilePresenter, NSOpenPanel), JetBrains Mono (bundled).

**Reference Specs:** [SPEC.md](SPEC.md) (todo.txt format), [REQUIREMENTS.md](REQUIREMENTS.md) (functional + non-functional)

---

## Pre-Flight

### Task 0: Install Xcode and verify toolchain

**Objective:** Ensure the full Xcode toolchain is available.

**Commands:**

```sh
# Check if Xcode is installed
ls /Applications/Xcode.app/Contents/Developer

# If not: install from App Store or https://developer.apple.com/download/all/
# After install:
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
# Expected: Xcode 26.x, Build version ...

swift --version
# Expected: Swift 6.3.x, Target: arm64-apple-macosx26.0
```

**Verification:** `xcodebuild -version` prints version; `swift --version` prints Swift 6.

---

## Phase 1: Project Scaffold

### Task 1.1: Create Xcode project

**Objective:** Create the Binnacle Xcode project with SwiftUI lifecycle.

**Steps:**

1. Open Xcode → File → New → Project → macOS → App
2. Name: `Binnacle`
3. Interface: SwiftUI, Language: Swift, Lifecycle: SwiftUI App
4. Team: None (unsigned)
5. Save to `~/github/binnacle/`

**Files created:**
- `Binnacle.xcodeproj/`
- `Binnacle/BinnacleApp.swift` — `@main App`
- `Binnacle/ContentView.swift` — placeholder view
- `Binnacle/Assets.xcassets` — app icon placeholder

**Verification:** Project builds with ⌘B. Empty window appears on ⌘R.

### Task 1.2: Setup directory structure

**Objective:** Create the source directory tree.

**Commands:**

```sh
cd ~/github/binnacle/Binnacle
mkdir -p Model View Theme/Fonts Util
```

**Expected layout after this task:**

```
Binnacle/
├── BinnacleApp.swift
├── ContentView.swift
├── Assets.xcassets/
├── Model/          # (empty)
├── View/           # (empty)
├── Theme/          # (empty)
│   └── Fonts/      # (empty)
└── Util/           # (empty)
```

### Task 1.3: Add JetBrains Mono font

**Objective:** Download and bundle JetBrains Mono (Regular, Bold) into the app.

**Steps:**

```sh
cd ~/github/binnacle/Binnacle/Theme/Fonts
curl -L -o JetBrainsMono-Regular.ttf \
  "https://github.com/JetBrains/JetBrainsMono/raw/master/fonts/ttf/JetBrainsMono-Regular.ttf"
curl -L -o JetBrainsMono-Bold.ttf \
  "https://github.com/JetBrains/JetBrainsMono/raw/master/fonts/ttf/JetBrainsMono-Bold.ttf"
```

In Xcode:
1. Drag `Fonts/` folder into project navigator (under `Binnacle` group)
2. Check "Copy items if needed"
3. Add to target: `Binnacle`

In `Info.plist`, add:

```xml
<key>ATSApplicationFontsPath</key>
<string>Fonts</string>
```

**Verification:** Font files appear in Xcode project navigator. Build succeeds.

### Task 1.4: Configure build settings

**Objective:** Set strict concurrency, warnings-as-errors, deployment target.

In Xcode → Project → Binnacle → Build Settings:

| Setting | Value |
|---|---|
| Swift Language Version | Swift 6 |
| Strict Concurrency Checking | Complete |
| Deployment Target | macOS 15.0 |
| Treat Warnings as Errors | Yes |

**Verification:** Build with ⌘B — zero warnings.

---

## Phase 2: Data Model

### Task 2.1: Define `Task` struct

**File:** Create `Model/Task.swift`

```swift
import Foundation

struct Task: Identifiable, Equatable, Sendable {
    let id: String              // 4-char base62, stable
    var description: String     // plain text, no @+tags
    var done: Bool
    var completionDate: Date?
    var creationDate: Date?
    var priority: Character?    // "A", "B", "C", or nil
    var contexts: [String]      // @phone, @work
    var projects: [String]      // +binnacle, +personal
    var keyValues: [String: String]  // due:2026-06-15, id:abcd
}
```

**Encode/decode not needed** — tasks are serialised via `TaskFile`, not `Codable`.

**Verification:** File compiles (`swift build` or ⌘B).

### Task 2.2: Generate task IDs

**File:** Add to `Model/Task.swift`

```swift
extension Task {
    static func generateID() -> String {
        let chars = Array("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return String((0..<4).map { _ in chars.randomElement()! })
    }
}
```

**Verification:** Call `Task.generateID()` — returns 4-char alphanumeric string. No collisions in 100k iterations.

### Task 2.3: Define `AppState` — the observable root

**File:** Create `Model/AppState.swift`

```swift
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
    var paletteText: String = ""
    var isPaletteOpen: Bool = false
    var errorMessage: String?
    
    enum ColumnWidth {
        case narrow   // 480
        case normal   // 640
        case wide     // 800
        
        var points: CGFloat {
            switch self {
            case .narrow: 480
            case .normal: 640
            case .wide:   800
            }
        }
    }
    
    enum Theme: String, CaseIterable {
        case system
        case navy      // Pequod dark
        case parchment // Pequod light
    }
}
```

**Verification:** File compiles.

### Task 2.4: Compute derived task lists

**File:** Add to `Model/AppState.swift`

```swift
extension AppState {
    /// Tasks not marked done.
    var pendingTasks: [Task] {
        tasks.filter { !$0.done }
    }
    
    /// Tasks marked done.
    var completedTasks: [Task] {
        tasks.filter { $0.done }
    }
    
    /// Distinct projects across all tasks, alphabetically sorted.
    var allProjects: [String] {
        Array(Set(tasks.flatMap { $0.projects })).sorted()
    }
    
    /// Distinct contexts across all tasks, alphabetically sorted.
    var allContexts: [String] {
        Array(Set(tasks.flatMap { $0.contexts })).sorted()
    }
    
    /// Tasks grouped by +project. Tasks with no project go under "Inbox".
    var groupedTasks: [(project: String, tasks: [Task])] {
        var groups: [String: [Task]] = [:]
        for task in tasks where !task.done {
            if let project = task.projects.first {
                groups[project, default: []].append(task)
            } else {
                groups["Inbox", default: []].append(task)
            }
        }
        return groups
            .map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
    }
}
```

**Verification:** File compiles.

---

## Phase 3: TaskFile Parser

### Task 3.1: Write the parser — completion and priority

**File:** Create `Model/TaskFile.swift`

```swift
import Foundation

struct TaskFile {
    
    /// Parse a todo.txt string into an array of Tasks.
    static func parse(_ content: String) -> [Task] {
        var tasks: [Task] = []
        
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip blank lines
            if trimmed.isEmpty { continue }
            
            // Skip comments
            if trimmed.hasPrefix("#") { continue }
            
            var remaining = trimmed
            var done = false
            var completionDate: Date? = nil
            var priority: Character? = nil
            var creationDate: Date? = nil
            
            // Step 1: Completion marker
            if remaining.hasPrefix("x ") {
                done = true
                remaining = String(remaining.dropFirst(2))
                
                // Step 2: Completion date
                if let date = extractDate(from: remaining) {
                    completionDate = date
                    remaining = stripDate(from: remaining)
                }
            }
            
            // Step 3: Priority
            if let prio = extractPriority(from: remaining) {
                priority = prio
                remaining = stripPriority(from: remaining)
            }
            
            // Step 4: Creation date (only for non-completed tasks, or after priority on completed)
            if !done, let date = extractDate(from: remaining) {
                creationDate = date
                remaining = stripDate(from: remaining)
            }
            
            // Step 5: Extract description, contexts, projects, key:values
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
}
```

**Helper functions** (same file):

```swift
// MARK: - Date helpers

private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone(secondsFromGMT: 0)
    return f
}()

private func extractDate(from text: String) -> Date? {
    let pattern = /^\d{4}-\d{2}-\d{2}/
    guard let match = text.firstMatch(of: pattern) else { return nil }
    let dateStr = String(match.output)
    return dateFormatter.date(from: dateStr)
}

private func stripDate(from text: String) -> String {
    return text.replacing(/^\d{4}-\d{2}-\d{2}\s*/, with: "")
}

// MARK: - Priority helpers

private func extractPriority(from text: String) -> Character? {
    let pattern = /^\(([A-Z])\)\s/
    guard let match = text.firstMatch(of: pattern) else { return nil }
    return match.output.1.first
}

private func stripPriority(from text: String) -> String {
    return text.replacing(/^\([A-Z]\)\s*/, with: "")
}

// MARK: - Metadata extraction

private func extractMetadata(from text: String) -> (description: String, contexts: [String], projects: [String], keyValues: [String: String]) {
    var contexts: [String] = []
    var projects: [String] = []
    var keyValues: [String: String] = [:]
    var descriptionParts: [String] = []
    
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
                continue
            }
            descriptionParts.append(w)
        } else {
            descriptionParts.append(w)
        }
    }
    
    return (
        description: descriptionParts.joined(separator: " "),
        contexts: contexts.sorted(),
        projects: projects.sorted(),
        keyValues: keyValues
    )
}
```

**Verification:** File compiles.

### Task 3.2: Write the serializer

**File:** Add to `Model/TaskFile.swift`

```swift
// MARK: - Serialisation

extension TaskFile {
    
    /// Serialise an array of Tasks back to a todo.txt string.
    static func serialize(_ tasks: [Task]) -> String {
        return tasks.map { serializeTask($0) }.joined(separator: "\n") + "\n"
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
        
        // Priority
        if let p = task.priority, !task.done {
            parts.append("(\(p))")
        }
        
        // Creation date
        if let crd = task.creationDate, !task.done {
            parts.append(dateFormatter.string(from: crd))
        }
        
        // Description
        parts.append(task.description)
        
        // Contexts
        for ctx in task.contexts.sorted() {
            parts.append("@\(ctx)")
        }
        
        // Projects
        for proj in task.projects.sorted() {
            parts.append("+\(proj)")
        }
        
        // Key:value (excluding id if we want it auto-generated)
        let sortedKeys = task.keyValues.keys.sorted()
        for key in sortedKeys {
            if key == "id" { continue }  // id is generated
            guard let value = task.keyValues[key] else { continue }
            parts.append("\(key):\(value)")
        }
        
        // id always last
        parts.append("id:\(task.id)")
        
        return parts.joined(separator: " ")
    }
}
```

**Verification:** File compiles.

### Task 3.3: Write unit tests for parser

**File:** Create a test target in Xcode (or test file at `Tests/TaskFileTests.swift`).

**If using Xcode test target:**

1. File → New → Target → macOS → Unit Testing Bundle
2. Name: `BinnacleTests`

**Test file:** `BinnacleTests/TaskFileTests.swift`

```swift
import XCTest
@testable import Binnacle

final class TaskFileTests: XCTestCase {
    
    func testParseEmptyString() {
        let tasks = TaskFile.parse("")
        XCTAssertEqual(tasks.count, 0)
    }
    
    func testParseSinglePendingTask() {
        let tasks = TaskFile.parse("Call Mom @phone due:2026-06-08")
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].description, "Call Mom")
        XCTAssertFalse(tasks[0].done)
        XCTAssertEqual(tasks[0].contexts, ["phone"])
        XCTAssertEqual(tasks[0].keyValues["due"], "2026-06-08")
    }
    
    func testParseCompletedTask() {
        let tasks = TaskFile.parse("x 2026-06-07 2026-06-05 Buy milk @errands")
        XCTAssertEqual(tasks.count, 1)
        XCTAssertTrue(tasks[0].done)
        XCTAssertEqual(tasks[0].contexts, ["errands"])
    }
    
    func testParsePriority() {
        let tasks = TaskFile.parse("(A) Important task +work")
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].priority, "A")
        XCTAssertEqual(tasks[0].projects, ["work"])
    }
    
    func testParseMultipleTasks() {
        let input = """
        (A) Call Mom @phone due:2026-06-08
        x 2026-06-07 2026-06-05 Buy milk @errands
        (B) Revise the paper +binnacle
        """
        let tasks = TaskFile.parse(input)
        XCTAssertEqual(tasks.count, 3)
        XCTAssertFalse(tasks[0].done)
        XCTAssertTrue(tasks[1].done)
        XCTAssertEqual(tasks[2].priority, "B")
    }
    
    func testParseCommentLinesSkipped() {
        let input = """
        # This is a comment
        Call Mom
        # Another comment
        """
        let tasks = TaskFile.parse(input)
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].description, "Call Mom")
    }
    
    func testParseBlankLinesSkipped() {
        let input = """

        Call Mom

        Buy milk

        """
        let tasks = TaskFile.parse(input)
        XCTAssertEqual(tasks.count, 2)
    }
    
    func testParsePreservesID() {
        let tasks = TaskFile.parse("Call Mom id:abcd")
        XCTAssertEqual(tasks[0].id, "abcd")
    }
    
    func testParseGeneratesIDWhenMissing() {
        let tasks = TaskFile.parse("Call Mom")
        XCTAssertEqual(tasks[0].id.count, 4)
    }
    
    func testRoundtrip() {
        let input = "(A) Call Mom @phone due:2026-06-08 +personal\nx 2026-06-07 Buy milk @errands\n"
        let tasks = TaskFile.parse(input)
        let output = TaskFile.serialize(tasks)
        
        // Re-parse the output and compare task count
        let reparsed = TaskFile.parse(output)
        XCTAssertEqual(reparsed.count, tasks.count)
        for (original, roundtripped) in zip(tasks, reparsed) {
            XCTAssertEqual(original.description, roundtripped.description)
            XCTAssertEqual(original.done, roundtripped.done)
            XCTAssertEqual(original.contexts, roundtripped.contexts)
            XCTAssertEqual(original.projects, roundtripped.projects)
        }
    }
    
    func testExtractAllProjects() {
        let input = """
        Task one +work
        Task two +home
        Task three +work +side
        Task four
        """
        let tasks = TaskFile.parse(input)
        let allProjects = Set(tasks.flatMap { $0.projects })
        XCTAssertEqual(allProjects, ["home", "side", "work"])
    }
}
```

**Command:**

```sh
cd ~/github/binnacle
xcodebuild test -scheme Binnacle -destination 'platform=macOS' 2>&1
```

**Expected output:** All 10 tests pass.

### Task 3.4: Add `TaskFile` read/write to `AppState`

**File:** Add to `Model/AppState.swift`

```swift
extension AppState {
    
    /// Load tasks from a file URL.
    func load(from url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        let parsed = TaskFile.parse(content)
        tasks = parsed
        fileURL = url
        
        // Persist file path for crash recovery
        UserDefaults.standard.set(url.path, forKey: "lastOpenFilePath")
    }
    
    /// Save current tasks to the file at `fileURL`.
    func save() throws {
        guard let url = fileURL else {
            throw AppError.noFileOpen
        }
        let content = TaskFile.serialize(tasks)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    /// Reload from disk (used when external change detected).
    func reload() throws {
        guard let url = fileURL else { return }
        try load(from: url)
    }
}

enum AppError: LocalizedError {
    case noFileOpen
    
    var errorDescription: String? {
        switch self {
        case .noFileOpen: "No file is currently open."
        }
    }
}
```

**Verification:** File compiles.

---

## Phase 4: Theme

### Task 4.1: Define PequodTheme

**File:** Create `Theme/PequodTheme.swift`

```swift
import SwiftUI

struct PequodTheme {
    // MARK: - Core palette
    
    static let navy       = Color(hex: "#0B1F2D")
    static let parchment  = Color(hex: "#F1E7D2")
    static let amber      = Color(hex: "#D4A882")
    static let amberLight = Color(hex: "#BD8C68")
    static let cream      = Color(hex: "#E8D5B7")
    static let ink        = Color(hex: "#1A1A1A")
    
    // MARK: - Semantic colours (dark mode)
    
    static var darkBackground: Color { navy }
    static var darkForeground: Color { cream }
    static var darkMuted: Color { amber.opacity(0.6) }
    static var darkAccent: Color { amber }
    static var darkCompleted: Color { amber.opacity(0.35) }
    static var darkStrikethrough: Color { amber.opacity(0.45) }
    
    // MARK: - Semantic colours (light mode)
    
    static var lightBackground: Color { parchment }
    static var lightForeground: Color { ink }
    static var lightMuted: Color { amberLight.opacity(0.8) }
    static var lightAccent: Color { amberLight }
    static var lightCompleted: Color { amberLight.opacity(0.4) }
    static var lightStrikethrough: Color { amberLight.opacity(0.55) }
    
    // MARK: - Typography
    
    static func taskFont(size: CGFloat = 13) -> Font {
        .custom("JetBrainsMono-Regular", size: size)
    }
    
    static func taskFontBold(size: CGFloat = 13) -> Font {
        .custom("JetBrainsMono-Bold", size: size)
    }
    
    static func metadataFont() -> Font {
        .custom("JetBrainsMono-Regular", size: 11)
    }
    
    static func focusFont() -> Font {
        .custom("JetBrainsMono-Regular", size: 18)
    }
    
    // MARK: - Dimensions
    
    static let checkboxSize: CGFloat = 16
    static let checkboxStroke: CGFloat = 1.5
    static let rowPadding: CGFloat = 6
    static let taskRowHeight: CGFloat = 28
}

// MARK: - Color hex initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

**Verification:** File compiles.

---

## Phase 5: Views

### Task 5.1: Build `TaskRow`

**File:** Create `View/TaskRow.swift`

```swift
import SwiftUI

struct TaskRow: View {
    let task: Task
    let isSelected: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void
    
    @Environment(AppState.self) private var state
    
    var body: some View {
        HStack(spacing: 8) {
            checkbox
            taskText
            Spacer()
            metadataText
        }
        .padding(.vertical, PequodTheme.rowPadding)
        .padding(.horizontal, 12)
        .background(isSelected ? PequodTheme.amber.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
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
    
    private var taskText: some View {
        Text(task.description)
            .font(PequodTheme.taskFont())
            .foregroundColor(task.done ? PequodTheme.amber.opacity(0.45) : PequodTheme.cream)
            .strikethrough(task.done, color: PequodTheme.amber.opacity(0.35))
            .lineLimit(1)
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
                    .foregroundColor(PequodTheme.amber.opacity(0.6))
            }
            ForEach(task.contexts, id: \.self) { ctx in
                Text("@\(ctx)")
                    .font(PequodTheme.metadataFont())
                    .foregroundColor(PequodTheme.amber.opacity(0.5))
            }
            ForEach(task.projects, id: \.self) { proj in
                Text("+\(proj)")
                    .font(PequodTheme.metadataFont())
                    .foregroundColor(PequodTheme.amber.opacity(0.5))
            }
        }
    }
}
```

**Verification:** File compiles. (Cannot preview without AppState wired — see next task.)

### Task 5.2: Build `TaskListView`

**File:** Create `View/TaskListView.swift`

```swift
import SwiftUI

struct TaskListView: View {
    @Environment(AppState.self) private var state
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if state.pendingTasks.isEmpty && state.completedTasks.isEmpty {
                        EmptyStateView()
                    } else {
                        pendingSection
                        if !state.completedTasks.isEmpty {
                            Divider()
                                .overlay(PequodTheme.amber.opacity(0.15))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            completedSection
                        }
                    }
                }
            }
            .background(backgroundColor)
            .onChange(of: state.selectedTaskID) { _, newID in
                if let id = newID {
                    withAnimation {
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
                onSelect: { state.selectedTaskID = task.id }
            )
            .id(task.id)
        }
    }
    
    @ViewBuilder
    private var completedSection: some View {
        ForEach(state.completedTasks) { task in
            TaskRow(
                task: task,
                isSelected: state.selectedTaskID == task.id,
                onToggle: { state.toggleTask(task.id) },
                onSelect: { state.selectedTaskID = task.id }
            )
            .id(task.id)
        }
    }
    
    // MARK: - Background
    
    private var backgroundColor: Color {
        switch state.theme {
        case .system:
            // System follows OS appearance
            Color(nsColor: .controlBackgroundColor)
        case .navy:
            PequodTheme.navy
        case .parchment:
            PequodTheme.parchment
        }
    }
}
```

**Verification:** File compiles.

### Task 5.3: Build `EmptyStateView`

**File:** Create `View/EmptyStateView.swift`

```swift
import SwiftUI

struct EmptyStateView: View {
    @Environment(AppState.self) private var state
    
    var body: some View {
        VStack(spacing: 16) {
            Text("No tasks.")
                .font(PequodTheme.taskFont(size: 16))
                .foregroundColor(PequodTheme.amber.opacity(0.4))
            Text("\u{2318}N to add one")
                .font(PequodTheme.metadataFont())
                .foregroundColor(PequodTheme.amber.opacity(0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 120)
    }
}
```

**Verification:** File compiles.

### Task 5.4: Build `FocusView`

**File:** Create `View/FocusView.swift`

```swift
import SwiftUI

struct FocusView: View {
    @Environment(AppState.self) private var state
    
    var body: some View {
        ZStack {
            PequodTheme.navy
                .ignoresSafeArea()
            
            if let task = currentTask {
                VStack(spacing: 16) {
                    Spacer()
                    
                    // Task description — large, centred
                    Text(task.description)
                        .font(PequodTheme.focusFont())
                        .foregroundColor(task.done ? PequodTheme.amber.opacity(0.5) : PequodTheme.cream)
                        .strikethrough(task.done, color: PequodTheme.amber.opacity(0.35))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 500)
                    
                    // Metadata
                    HStack(spacing: 12) {
                        if let priority = task.priority {
                            Text("(\(String(priority)))")
                                .font(PequodTheme.metadataFont())
                                .foregroundColor(PequodTheme.amber)
                        }
                        ForEach(task.contexts, id: \.self) { ctx in
                            Text("@\(ctx)")
                                .font(PequodTheme.metadataFont())
                                .foregroundColor(PequodTheme.amber.opacity(0.5))
                        }
                        ForEach(task.projects, id: \.self) { proj in
                            Text("+\(proj)")
                                .font(PequodTheme.metadataFont())
                                .foregroundColor(PequodTheme.amber.opacity(0.5))
                        }
                        if let due = task.keyValues["due"] {
                            Text(due)
                                .font(PequodTheme.metadataFont())
                                .foregroundColor(PequodTheme.amber.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                    
                    // Counter
                    if let index = pendingIndex {
                        Text("\(index + 1) of \(state.pendingTasks.count)")
                            .font(PequodTheme.metadataFont())
                            .foregroundColor(PequodTheme.amber.opacity(0.3))
                    }
                }
                .padding(40)
            } else {
                Text("No pending tasks.")
                    .font(PequodTheme.taskFont(size: 16))
                    .foregroundColor(PequodTheme.amber.opacity(0.4))
            }
        }
    }
    
    // MARK: - Current task
    
    private var currentTask: Task? {
        guard let id = state.selectedTaskID else { return nil }
        return state.tasks.first { $0.id == id }
    }
    
    private var pendingIndex: Int? {
        guard let task = currentTask, !task.done else { return nil }
        return state.pendingTasks.firstIndex { $0.id == task.id }
    }
}
```

**Verification:** File compiles.

### Task 5.5: Build `PaletteView`

**File:** Create `View/PaletteView.swift`

```swift
import SwiftUI

struct PaletteView: View {
    @Environment(AppState.self) private var state
    @State private var searchText: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
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
            }
            .padding(12)
            .background(PequodTheme.amber.opacity(0.05))
            
            // Results
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredTasks) { task in
                        PaletteRow(task: task)
                            .onTapGesture {
                                state.selectedTaskID = task.id
                                state.isPaletteOpen = false
                            }
                    }
                    
                    if filteredTasks.isEmpty && !searchText.isEmpty {
                        Text("No matches.")
                            .font(PequodTheme.metadataFont())
                            .foregroundColor(PequodTheme.amber.opacity(0.3))
                            .padding(20)
                    }
                }
            }
        }
        .frame(width: 400, height: 300)
        .background(PequodTheme.navy)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.5), radius: 20)
        .onChange(of: searchText) { _, _ in
            // Fuzzy filtering is done inline via filteredTasks
        }
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
    }
    
    // MARK: - Filtering (simple contains-based; fuzzy can be added later)
    
    private var filteredTasks: [Task] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        if query.isEmpty { return [] }
        
        return state.tasks.filter { task in
            task.description.lowercased().contains(query) ||
            task.contexts.contains(where: { $0.lowercased().contains(query) }) ||
            task.projects.contains(where: { $0.lowercased().contains(query) })
        }
    }
    
    // MARK: - Navigation
    
    private func selectNext() {
        guard let current = state.selectedTaskID,
              let idx = filteredTasks.firstIndex(where: { $0.id == current }),
              idx + 1 < filteredTasks.count else {
            if let first = filteredTasks.first {
                state.selectedTaskID = first.id
            }
            return
        }
        state.selectedTaskID = filteredTasks[idx + 1].id
    }
    
    private func selectPrevious() {
        guard let current = state.selectedTaskID,
              let idx = filteredTasks.firstIndex(where: { $0.id == current }),
              idx > 0 else { return }
        state.selectedTaskID = filteredTasks[idx - 1].id
    }
}

// MARK: - Palette Row

private struct PaletteRow: View {
    let task: Task
    @Environment(AppState.self) private var state
    
    var body: some View {
        HStack {
            Text(task.description)
                .font(PequodTheme.taskFont())
                .foregroundColor(
                    state.selectedTaskID == task.id
                        ? PequodTheme.cream
                        : PequodTheme.amber.opacity(0.6)
                )
                .lineLimit(1)
            Spacer()
            if let project = task.projects.first {
                Text("+\(project)")
                    .font(PequodTheme.metadataFont())
                    .foregroundColor(PequodTheme.amber.opacity(0.4))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            state.selectedTaskID == task.id
                ? PequodTheme.amber.opacity(0.08)
                : Color.clear
        )
        .contentShape(Rectangle())
    }
}
```

**Verification:** File compiles.

### Task 5.6: Wire `ContentView` as root layout

**File:** Replace `ContentView.swift`

```swift
import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var state
    
    var body: some View {
        ZStack {
            // Main content
            Group {
                if state.isFocusMode {
                    FocusView()
                } else {
                    TaskListView()
                }
            }
            .frame(minWidth: state.columnWidth.points, idealWidth: state.columnWidth.points)
            
            // Palette overlay
            if state.isPaletteOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        state.isPaletteOpen = false
                    }
                PaletteView()
            }
            
            // Error banner
            if let error = state.errorMessage {
                VStack {
                    Text(error)
                        .font(PequodTheme.metadataFont())
                        .foregroundColor(PequodTheme.cream)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(PequodTheme.amber.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Spacer()
                }
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(minWidth: 480, minHeight: 320)
    }
}
```

**Verification:** File compiles. App builds with ⌘B.

### Task 5.7: Update `BinnacleApp.swift` with AppState

**File:** Replace `BinnacleApp.swift`

```swift
import SwiftUI

@main
struct BinnacleApp: App {
    @State private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onAppear {
                    appDelegate.appState = appState
                    restoreLastSession()
                }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        
        Settings {
            PreferencesView()
                .environment(appState)
        }
    }
    
    private func restoreLastSession() {
        guard let path = UserDefaults.standard.string(forKey: "lastOpenFilePath"),
              FileManager.default.fileExists(atPath: path) else { return }
        let url = URL(fileURLWithPath: path)
        do {
            try appState.load(from: url)
        } catch {
            appState.errorMessage = "Could not restore last session: \(error.localizedDescription)"
        }
    }
}
```

**Note:** `AppDelegate` will be created in Phase 6 (keyboard handling). For now it's a stub.

**File:** Create `Util/AppDelegate.swift` (stub)

```swift
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var appState: AppState?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keyboard handler will be set up in Phase 6
    }
}
```

**Verification:** App builds and runs — shows empty state view (no file loaded yet).

### Task 5.8: Create stub `PreferencesView`

**File:** Create `View/PreferencesView.swift`

```swift
import SwiftUI

struct PreferencesView: View {
    @Environment(AppState.self) private var state
    
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 400, height: 250)
    }
}

private struct GeneralSettings: View {
    @Environment(AppState.self) private var state
    
    var body: some View {
        Form {
            Picker("Theme", selection: Binding(
                get: { state.theme },
                set: { state.theme = $0 }
            )) {
                Text("System").tag(AppState.Theme.system)
                Text("Navy").tag(AppState.Theme.navy)
                Text("Parchment").tag(AppState.Theme.parchment)
            }
            .pickerStyle(.segmented)
            
            Text("File location: \(state.fileURL?.path ?? "None")")
                .font(PequodTheme.metadataFont())
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
```

**Verification:** File compiles.

---

## Phase 6: Keyboard Handling + Task Actions

### Task 6.1: Implement `KeyboardHandler`

**File:** Create `Util/KeyboardHandler.swift`

```swift
import SwiftUI
import AppKit

final class KeyboardHandler {
    private weak var appState: AppState?
    private var monitor: Any?
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    func start() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event: event)
        }
    }
    
    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
    
    private func handle(event: NSEvent) -> NSEvent? {
        guard let state = appState else { return event }
        
        // Only intercept with Command modifier
        guard event.modifierFlags.contains(.command) else { return event }
        
        // Ignore if palette is open and key is not Escape
        if state.isPaletteOpen && event.keyCode != 53 {
            return event
        }
        
        let shift = event.modifierFlags.contains(.shift)
        
        switch event.keyCode {
        case 45:     // N
            if shift {
                // ⌘⇧N — new section (no-op in todo.txt flat list)
            } else {
                state.addNewTask()
                return nil
            }
        case 36:     // Return
            state.toggleSelectedTask()
            return nil
        case 2:      // D
            if shift {
                state.isFocusMode.toggle()
                return nil
            }
        case 35:     // P
            if shift {
                // ⌘⇧P — toggle focus mode
                state.isFocusMode.toggle()
                return nil
            } else {
                state.isPaletteOpen.toggle()
                return nil
            }
        case 13:     // W
            if shift {
                state.cycleColumnWidth()
                return nil
            }
        case 17:     // T
            if shift {
                state.cycleTheme()
                return nil
            }
        case 51:     // Delete / Backspace
            state.deleteSelectedTask()
            return nil
        case 126:    // Up arrow
            state.moveSelectedTaskUp()
            return nil
        case 125:    // Down arrow
            state.moveSelectedTaskDown()
            return nil
        default:
            break
        }
        
        return event
    }
}
```

**macOS key codes reference:**

| Key | Code |
|---|---|
| N | 45 |
| Return | 36 |
| D | 2 |
| P | 35 |
| W | 13 |
| T | 17 |
| Delete | 51 |
| Up arrow | 126 |
| Down arrow | 125 |
| Esc | 53 |

**Verification:** File compiles.

### Task 6.2: Wire keyboard handler into `AppDelegate`

**File:** Replace `Util/AppDelegate.swift`

```swift
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var appState: AppState?
    private var keyboardHandler: KeyboardHandler?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let appState = appState else { return }
        keyboardHandler = KeyboardHandler(appState: appState)
        keyboardHandler?.start()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        keyboardHandler?.stop()
    }
}
```

**Verification:** File compiles.

### Task 6.3: Implement task actions in `AppState`

**File:** Add to `Model/AppState.swift`

```swift
// MARK: - Task Actions

extension AppState {
    
    /// Add a new empty task, select it.
    func addNewTask() {
        let task = Task(
            id: Task.generateID(),
            description: "",
            done: false,
            contexts: [],
            projects: [],
            keyValues: [:]
        )
        tasks.insert(task, at: 0)
        selectedTaskID = task.id
        scheduleAutoSave()
    }
    
    /// Toggle done state of the currently selected task.
    func toggleSelectedTask() {
        guard let id = selectedTaskID,
              let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].done.toggle()
        
        if tasks[index].done {
            tasks[index].completionDate = Date()
            // Move to bottom
            let task = tasks.remove(at: index)
            tasks.append(task)
        } else {
            tasks[index].completionDate = nil
            // Move to top
            let task = tasks.remove(at: index)
            tasks.insert(task, at: 0)
        }
        scheduleAutoSave()
    }
    
    /// Toggle a specific task by ID.
    func toggleTask(_ id: String) {
        selectedTaskID = id
        toggleSelectedTask()
    }
    
    /// Delete the currently selected task.
    func deleteSelectedTask() {
        guard let id = selectedTaskID,
              let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks.remove(at: index)
        
        // Select next task, or previous if last
        if tasks.isEmpty {
            selectedTaskID = nil
        } else if index < tasks.count {
            selectedTaskID = tasks[index].id
        } else {
            selectedTaskID = tasks[tasks.count - 1].id
        }
        scheduleAutoSave()
    }
    
    /// Move the selected task up one position.
    func moveSelectedTaskUp() {
        guard let id = selectedTaskID,
              let index = tasks.firstIndex(where: { $0.id == id }),
              index > 0 else { return }
        tasks.swapAt(index, index - 1)
        scheduleAutoSave()
    }
    
    /// Move the selected task down one position.
    func moveSelectedTaskDown() {
        guard let id = selectedTaskID,
              let index = tasks.firstIndex(where: { $0.id == id }),
              index < tasks.count - 1 else { return }
        tasks.swapAt(index, index + 1)
        scheduleAutoSave()
    }
    
    /// Cycle column width: normal → wide → narrow → normal
    func cycleColumnWidth() {
        switch columnWidth {
        case .normal: columnWidth = .wide
        case .wide:   columnWidth = .narrow
        case .narrow: columnWidth = .normal
        }
    }
    
    /// Cycle theme: system → navy → parchment → system
    func cycleTheme() {
        switch theme {
        case .system:    theme = .navy
        case .navy:      theme = .parchment
        case .parchment: theme = .system
        }
    }
}
```

**Verification:** File compiles.

### Task 6.4: Implement auto-save

**File:** Add to `Model/AppState.swift`

```swift
// MARK: - Auto-save

extension AppState {
    private var autoSaveTask: Task<Void, Never>?
    
    func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            do {
                try save()
            } catch {
                await MainActor.run {
                    errorMessage = "Save failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
```

**Verification:** File compiles.

---

## Phase 7: File Operations (Open, Save, Recent, Watcher)

### Task 7.1: Implement File → Open

**File:** Add to `Util/AppDelegate.swift`

```swift
// Inside AppDelegate:

func applicationDidFinishLaunching(_ notification: Notification) {
    guard let appState = appState else { return }
    keyboardHandler = KeyboardHandler(appState: appState)
    keyboardHandler?.start()
    setupMainMenu()
}

private func setupMainMenu() {
    let mainMenu = NSMenu()
    
    // App menu
    let appMenuItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(NSMenuItem(title: "About Binnacle", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(NSMenuItem(title: "Preferences...", action: nil, keyEquivalent: ","))
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(NSMenuItem(title: "Quit Binnacle", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    appMenuItem.submenu = appMenu
    mainMenu.addItem(appMenuItem)
    
    // File menu
    let fileMenuItem = NSMenuItem()
    let fileMenu = NSMenu(title: "File")
    fileMenu.addItem(NSMenuItem(title: "New", action: #selector(newFile), keyEquivalent: "n"))
    fileMenu.addItem(NSMenuItem(title: "Open...", action: #selector(openFile), keyEquivalent: "o"))
    fileMenu.addItem(NSMenuItem.separator())
    fileMenu.addItem(NSMenuItem(title: "Save", action: #selector(saveFile), keyEquivalent: "s"))
    fileMenu.addItem(NSMenuItem.separator())
    
    // Open Recent submenu
    let recentMenuItem = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
    let recentMenu = NSMenu(title: "Open Recent")
    recentMenu.addItem(NSMenuItem(title: "Clear Menu", action: #selector(clearRecent), keyEquivalent: ""))
    recentMenuItem.submenu = recentMenu
    fileMenu.addItem(recentMenuItem)
    
    fileMenuItem.submenu = fileMenu
    mainMenu.addItem(fileMenuItem)
    
    // View menu
    let viewMenuItem = NSMenuItem()
    let viewMenu = NSMenu(title: "View")
    viewMenu.addItem(NSMenuItem(title: "Focus Mode", action: #selector(toggleFocusMode), keyEquivalent: "D"))
    viewMenu.addItem(NSMenuItem(title: "Palette...", action: #selector(openPalette), keyEquivalent: "p"))
    viewMenu.addItem(NSMenuItem.separator())
    viewMenu.addItem(NSMenuItem(title: "Cycle Column Width", action: #selector(cycleWidth), keyEquivalent: "W"))
    viewMenu.addItem(NSMenuItem(title: "Cycle Theme", action: #selector(cycleAppTheme), keyEquivalent: "T"))
    viewMenuItem.submenu = viewMenu
    mainMenu.addItem(viewMenuItem)
    
    NSApplication.shared.mainMenu = mainMenu
}

@objc private func openFile() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.plainText]
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    
    guard panel.runModal() == .OK,
          let url = panel.url else { return }
    
    do {
        try appState?.load(from: url)
    } catch {
        appState?.errorMessage = "Could not open file: \(error.localizedDescription)"
    }
}

@objc private func newFile() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.plainText]
    panel.nameFieldStringValue = "todo.txt"
    
    guard panel.runModal() == .OK,
          let url = panel.url else { return }
    
    // Create empty file
    FileManager.default.createFile(atPath: url.path, contents: nil)
    
    do {
        try appState?.load(from: url)
    } catch {
        appState?.errorMessage = "Could not create file: \(error.localizedDescription)"
    }
}

@objc private func saveFile() {
    do {
        try appState?.save()
    } catch {
        appState?.errorMessage = "Save failed: \(error.localizedDescription)"
    }
}

@objc private func toggleFocusMode() {
    appState?.isFocusMode.toggle()
}

@objc private func openPalette() {
    appState?.isPaletteOpen.toggle()
}

@objc private func cycleWidth() {
    appState?.cycleColumnWidth()
}

@objc private func cycleAppTheme() {
    appState?.cycleTheme()
}

@objc private func clearRecent() {
    // NSDocumentController recent document handling
}
```

**Verification:** File menu works: ⌘O opens file picker, selecting a `.txt` file loads tasks into the list.

### Task 7.2: Implement `FileWatcher`

**File:** Create `Util/FileWatcher.swift`

```swift
import Foundation

final class FileWatcher: NSObject, NSFilePresenter {
    let fileURL: URL
    var onFileChanged: (() -> Void)?
    
    var presentedItemURL: URL? { fileURL }
    var presentedItemOperationQueue: OperationQueue { .main }
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init()
        NSFileCoordinator.addFilePresenter(self)
    }
    
    func presentedItemDidChange() {
        onFileChanged?()
    }
    
    func stop() {
        NSFileCoordinator.removeFilePresenter(self)
    }
}
```

**Verification:** File compiles. Wire into `AppState.load(from:)`:

In `AppState.load(from:)`, after `self.fileURL = url`:

```swift
fileWatcher?.stop()
fileWatcher = FileWatcher(fileURL: url)
fileWatcher?.onFileChanged = { [weak self] in
    DispatchQueue.main.async {
        // Prompt user — for now, auto-reload
        try? self?.reload()
    }
}
```

Add `var fileWatcher: FileWatcher?` to `AppState`.

---

## Phase 8: Polish

### Task 8.1: Save theme preference

**File:** Add to `AppState`:

```swift
var theme: Theme = .system {
    didSet {
        UserDefaults.standard.set(theme.rawValue, forKey: "theme")
    }
}

// In init or restore:
init() {
    if let raw = UserDefaults.standard.string(forKey: "theme"),
       let saved = Theme(rawValue: raw) {
        theme = saved
    }
}
```

**Verification:** Change theme, restart app — theme persists.

### Task 8.2: Dark/light mode support in TaskRow

**File:** Update `TaskRow` foreground colours to respond to theme:

The simplest approach: use a `@Environment(\.colorScheme)` and map to semantic colours in `PequodTheme`.

```swift
extension PequodTheme {
    static func foreground(for theme: AppState.Theme, colorScheme: ColorScheme) -> Color {
        switch theme {
        case .system:
            colorScheme == .dark ? cream : ink
        case .navy:
            cream
        case .parchment:
            ink
        }
    }
    
    static func background(for theme: AppState.Theme, colorScheme: ColorScheme) -> Color {
        switch theme {
        case .system:
            colorScheme == .dark ? navy : parchment
        case .navy:
            navy
        case .parchment:
            parchment
        }
    }
}
```

**Verification:** TaskRow text changes colour correctly across all three theme modes.

### Task 8.3: Add app icon

**File:** Replace `Assets.xcassets/AppIcon` with a 1024×1024 PNG.

For v1, a simple compass rose icon in Pequod colours:

```sh
# Generate a simple icon using sips (or use an SVG → PNG pipeline)
# The icon should be: navy circle + amber compass rose, 1024×1024
```

Add to Xcode assets catalog under `AppIcon`.

**Verification:** App icon appears in Dock and Finder.

### Task 8.4: Add LICENSE and .gitignore

**File:** Create `LICENSE`

```text
MIT License

Copyright (c) 2026 Tiago Jacinto

Permission is hereby granted...
```

(standard MIT text)

**File:** Create `.gitignore`

```text
# Xcode
*.xcuserdata
*.xcworkspace
xcuserdata/
DerivedData/
build/

# Swift
.build/

# macOS
.DS_Store
```

**Commit and push:**

```sh
cd ~/github/binnacle
git add -A
git commit -m "Initial commit: Binnacle — todo.txt task manager for macOS"
git push origin main
```

---

## Phase 9: CI/CD (GitHub Actions)

### Task 9.1: Add build workflow

**File:** Create `.github/workflows/build.yml`

```yaml
name: Build

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app
      - name: Build
        run: xcodebuild -scheme Binnacle -configuration Release build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
      - name: Test
        run: xcodebuild test -scheme Binnacle -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

**Verification:** Push to main — GitHub Actions runs build + tests, both green.

---

## Summary: Files Created

```
binnacle/
├── Binnacle.xcodeproj/
├── Binnacle/
│   ├── BinnacleApp.swift
│   ├── ContentView.swift
│   ├── Assets.xcassets/
│   │   └── AppIcon.appiconset/
│   ├── Model/
│   │   ├── Task.swift
│   │   ├── TaskFile.swift
│   │   └── AppState.swift
│   ├── View/
│   │   ├── TaskRow.swift
│   │   ├── TaskListView.swift
│   │   ├── FocusView.swift
│   │   ├── PaletteView.swift
│   │   ├── EmptyStateView.swift
│   │   └── PreferencesView.swift
│   ├── Theme/
│   │   ├── PequodTheme.swift
│   │   └── Fonts/
│   │       ├── JetBrainsMono-Regular.ttf
│   │       └── JetBrainsMono-Bold.ttf
│   └── Util/
│       ├── AppDelegate.swift
│       ├── KeyboardHandler.swift
│       └── FileWatcher.swift
├── BinnacleTests/
│   └── TaskFileTests.swift
├── .github/workflows/
│   └── build.yml
├── README.md
├── SPEC.md
├── REQUIREMENTS.md
├── PLAN.md
├── LICENSE
└── .gitignore
```

**Total:** ~24 files, ~1,500 lines of Swift, ~10 tests.

## Verification Checklist

- [ ] `xcodebuild -scheme Binnacle build` — compiles with zero warnings
- [ ] `xcodebuild test -scheme Binnacle -destination 'platform=macOS'` — all tests pass
- [ ] Open a `todo.txt` file — tasks appear in list
- [ ] ⌘N adds a new task
- [ ] ⌘Enter toggles completion
- [ ] ⌘⇧D enters focus mode
- [ ] ⌘P opens palette, type to filter
- [ ] ⌘⇧W cycles column width
- [ ] ⌘⇧T cycles theme
- [ ] Edit a task in vim/another editor — app reloads
- [ ] Close and reopen — same file restored
