//
//  SettingsMotionPane.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//


import SwiftUI

struct SettingsMotionPane: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    @AppStorage("settings.motion.override") private var overrideSystem: Bool = false
    @AppStorage("settings.motion.reduce") private var reduceOverride: Bool = false

    private var effectiveReduceMotion: Bool {
        overrideSystem ? reduceOverride : systemReduceMotion
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Divider()
                .overlay(AppTheme.Colors.borderSoft.opacity(0.7))

            VStack(alignment: .leading, spacing: 10) {
                row(label: "System Reduce Motion", value: systemReduceMotion ? "On" : "Off")

                Toggle("Override system Reduce Motion", isOn: $overrideSystem)
                    .toggleStyle(.switch)

                if overrideSystem {
                    Toggle("Reduce motion", isOn: $reduceOverride)
                        .toggleStyle(.switch)
                }

                row(label: "Effective Reduce Motion", value: effectiveReduceMotion ? "On" : "Off")

                Text("If you override, the app should prefer this value where motion is used.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                .fill(AppTheme.Colors.surface0)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                        .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                )
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Motion")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("Respect system settings, or override for testing.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            Spacer()
        }
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }
}
