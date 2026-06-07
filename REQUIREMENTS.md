# Requirements

## Functional Requirements

### FR-01: File Operations

| ID | Requirement | Priority |
|---|---|---|
| FR-01a | Open a `todo.txt` file via ⌘O (NSOpenPanel, filtered to `.txt`) | Must |
| FR-01b | Open recent files via File → Open Recent menu | Should |
| FR-01c | Create a new `todo.txt` file via ⌘N (NSSavePanel) | Must |
| FR-01d | Read and parse the file on open; display parsed tasks | Must |
| FR-01e | Write the file on change (auto-save, 2s debounce after last edit) | Must |
| FR-01f | Detect external file changes via `NSFilePresenter` and prompt reload | Must |
| FR-01g | Restore last open file on app launch (crash recovery) | Should |

### FR-02: Task Display

| ID | Requirement | Priority |
|---|---|---|
| FR-02a | Display tasks as a scrollable list, grouped by `+project` | Must |
| FR-02b | Each row shows: checkbox, priority, description, projects, contexts, due date | Must |
| FR-02c | Completed tasks rendered with strikethrough + muted colour | Must |
| FR-02d | Completed tasks move to the bottom of the list (or stay inline, configurable) | Must |
| FR-02e | Column width cycling (⌘⇧W): narrow (480px), normal (640px), wide (800px) | Must |
| FR-02f | Empty state: show hint text ("No tasks. ⌘N to add one.") | Must |

### FR-03: Task Editing

| ID | Requirement | Priority |
|---|---|---|
| FR-03a | Add a new task (⌘N): insert empty task at cursor position, focus for inline editing | Must |
| FR-03b | Edit task description inline (click or Enter to edit) | Must |
| FR-03c | Delete a task (⌘⌫): remove the line | Must |
| FR-03d | Toggle task completion (⌘Enter): mark done/undone | Must |
| FR-03e | Reorder task up (⌘↑) and down (⌘↓) | Must |
| FR-03f | Set priority: `(A)`, `(B)`, `(C)`, or none, via right-click or shortcut | Should |
| FR-03g | Add/remove contexts (@tag) and projects (+tag) inline or via palette | Should |

### FR-04: Focus Mode

| ID | Requirement | Priority |
|---|---|---|
| FR-04a | Enter focus mode (⌘⇧D): show only the currently selected task | Must |
| FR-04b | Focus view: navy solid background, task centred, large JetBrains Mono | Must |
| FR-04c | Navigate between tasks in focus mode: ⌘↓ (next), ⌘↑ (previous) | Must |
| FR-04d | Complete task in focus mode (⌘Enter): mark done, advance to next pending | Must |
| FR-04e | Exit focus mode (⌘⇧D or Esc): return to list at current position | Must |
| FR-04f | Show counter "3 of 7" in focus mode | Must |
| FR-04g | Focus mode skips completed tasks (configurable) | Should |

### FR-05: Palette (⌘P)

| ID | Requirement | Priority |
|---|---|---|
| FR-05a | Fuzzy search over task descriptions, projects, and contexts | Must |
| FR-05b | Navigate results with ↑/↓, select with Enter, dismiss with Esc | Must |
| FR-05c | Selecting a task navigates to it in the list (or opens it in focus mode) | Must |
| FR-05d | Filter by project or context: typing `+binnacle` shows only tasks in that project | Should |

### FR-06: Themes

| ID | Requirement | Priority |
|---|---|---|
| FR-06a | Three themes: system (follow OS), navy (dark), parchment (light) | Must |
| FR-06b | Cycle theme with ⌘⇧T | Must |
| FR-06c | Persist theme preference in UserDefaults | Must |
| FR-06d | Use Pequod palette exclusively: navy `#0B1F2D`, parchment `#F1E7D2`, amber `#D4A882`, cream `#E8D5B7`, ink `#1A1A1A` | Must |

### FR-07: Typography

| ID | Requirement | Priority |
|---|---|---|
| FR-07a | Use JetBrains Mono (bundled, SIL Open Font) for all text | Must |
| FR-07b | Task description: 13px regular | Must |
| FR-07c | Tags, dates, metadata: 11px | Must |
| FR-07d | Focus mode task: 18px | Must |
| FR-07e | Palette input: 14px | Must |

---

## Non-Functional Requirements

### NFR-01: Performance

| ID | Requirement | Target |
|---|---|---|
| NFR-01a | App launch time (cold, on Apple Silicon) | < 1 second |
| NFR-01b | File parse time for 500 tasks | < 50 ms |
| NFR-01c | Memory footprint at idle | < 50 MB |
| NFR-01d | Binary size (.app, uncompressed) | < 5 MB |

### NFR-02: Compatibility

| ID | Requirement |
|---|---|
| NFR-02a | macOS 15 (Sequoia) or later |
| NFR-02b | Apple Silicon native (arm64). Intel via Rosetta 2 (no separate x86_64 build) |
| NFR-02c | Unsigned binary — user strips quarantine with `xattr` |
| NFR-02d | No sandbox (app needs file system access to open arbitrary files) |

### NFR-03: Code Quality

| ID | Requirement |
|---|---|
| NFR-03a | Swift 6 with strict concurrency checking enabled |
| NFR-03b | All public types annotated with `@MainActor` or `Sendable` as appropriate |
| NFR-03c | Unit tests for parser (TaskFile), model (Task), and keyboard handler |
| NFR-03d | Zero warnings at `-warnings-as-errors` |
| NFR-03e | Modular architecture: Model knows nothing about View; View observes Model via `@Observable` |

### NFR-04: What Binnacle Will NOT Do (anti-features)

- ❌ Cloud sync of any kind
- ❌ User accounts or authentication
- ❌ Analytics, telemetry, or crash reporting to external servers
- ❌ AI-powered prioritisation or scheduling
- ❌ Natural language date parsing (use `due:YYYY-MM-DD`)
- ❌ iOS / iPadOS / watchOS companion
- ❌ iCloud or CoreData persistence
- ❌ Notifications (use `due:` and your calendar app)
- ❌ Calendar integration
- ❌ Collaboration or multi-user
- ❌ Kanban board or Gantt chart views
- ❌ Markdown rendering
- ❌ Plugin system
- ❌ Themes marketplace
- ❌ Recurring tasks (use `due:` and a cron job)
- ❌ Subtasks or task hierarchy
- ❌ Attachments or images
