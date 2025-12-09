//
//  Theme.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/9/25.
//

import SwiftUI

// Simple design system for GlassGPT-style styling.
enum AppTheme {
    enum Colors {
        // Backgrounds
        static let window = Color(red: 5/255, green: 6/255, blue: 10/255)
        static let surface0 = Color(red: 9/255, green: 11/255, blue: 18/255)
        static let surface1 = Color(red: 17/255, green: 22/255, blue: 36/255).opacity(0.88)
        static let surface2 = Color(red: 22/255, green: 28/255, blue: 46/255).opacity(0.96)

        // Accent families
        // Structural tags (G, Q, O, C, O_F)
        static let structuralAccent = Color(red: 0.49, green: 0.50, blue: 1.0)      // ~violet/indigo
        static let structuralAccentSoft = structuralAccent.opacity(0.18)

        // Exception tags (E, E_O)
        static let exceptionAccent = Color(red: 1.0, green: 0.31, blue: 0.63)       // ~magenta/red
        static let exceptionAccentSoft = exceptionAccent.opacity(0.18)

        // Status
        static let statusCorrect = Color(red: 0.31, green: 0.89, blue: 0.56)
        static let statusMinor = Color(red: 1.0, green: 0.78, blue: 0.34)
        static let statusMajor = Color(red: 1.0, green: 0.30, blue: 0.36)

        // Text
        static let textPrimary = Color(red: 0.96, green: 0.97, blue: 0.98)
        static let textSecondary = Color(red: 0.65, green: 0.69, blue: 0.78)
        static let textSubtle = Color(red: 0.50, green: 0.53, blue: 0.63)

        static let borderSoft = Color.white.opacity(0.12)
        static let borderEmphasis = structuralAccent.opacity(0.5)
    }

    enum Radii {
        static let card: CGFloat = 16
        static let panel: CGFloat = 24
        static let chip: CGFloat = 999
    }

    enum Spacing {
        static let base: CGFloat = 8
        static let cardInner: CGFloat = 16
        static let outerHorizontal: CGFloat = 24
    }

    enum Motion {
        static let fast: Double = 0.18
        static let medium: Double = 0.25
    }
}

// Optional: simple noise overlay placeholder.
// You can swap this for a more sophisticated shader/noise source later.
struct NoiseBackground: View {
    var body: some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [
                    AppTheme.Colors.window,
                    AppTheme.Colors.surface0
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .blendMode(.softLight)
                    .opacity(0.6)
            )
            .ignoresSafeArea()
    }
}
