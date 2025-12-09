import SwiftUI

enum StudioTheme {
    enum Colors {
        static let backdropTop = Color(red: 10/255, green: 12/255, blue: 20/255)
        static let backdropBottom = Color(red: 4/255, green: 5/255, blue: 9/255)
        static let panel = Color.white.opacity(0.08)
        static let borderSoft = Color.white.opacity(0.12)
        static let accent = Color(red: 0.56, green: 0.66, blue: 1.0)
        static let accentSoft = accent.opacity(0.18)
        static let textPrimary = Color(red: 0.96, green: 0.97, blue: 0.98)
        static let textSecondary = Color(red: 0.70, green: 0.73, blue: 0.80)
        static let textSubtle = Color.white.opacity(0.55)
    }

    enum Radii {
        static let card: CGFloat = 16
        static let panel: CGFloat = 22
    }
}

struct StudioBackgroundView: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [StudioTheme.Colors.backdropTop, StudioTheme.Colors.backdropBottom]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            AngularGradient(
                gradient: Gradient(colors: [
                    StudioTheme.Colors.accent.opacity(0.3),
                    .clear,
                    Color.purple.opacity(0.25),
                    .clear
                ]),
                center: .center
            )
            .blur(radius: 160)
        )
        .ignoresSafeArea()
    }
}
