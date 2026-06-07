import SwiftUI
import AppKit

@MainActor
final class KeyboardHandler {
    private weak var appState: AppState?
    private var monitor: Any?

    init(appState: AppState) {
        self.appState = appState
    }

    func start() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let state = self.appState else { return event }
            return self.handle(event: event, state: state)
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handle(event: NSEvent, state: AppState) -> NSEvent? {
        guard event.modifierFlags.contains(.command) else { return event }

        // In palette mode, only Escape works
        if state.isPaletteOpen && event.keyCode != 53 { return event }

        let shift = event.modifierFlags.contains(.shift)

        switch event.keyCode {
        case 45:  // N — new task
            state.addNewTask()
            return nil
        case 36:  // Return — toggle complete
            if state.isFocusMode {
                state.focusCompleteAndAdvance()
            } else {
                state.toggleSelectedTask()
            }
            return nil
        case 2:   // D — focus mode (with shift)
            if shift {
                state.isFocusMode.toggle()
                return nil
            }
        case 35:  // P — palette (without shift) / toggle focus (with shift)
            if shift {
                state.isFocusMode.toggle()
            } else {
                state.isPaletteOpen.toggle()
            }
            return nil
        case 13:  // W — cycle column width (with shift)
            if shift {
                state.cycleColumnWidth()
                return nil
            }
        case 17:  // T — cycle theme (with shift)
            if shift {
                state.cycleTheme()
                return nil
            }
        case 51:  // Delete — delete selected task
            state.deleteSelectedTask()
            return nil
        case 126: // Up arrow — move task up
            state.moveSelectedTaskUp()
            return nil
        case 125: // Down arrow — move task down
            state.moveSelectedTaskDown()
            return nil
        case 53:  // Escape — dismiss palette / exit focus
            if state.isPaletteOpen {
                state.isPaletteOpen = false
                return nil
            }
            if state.isFocusMode {
                state.isFocusMode = false
                return nil
            }
        default:
            break
        }

        return event
    }
}
