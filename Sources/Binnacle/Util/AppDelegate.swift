import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var appState: AppState?
    private var keyboardHandler: KeyboardHandler?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let appState else { return }

        keyboardHandler = KeyboardHandler(appState: appState)
        keyboardHandler?.start()
        setupMainMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyboardHandler?.stop()
        try? appState?.save()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: - Menu bar

    @MainActor private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            NSMenuItem(title: "About Binnacle",
                       action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                       keyEquivalent: "")
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            NSMenuItem(title: "Preferences...",
                       action: nil,
                       keyEquivalent: ",")
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            NSMenuItem(title: "Quit Binnacle",
                       action: #selector(NSApplication.terminate(_:)),
                       keyEquivalent: "q")
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(
            NSMenuItem(title: "New File...",
                       action: #selector(newFile),
                       keyEquivalent: "n")
        )
        fileMenu.addItem(
            NSMenuItem(title: "Open...",
                       action: #selector(openFile),
                       keyEquivalent: "o")
        )
        fileMenu.addItem(.separator())
        fileMenu.addItem(
            NSMenuItem(title: "Save",
                       action: #selector(saveFile),
                       keyEquivalent: "s")
        )
        fileMenu.addItem(.separator())

        // Open Recent
        let recentItem = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
        let recentMenu = NSMenu(title: "Open Recent")
        recentMenu.addItem(
            NSMenuItem(title: "Clear Menu",
                       action: #selector(clearRecent),
                       keyEquivalent: "")
        )
        recentItem.submenu = recentMenu
        fileMenu.addItem(recentItem)

        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // View menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(
            NSMenuItem(title: "Focus Mode",
                       action: #selector(toggleFocusMode),
                       keyEquivalent: "D")
        )
        viewMenu.addItem(
            NSMenuItem(title: "Palette...",
                       action: #selector(openPalette),
                       keyEquivalent: "p")
        )
        viewMenu.addItem(.separator())
        viewMenu.addItem(
            NSMenuItem(title: "Cycle Column Width",
                       action: #selector(cycleWidth),
                       keyEquivalent: "W")
        )
        viewMenu.addItem(
            NSMenuItem(title: "Cycle Theme",
                       action: #selector(cycleAppTheme),
                       keyEquivalent: "T")
        )
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        NSApplication.shared.mainMenu = mainMenu
    }

    // MARK: - Actions

    @objc private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Open todo.txt"
        panel.message = "Choose a todo.txt file to open."

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try appState?.load(from: url)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch {
            appState?.errorMessage = "Could not open file: \(error.localizedDescription)"
        }
    }

    @objc private func newFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "todo.txt"
        panel.title = "Create todo.txt"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        FileManager.default.createFile(
            atPath: url.path,
            contents: "\n".data(using: .utf8)
        )

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
        NSDocumentController.shared.clearRecentDocuments(nil)
    }
}
