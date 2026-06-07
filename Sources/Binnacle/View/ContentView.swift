import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Background
            PequodTheme.background(theme: state.theme, colorScheme: colorScheme)
                .ignoresSafeArea()

            // Main content
            Group {
                if state.isFocusMode {
                    FocusView()
                } else {
                    TaskListView()
                }
            }
            .frame(minWidth: state.columnWidth.points)

            // Palette overlay
            if state.isPaletteOpen {
                paletteOverlay
            }

            // Error banner
            if let error = state.errorMessage {
                errorBanner(error)
            }
        }
        .frame(minWidth: 480, minHeight: 320)
    }

    // MARK: - Palette overlay

    private var paletteOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    state.isPaletteOpen = false
                }
            PaletteView()
        }
    }

    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        VStack {
            HStack {
                Text(message)
                    .font(PequodTheme.metadataFont())
                    .foregroundColor(PequodTheme.cream)
                Spacer()
                Button("Dismiss") {
                    state.errorMessage = nil
                }
                .font(PequodTheme.metadataFont())
                .foregroundColor(PequodTheme.amber)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(PequodTheme.navy.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            Spacer()
        }
        .padding(.top, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
