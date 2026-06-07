import SwiftUI

struct EmptyStateView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Compass icon (the binnacle itself)
            compassIcon
                .padding(.bottom, 8)

            Text("No tasks.")
                .font(PequodTheme.taskFont(size: 16))
                .foregroundColor(PequodTheme.amber.opacity(0.4))

            if state.fileURL == nil {
                VStack(spacing: 8) {
                    Text("\u{2318}O to open a todo.txt file")
                        .font(PequodTheme.metadataFont())
                        .foregroundColor(PequodTheme.amber.opacity(0.25))
                    Text("or \u{2318}N to create one")
                        .font(PequodTheme.metadataFont())
                        .foregroundColor(PequodTheme.amber.opacity(0.25))
                }
            } else {
                Text("\u{2318}N to add the first task")
                    .font(PequodTheme.metadataFont())
                    .foregroundColor(PequodTheme.amber.opacity(0.25))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Compass icon (drawn in code)

    private var compassIcon: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(PequodTheme.amber.opacity(0.3), lineWidth: 2)
                .frame(width: 52, height: 52)

            // Inner ring
            Circle()
                .stroke(PequodTheme.amber.opacity(0.15), lineWidth: 1)
                .frame(width: 36, height: 36)

            // North marker (filled rhombus)
            Path { path in
                path.move(to: CGPoint(x: 26, y: 6))
                path.addLine(to: CGPoint(x: 22, y: 22))
                path.addLine(to: CGPoint(x: 26, y: 18))
                path.addLine(to: CGPoint(x: 30, y: 22))
                path.closeSubpath()
            }
            .fill(PequodTheme.amber.opacity(0.5))

            // South marker
            Path { path in
                path.move(to: CGPoint(x: 26, y: 46))
                path.addLine(to: CGPoint(x: 22, y: 30))
                path.addLine(to: CGPoint(x: 26, y: 34))
                path.addLine(to: CGPoint(x: 30, y: 30))
                path.closeSubpath()
            }
            .fill(PequodTheme.amber.opacity(0.2))

            // Centre dot
            Circle()
                .fill(PequodTheme.amber.opacity(0.4))
                .frame(width: 4, height: 4)
        }
    }
}
