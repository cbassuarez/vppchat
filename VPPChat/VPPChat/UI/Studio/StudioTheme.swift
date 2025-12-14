import SwiftUI


struct StudioTheme {
    struct Colors {
        // Light neutrals
        static let background = Color(red: 0.96, green: 0.97, blue: 0.99)
        static let surface2   = Color.white
        static let surface1   = Color.white.opacity(0.8)

        static let panel = Color.white

        static let textPrimary   = Color(red: 0.08, green: 0.10, blue: 0.16)
        static let textSecondary = Color(red: 0.35, green: 0.38, blue: 0.47)
        static let textSubtle    = Color(red: 0.55, green: 0.59, blue: 0.69)

        static let borderSoft = Color.black.opacity(0.08)

        // Accent slots — now driven by AccentPalette
        static var accent: Color {
            AccentPalette.current.structural
        }

        static var accentSoft: Color {
            accent.opacity(0.16)
        }

        static var structuralAccent: Color {
            AccentPalette.current.structural
        }

        static var exceptionAccent: Color {
            AccentPalette.current.exception
        }

        // Status
        static let statusCorrect = Color(red: 0.06, green: 0.62, blue: 0.26)
        static let statusMinor   = Color(red: 0.87, green: 0.65, blue: 0.09)
        static let statusMajor   = Color(red: 0.80, green: 0.15, blue: 0.20)
    }

    struct Radii {
        static let card: CGFloat  = 16
        static let panel: CGFloat = 24
    }

    struct Spacing {
        static let base: CGFloat  = 8
        static let outer: CGFloat = 24
    }
}


struct StudioBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.97, blue: 0.99),
                Color(red: 0.93, green: 0.95, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Color.white.opacity(0.25).blendMode(.softLight)
        )
        .ignoresSafeArea()
    }
}
