//
//  SettingsAdvancedPane.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//


import SwiftUI

struct SettingsAdvancedPane: View {
    @AppStorage("settings.advanced.verboseLogging") private var verboseLogging: Bool = false
    @AppStorage("settings.advanced.debugOverlays") private var debugOverlays: Bool = false
    @AppStorage("settings.advanced.experimentalFeatures") private var experimentalFeatures: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Divider()
                .overlay(AppTheme.Colors.borderSoft.opacity(0.7))

            VStack(alignment: .leading, spacing: 10) {
                Toggle("Verbose logging", isOn: $verboseLogging)
                    .toggleStyle(.switch)
                Toggle("Show debug overlays", isOn: $debugOverlays)
                    .toggleStyle(.switch)
                Toggle("Enable experimental features", isOn: $experimentalFeatures)
                    .toggleStyle(.switch)

                Text("These are developer-facing defaults. Some may require an app restart.")
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
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Advanced")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("Diagnostics and experimental flags.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            Spacer()
        }
    }
}
