import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    @Published var palette: AccentPalette {
        didSet {
            AccentPalette.current = palette
            persistPalette()
        }
    }

    private let paletteKey = "vppchat.theme.palette"

    init() {
        if let stored = UserDefaults.standard.string(forKey: paletteKey),
           let p = AccentPalette(rawValue: stored) {
            self.palette = p
            AccentPalette.current = p
        } else {
            self.palette = AccentPalette.current
        }
    }

    private func persistPalette() {
        UserDefaults.standard.set(palette.rawValue, forKey: paletteKey)
    }

    // Convenience accessors for existing call sites
    var structuralAccent: Color { palette.structural }
    var exceptionAccent: Color { palette.exception }
}
