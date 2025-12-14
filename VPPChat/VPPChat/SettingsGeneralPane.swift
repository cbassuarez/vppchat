//
//  SettingsGeneralPane.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//


// SettingsGeneralPane.swift
// VPPChat

import SwiftUI

struct SettingsGeneralPane: View {
    @EnvironmentObject private var llmConfig: LLMConfigStore

    private var selectedPreset: LLMModelPreset {
        LLMModelCatalog.preset(for: llmConfig.defaultModelID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Defaults for new console sessions")
                .font(.system(size: 16.5, weight: .semibold))

            // Model
            VStack(alignment: .leading, spacing: 6) {
                Text("Default Model")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.Colors.textSubtle)

                Picker("Default Model", selection: $llmConfig.defaultModelID) {
                    ForEach(LLMModelCatalog.presets) { preset in
                        Text(preset.label).tag(preset.id)
                    }
                }
#if os(macOS)
            //    .pickerStyle(.popUpButton)
#endif

                Text(selectedPreset.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            // Temperature
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Default Temperature")
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.Colors.textSubtle)

                    Spacer()

                    Text(String(format: "%.2f", llmConfig.defaultTemperature))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                Slider(
                    value: Binding(
                        get: { llmConfig.defaultTemperature },
                        set: { newValue in
                            let clamped = min(1.0, max(0.0, newValue))
                            llmConfig.defaultTemperature = clamped
                        }
                    ),
                    in: 0.0...1.0
                )
                .controlSize(.small)
            }

            // Context strategy
            VStack(alignment: .leading, spacing: 6) {
                Text("Default Context Strategy")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.Colors.textSubtle)

                Picker("", selection: Binding(
                    get: { llmConfig.defaultContextStrategy },
                    set: { newValue in
                        llmConfig.defaultContextStrategy = newValue
                    }
                )) {
                    ForEach(LLMContextStrategy.allCases) { strategy in
                        Text(strategy.label).tag(strategy)
                    }
                }
                .pickerStyle(.segmented)

                Text(llmConfig.defaultContextStrategy.hint)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.primary.opacity(0.07), lineWidth: 1)
                )
        )
    }
}
