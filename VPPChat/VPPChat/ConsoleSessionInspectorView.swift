//
//  ConsoleSessionInspectorView.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//


// ConsoleSessionInspectorView.swift
// VPPChat

import SwiftUI

struct ConsoleSessionInspectorView: View {
    @Binding var modelID: String
    @Binding var temperature: Double
    @Binding var contextStrategy: LLMContextStrategy

    @Environment(\.colorScheme) private var colorScheme

    private var selectedPreset: LLMModelPreset {
        LLMModelCatalog.preset(for: modelID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            modelPicker

            temperatureRow

            contextRow
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                .fill(AppTheme.Colors.surface0)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                        .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                )
        )
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 6) {
            Text("Session Model")
                .font(.system(size: 12, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Colors.textSubtle)

            Spacer()

            Text(selectedPreset.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    private var modelPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Model", selection: $modelID) {
                ForEach(LLMModelCatalog.presets) { preset in
                    Text(preset.label)
                        .tag(preset.id)
                }
            }
#if os(macOS)
            .pickerStyle(.menu)
#endif

            Text(selectedPreset.detail)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .lineLimit(2)
        }
    }

    private var temperatureRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Temperature")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.Colors.textSubtle)

                Spacer()

                Text(String(format: "%.2f", temperature))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Slider(
                value: Binding(
                    get: { temperature },
                    set: { newValue in
                        temperature = min(1.0, max(0.0, newValue))
                    }
                ),
                in: 0.0...1.0
            )
            .controlSize(.small)
        }
    }

    private var contextRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Context")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.Colors.textSubtle)

                Spacer()
            }

            Picker("", selection: $contextStrategy) {
                ForEach(LLMContextStrategy.allCases) { strategy in
                    Text(strategy.label).tag(strategy)
                }
            }
            .pickerStyle(.segmented)

            Text(contextStrategy.hint)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }
}
