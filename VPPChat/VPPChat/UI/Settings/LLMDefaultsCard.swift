//
//  LLMDefaultsCard.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//

import SwiftUI

private enum LLMDefaultsPopover: Hashable {
    case model
}

private struct LLMDefaultsAnchorKey: PreferenceKey {
    static var defaultValue: [LLMDefaultsPopover: Anchor<CGRect>] = [:]
    static func reduce(value: inout [LLMDefaultsPopover: Anchor<CGRect>],
                       nextValue: () -> [LLMDefaultsPopover: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct LLMDefaultsCard: View {
    @EnvironmentObject private var llmConfig: LLMConfigStore
    @State private var activePopover: LLMDefaultsPopover? = nil

    private var selectedPreset: LLMModelPreset {
        LLMModelCatalog.preset(for: llmConfig.defaultModelID)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            content
        }
        .overlayPreferenceValue(LLMDefaultsAnchorKey.self) { anchors in
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    if activePopover != nil {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    activePopover = nil
                                }
                            }
                    }

                    if let active = activePopover,
                       let anchor = anchors[active] {
                        let rect = proxy[anchor]
                        popover(for: active)
                            .fixedSize(horizontal: true, vertical: true)
                            .frame(maxWidth: 360, alignment: .leading)
                            .offset(x: rect.minX, y: rect.maxY + 8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Defaults (new sessions)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("Applies only to newly created Console sessions.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                Spacer()
            }

            Divider()
                .overlay(AppTheme.Colors.borderSoft.opacity(0.7))

            // Model (Atlas-style anchored dropdown)
            VStack(alignment: .leading, spacing: 8) {
                Text("Default model")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.Colors.textSubtle)

                SettingsFilterChip(isActive: true, primary: true) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        activePopover = (activePopover == .model ? nil : .model)
                    }
                } label: {
                    Text(selectedPreset.label)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .anchorPreference(key: LLMDefaultsAnchorKey.self, value: .bounds) { anchor in
                    [.model: anchor]
                }

                if !selectedPreset.detail.isEmpty {
                    Text(selectedPreset.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Context (chips)
            VStack(alignment: .leading, spacing: 8) {
                Text("Default context strategy")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.Colors.textSubtle)

                HStack(spacing: 8) {
                    ForEach(LLMContextStrategy.allCases) { strategy in
                        contextChip(strategy)
                    }
                }

                Text(llmConfig.defaultContextStrategy.hint)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Text("Temperature is adjusted in Studio’s inspector.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Colors.textSecondary)
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

    @ViewBuilder
    private func popover(for popover: LLMDefaultsPopover) -> some View {
        switch popover {
        case .model:
            SettingsPopoverChrome {
                HStack {
                    Text("Model")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Spacer()
                    Button("Done") {
                        withAnimation(.easeOut(duration: 0.18)) {
                            activePopover = nil
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 4)

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(LLMModelCatalog.presets) { preset in
                            modelRow(preset)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
    }

    private func modelRow(_ preset: LLMModelPreset) -> some View {
        let isSelected = (preset.id == llmConfig.defaultModelID)
        return Button {
            llmConfig.defaultModelID = preset.id
            withAnimation(.easeOut(duration: 0.18)) {
                activePopover = nil
            }
        } label: {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    if !preset.detail.isEmpty {
                        Text(preset.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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

    private func contextChip(_ strategy: LLMContextStrategy) -> some View {
        let isSelected = (strategy == llmConfig.defaultContextStrategy)
        return Button {
            llmConfig.defaultContextStrategy = strategy
        } label: {
            Text(strategy.label)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? StudioTheme.Colors.accentSoft : AppTheme.Colors.surface1)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? StudioTheme.Colors.accent : AppTheme.Colors.borderSoft, lineWidth: 1)
                )
                .foregroundStyle(isSelected ? StudioTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings chrome (Atlas-style)

private struct SettingsPopoverChrome<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(12)
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
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.10), radius: 16, x: 6, y: 12)
        .transition(
            reduceMotion ? .opacity : .scale(scale: 0.96, anchor: .topLeading).combined(with: .opacity)
        )
    }
}

private struct SettingsFilterChip<Label: View>: View {
    let isActive: Bool
    let primary: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isHovering: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) { label() }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isActive ? StudioTheme.Colors.accentSoft : AppTheme.Colors.surface1)
                )
                .overlay(
                    Capsule()
                        .stroke(borderColor, lineWidth: primary ? (isActive ? 1.2 : 1) : 1)
                )
                .foregroundStyle(isActive ? StudioTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                .scaleEffect(isHovering ? 1.02 : 1.0)
        }
        .buttonStyle(SettingsScalePressButtonStyle())
#if os(macOS)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
#endif
    }

    private var borderColor: Color {
        if primary {
            return isActive ? StudioTheme.Colors.accent : AppTheme.Colors.borderSoft
        } else {
            return isActive ? StudioTheme.Colors.accent : AppTheme.Colors.borderSoft.opacity(0.9)
        }
    }
}

private struct SettingsScalePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

