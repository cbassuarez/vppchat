//
//  ConsoleSessionInspectorView.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//


// ConsoleSessionInspectorView.swift
// VPPChat

import SwiftUI

private enum TemperaturePreset: String, CaseIterable, Identifiable {
    case deterministic
    case low
    case balanced
    case creative
    case wild

    var id: Self { self }

    var label: String {
        switch self {
        case .deterministic: return "Deterministic"
        case .low:           return "Low variation"
        case .balanced:      return "Balanced"
        case .creative:      return "Creative"
        case .wild:          return "Wild"
        }
    }

    var detail: String {
        switch self {
        case .deterministic: return "Pinned, repeatable · ~0.0"
        case .low:           return "Careful, focused · ~0.25"
        case .balanced:      return "Default mix · ~0.5"
        case .creative:      return "Playful, exploratory · ~0.75"
        case .wild:          return "Maximum variation · ~1.0"
        }
    }

    var value: Double {
        switch self {
        case .deterministic: return 0.0
        case .low:           return 0.25
        case .balanced:      return 0.5
        case .creative:      return 0.75
        case .wild:          return 1.0
        }
    }

    static func nearestPreset(for value: Double) -> TemperaturePreset {
        let clamped = max(0.0, min(1.0, value))
        return Self.allCases.min(by: { abs($0.value - clamped) < abs($1.value - clamped) }) ?? .balanced
    }
}


struct ConsoleSessionInspectorView: View {
    @Binding var modelID: String
    @Binding var temperature: Double
    @Binding var contextStrategy: LLMContextStrategy
    @State private var isTemperaturePopoverPresented = false

    @Environment(\.colorScheme) private var colorScheme

    private var selectedPreset: LLMModelPreset {
        LLMModelCatalog.preset(for: modelID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
                .overlay(AppTheme.Colors.borderSoft.opacity(0.7))
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
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 6, y: 8)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "cpu")
                .font(.system(size: 12, weight: .semibold))

            Text("Session Model")
                .font(.system(size: 12, weight: .semibold))
                .textCase(.uppercase)
        }
        .foregroundStyle(AppTheme.Colors.textSubtle)
    }

    private var modelPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Model")
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Colors.textSubtle)

            // Compact horizontal chip row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(LLMModelCatalog.presets) { preset in
                        modelChip(for: preset)
                    }
                }
                .padding(.vertical, 2)
            }

            // Single detail line for the *selected* model only
            if !selectedPreset.detail.isEmpty {
                Text(selectedPreset.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
        }
    }

    private func modelChip(for preset: LLMModelPreset) -> some View {
        let isSelected = (preset.id == modelID)

        return Button {
            modelID = preset.id
        } label: {
            Text(preset.label)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected
                              ? StudioTheme.Colors.accentSoft
                              : StudioTheme.Colors.surface1)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                            ? StudioTheme.Colors.accent
                            : StudioTheme.Colors.borderSoft,
                            lineWidth: isSelected ? 1.3 : 1
                        )
                )
                .foregroundStyle(
                    isSelected
                    ? StudioTheme.Colors.textPrimary
                    : StudioTheme.Colors.textSecondary
                )
        }
        .buttonStyle(.plain)
    }

    private var temperatureRow: some View {
        let currentPreset = TemperaturePreset.nearestPreset(for: temperature)

        return VStack(alignment: .leading, spacing: 6) {
            Text("Temperature")
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Colors.textSubtle)

            // Chip + inline dropdown card
            VStack(alignment: .leading, spacing: 4) {
                InspectorFilterChip(isActive: true) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        isTemperaturePopoverPresented.toggle()
                    }
                } label: {
                    Text(currentPreset.label)
                    Text("·")
                    Text(String(format: "≈ %.2f", currentPreset.value))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }

                if isTemperaturePopoverPresented {
                    InspectorPopoverChrome {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Temperature")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                                .padding(.bottom, 4)

                            ForEach(TemperaturePreset.allCases) { preset in
                                let isSelected = (preset == currentPreset)

                                Button {
                                    temperature = preset.value
                                    withAnimation(.easeOut(duration: 0.18)) {
                                        isTemperaturePopoverPresented = false
                                    }
                                } label: {
                                    HStack(alignment: .top, spacing: 8) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(preset.label)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(AppTheme.Colors.textPrimary)

                                            Text(preset.detail)
                                                .font(.system(size: 11))
                                                .foregroundStyle(AppTheme.Colors.textSecondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }

                                        Spacer()

                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(StudioTheme.Colors.accent)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 2)
                }
            }

            Text(currentPreset.detail)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.Colors.textSubtle)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    
    private var contextRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Context")
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Colors.textSubtle)

            HStack(spacing: 6) {
                ForEach(LLMContextStrategy.allCases) { strategy in
                    contextChip(for: strategy)
                }
            }

            Text(contextStrategy.hint)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.Colors.textSubtle)
        }
    }

    private func contextChip(for strategy: LLMContextStrategy) -> some View {
        let isSelected = (strategy == contextStrategy)

        return Button {
            contextStrategy = strategy
        } label: {
            Text(strategy.label)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected
                              ? StudioTheme.Colors.accentSoft
                              : StudioTheme.Colors.surface1)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                            ? StudioTheme.Colors.accent
                            : StudioTheme.Colors.borderSoft,
                            lineWidth: isSelected ? 1.3 : 1
                        )
                )
                .foregroundStyle(
                    isSelected
                    ? StudioTheme.Colors.textPrimary
                    : StudioTheme.Colors.textSecondary
                )
        }
        .buttonStyle(.plain)
    }

}

// MARK: - Inspector chrome + chip (Atlas-style)

private struct InspectorPopoverChrome<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(12)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 320, alignment: .topLeading)
        .background(
            .ultraThinMaterial.opacity(0.5),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.Colors.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 16, x: 6, y: 12)
        .transition(
            reduceMotion
            ? .opacity
            : .scale(scale: 0.96, anchor: .topLeading).combined(with: .opacity)
        )
    }
}


private struct InspectorFilterChip<Label: View>: View {
    let isActive: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                label()
            }
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isActive
                          ? StudioTheme.Colors.accentSoft
                          : StudioTheme.Colors.surface1)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isActive
                        ? StudioTheme.Colors.accent
                        : StudioTheme.Colors.borderSoft,
                        lineWidth: isActive ? 1.2 : 1
                    )
            )
            .foregroundStyle(
                isActive
                ? StudioTheme.Colors.textPrimary
                : StudioTheme.Colors.textSecondary
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
        }
        .buttonStyle(InspectorScalePressButtonStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

private struct InspectorScalePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
