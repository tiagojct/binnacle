import SwiftUI
import AppKit

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
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New File...") {
                    newFileAction()
                }
                .keyboardShortcut("n")
            }
            CommandGroup(replacing: .appSettings) {
                Button("Preferences...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",")
            }
        }

        Settings {
            PreferencesView()
                .environment(appState)
        }
    }

    // MARK: - Session restore

    private func restoreLastSession() {
        guard let path = UserDefaults.standard.string(forKey: "binnacle_lastFilePath"),
              FileManager.default.fileExists(atPath: path) else { return }
        let url = URL(fileURLWithPath: path)
        do {
            try appState.load(from: url)
        } catch {
            appState.errorMessage = "Could not restore last session."
        }
    }

    private func newFileAction() {
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
            try appState.load(from: url)
        } catch {
            appState.errorMessage = "Could not create file: \(error.localizedDescription)"
        }
    }
}
