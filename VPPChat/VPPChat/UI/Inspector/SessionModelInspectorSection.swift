//
//  SessionModelInspectorSection.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//


import SwiftUI

struct SessionModelInspectorSection: View {
    /// Optional session title to show in the header pill.
    let sessionTitle: String?

    /// Bindings into whatever model config you already have on the VM.
    @Binding var modelID: String
    @Binding var temperature: Double       // 0...1
    @Binding var useFullHistory: Bool      // false = compact, true = full
    @Binding var webEnabled: Bool          // false = local-only, true = web

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct ModelPreset: Identifiable {
        let id: String
        let label: String
        let subtitle: String?
        var isPrimary: Bool
    }

    // Tune these IDs/labels to match your actual model identifiers.
    private var presets: [ModelPreset] {
        [
            .init(id: "gpt-5.1-thinking", label: "5.1 thinking", subtitle: "Deep reasoning", isPrimary: true),
            .init(id: "gpt-4.1-mini",     label: "4.1 mini",     subtitle: "Balanced",      isPrimary: false),
            .init(id: "gpt-4o-mini",      label: "4o mini",      subtitle: "Fast/light",    isPrimary: false)
        ]
    }

    private var currentPreset: ModelPreset? {
        presets.first(where: { $0.id == modelID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            Divider().overlay(AppTheme.Colors.borderSoft.opacity(0.7))
            modelRow
            temperatureRow
            contextRow
            sourcesRow
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
        .animation(reduceMotion ? .none : .spring(response: 0.22, dampingFraction: 0.85),
                   value: modelID)
    }

    // MARK: - Rows

    private var headerRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 12, weight: .semibold))
                Text("Session Model")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(StudioTheme.Colors.textPrimary)

            Spacer()

            if let preset = currentPreset {
                HStack(spacing: 6) {
                    Text(preset.label)
                        .font(.system(size: 11, weight: .medium))
                    if let title = sessionTitle, !title.isEmpty {
                        Text("·")
                        Text(title)
                    }
                }
                .font(.system(size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(StudioTheme.Colors.surface1)
                )
                .overlay(
                    Capsule()
                        .stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
                )
                .foregroundStyle(StudioTheme.Colors.textSecondary)
            }
        }
    }

    private var modelRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Model")
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Colors.textSubtle)

            HStack(spacing: 6) {
                ForEach(presets) { preset in
                    modelChip(for: preset)
                }
            }
        }
    }

    private func modelChip(for preset: ModelPreset) -> some View {
        let isSelected = (preset.id == modelID)

        return Button {
            modelID = preset.id
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.label)
                    .font(.system(size: 11, weight: .semibold))
                if let subtitle = preset.subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minWidth: 90, alignment: .leading)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Temperature")
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.Colors.textSubtle)
                Spacer()
                Text(String(format: "%.2f", temperature))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            // Custom glass rail wrapping the system Slider
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(AppTheme.Colors.surface1)
                    .frame(height: 6)

                GeometryReader { proxy in
                    let width = proxy.size.width * CGFloat(max(0.0, min(temperature, 1.0)))

                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(StudioTheme.Colors.accentSoft)
                        .frame(width: width, height: 6)
                }
                .allowsHitTesting(false)

                Slider(value: $temperature, in: 0...1)
                    .labelsHidden()
                    .tint(StudioTheme.Colors.accent)
            }
            .frame(height: 24)
        }
    }

    private var contextRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Context")
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Colors.textSubtle)

            HStack(spacing: 6) {
                contextChip(
                    label: "Compact",
                    subtitle: "Last few turns",
                    isOn: !useFullHistory
                ) {
                    useFullHistory = false
                }

                contextChip(
                    label: "Full history",
                    subtitle: "All turns",
                    isOn: useFullHistory
                ) {
                    useFullHistory = true
                }
            }

            Text(useFullHistory
                 ? "Sends the full conversation history (may be slower/cost more)."
                 : "Prefers recent turns, trimming older context before sending.")
            .font(.system(size: 10))
            .foregroundStyle(AppTheme.Colors.textSubtle)
        }
    }

    private func contextChip(
        label: String,
        subtitle: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isOn
                          ? StudioTheme.Colors.accentSoft
                          : StudioTheme.Colors.surface1)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isOn
                        ? StudioTheme.Colors.accent
                        : StudioTheme.Colors.borderSoft,
                        lineWidth: isOn ? 1.3 : 1
                    )
            )
            .foregroundStyle(
                isOn
                ? StudioTheme.Colors.textPrimary
                : StudioTheme.Colors.textSecondary
            )
        }
        .buttonStyle(.plain)
    }

    private var sourcesRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sources")
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Colors.textSubtle)

            HStack(spacing: 6) {
                sourceChip(
                    label: "Local only",
                    isOn: !webEnabled
                ) {
                    webEnabled = false
                }

                sourceChip(
                    label: "Web allowed",
                    isOn: webEnabled
                ) {
                    webEnabled = true
                }
            }
        }
    }

    private func sourceChip(
        label: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isOn
                              ? StudioTheme.Colors.accentSoft
                              : StudioTheme.Colors.surface1)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isOn
                            ? StudioTheme.Colors.accent
                            : StudioTheme.Colors.borderSoft,
                            lineWidth: isOn ? 1.3 : 1
                        )
                )
                .foregroundStyle(
                    isOn
                    ? StudioTheme.Colors.textPrimary
                    : StudioTheme.Colors.textSecondary
                )
        }
        .buttonStyle(.plain)
    }
}
