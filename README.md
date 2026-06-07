# Binnacle

A todo.txt task manager for macOS. The shapes loom before they take form.

**Binnacle** (n.) — the wooden or brass stand that houses a ship's compass. From Latin *habitaculum* ("little dwelling"). It sits before the helmsman, silent and essential. It does not steer the ship; it only points. Without it, there is no heading.

## What it is

A native macOS app that reads and writes a single `todo.txt` file. You open it, you see your tasks, you close it. The file is yours — version it with git, sync it however you want, open it in any text editor.

- Native SwiftUI + AppKit. No Electron. No WebView. No Chromium.
- One file format: [todo.txt](http://todotxt.org), plain text, human-readable
- Seven distinctive keyboard shortcuts + macOS conventions
- Pequod theme (navy, parchment, amber)
- Focus mode: show only the task you're working on
- Zero accounts. Zero cloud. Zero tracking.

## Philosophy

> most task managers want a piece of you.
>
> an account, a subscription, a "smart" scheduler, a cloud sync engine, a mobile companion, an AI that prioritises your groceries.
>
> binnacle does not.

Every missing feature is a deliberate choice. The app gets out of the way.

- **The file is yours.** It lives wherever you put it. No proprietary database.
- **Keyboard-driven.** Reach for the mouse only if you want to.
- **Small binary.** Target: under 5 MB. SwiftUI compiles to nothing.
- **One person, spare evenings.** MIT licensed, on GitHub.

## Install

### macOS (Homebrew, Apple Silicon)

```sh
brew install --cask --no-quarantine tiagojct/binnacle/binnacle
```

The `--no-quarantine` flag is required because the build is unsigned. Without it,
macOS Gatekeeper will reject the app on first launch. If already installed:

```sh
xattr -dr com.apple.quarantine /Applications/Binnacle.app
```

### Direct download

Download the `.dmg` from [releases](https://github.com/tiagojct/binnacle/releases/latest).

### Build from source

Prerequisites: Xcode (full, from App Store), Swift 6.

```sh
git clone https://github.com/tiagojct/binnacle
cd binnacle
swift build
swift test
```

To produce a standalone `.app` bundle:

```sh
xcodebuild -scheme Binnacle -configuration Release build
```

## Format

Binnacle reads and writes standard `todo.txt`:

```
(A) Call Mom @phone due:2026-06-08
x 2026-06-07 2026-06-05 Buy milk @errands
(B) Revise the paper +binnacle due:2026-06-15
```

Full specification in [SPEC.md](SPEC.md).

## Keyboard shortcuts

| Key | Action |
|---|---|
| ⌘N | New task |
| ⌘Enter | Toggle complete / uncomplete |
| ⌘⇧D | Focus mode (current task only) |
| ⌘⇧P | Toggle list / focus view |
| ⌘⇧W | Cycle column width |
| ⌘⇧T | Cycle theme |
| ⌘P | Palette: fuzzy search projects, contexts, text |
| ⌘↑ / ⌘↓ | Reorder task |
| ⌘⌫ | Delete task |
| ⌘, | Preferences (file path, theme) |

## License

MIT — see [LICENSE](LICENSE).
