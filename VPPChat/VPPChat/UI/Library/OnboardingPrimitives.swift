//
//  OnboardingChip.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/17/25.
//


import SwiftUI

/// Shared UI primitives used by both onboarding + scene creation.
/// (Keep these in one place so the forms stay identical.)
struct OnboardingChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var pressAnim: Animation {
        reduceMotion ? .easeOut(duration: 0.01) : AppTheme.Motion.chipPress
    }

    var body: some View {
        Button {
            withAnimation(pressAnim) { action() }
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? StudioTheme.Colors.accentSoft : AppTheme.Colors.surface1)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? StudioTheme.Colors.accent : AppTheme.Colors.borderSoft,
                            lineWidth: isSelected ? 1.4 : 1
                        )
                )
                .foregroundStyle(isSelected ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

struct OnboardingSoftField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Colors.textSubtle)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.Colors.surface1)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                        .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                )
        }
    }
}
