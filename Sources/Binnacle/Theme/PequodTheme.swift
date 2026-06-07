import SwiftUI

enum PequodTheme {
    // MARK: - Core palette

    static let navy       = Color(hex: "0B1F2D")
    static let parchment  = Color(hex: "F1E7D2")
    static let amber      = Color(hex: "D4A882")
    static let amberLight = Color(hex: "BD8C68")
    static let cream      = Color(hex: "E8D5B7")
    static let ink        = Color(hex: "1A1A1A")

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

    // MARK: - Semantic colours

    static func foreground(theme: AppState.Theme, colorScheme: ColorScheme) -> Color {
        switch theme {
        case .system:    colorScheme == .dark ? cream : ink
        case .navy:      cream
        case .parchment: ink
        }
    }

    static func background(theme: AppState.Theme, colorScheme: ColorScheme) -> Color {
        switch theme {
        case .system:    colorScheme == .dark ? navy : parchment
        case .navy:      navy
        case .parchment: parchment
        }
    }

    static func mutedForeground(theme: AppState.Theme, colorScheme: ColorScheme) -> Color {
        amber.opacity(theme == .parchment ? 0.7 : 0.5)
    }

    static func completedForeground(theme: AppState.Theme) -> Color {
        amber.opacity(theme == .parchment ? 0.4 : 0.35)
    }
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
