import SwiftUI

struct LLMSettingsPanel: View {
    @EnvironmentObject private var llmConfig: LLMConfigStore
    @State private var localKey: String = ""

    private var statusLabel: String {
        switch llmConfig.keyStatus {
        case .notConfigured:
            return "Not configured"
        case .configured:
            return "Configured"
        case .error:
            return "Error"
        }
    }

    private var statusColor: Color {
        switch llmConfig.keyStatus {
        case .notConfigured:
            return AppTheme.Colors.statusMajor
        case .configured:
            return AppTheme.Colors.statusCorrect
        case .error:
            return AppTheme.Colors.exceptionAccent
        }
    }

    private var selectedModel: LLMModelPreset {
        LLMModelCatalog.preset(for: llmConfig.defaultModelID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            apiKeySection
            clientModeSection
            defaultsPreview
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
        .onAppear {
            localKey = llmConfig.apiKey
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(StudioTheme.Colors.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LLM Configuration")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text("Manage your OpenAI key, client mode, and defaults.")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusLabel)
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.Colors.surface1)
            .overlay(
                Capsule()
                    .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
            )
            .clipShape(Capsule())
            .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OpenAI API Key")
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Colors.textSubtle)

            HStack(spacing: 8) {
                SecureField("sk-...", text: $localKey)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppTheme.Colors.surface1)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radii.s)
                            .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                    )

                Button("Save") {
                    llmConfig.apiKey = localKey
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(StudioTheme.Colors.accentSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.s)
                        .stroke(StudioTheme.Colors.accent, lineWidth: 1)
                )
                .foregroundStyle(StudioTheme.Colors.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.s, style: .continuous))
            }

            switch llmConfig.keyStatus {
            case .error(let message):
                Text(message ?? "Invalid key")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.exceptionAccent)
            default:
                Text("Keys are stored in UserDefaults for this sprint.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }

    private var clientModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Client mode")
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Colors.textSubtle)

            HStack(spacing: 8) {
                ForEach(LLMClientMode.allCases) { mode in
                    modeChip(mode)
                }
            }

            Text(llmConfig.clientMode.hint)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    private func modeChip(_ mode: LLMClientMode) -> some View {
        let isSelected = llmConfig.clientMode == mode

        return Button {
            llmConfig.clientMode = mode
        } label: {
            Text(mode.label)
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
                .foregroundStyle(
                    isSelected ? StudioTheme.Colors.textPrimary : AppTheme.Colors.textSecondary
                )
        }
        .buttonStyle(.plain)
    }

    private var defaultsPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Defaults Preview")
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Colors.textSubtle)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Model")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Spacer()
                    Text(selectedModel.label)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                HStack {
                    Text("Temperature")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Spacer()
                    Text(String(format: "%.2f", llmConfig.defaultTemperature))
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                HStack {
                    Text("Context Strategy")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Spacer()
                    Text(llmConfig.defaultContextStrategy.label)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            .padding(12)
            .background(AppTheme.Colors.surface1)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radii.s)
                    .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.s, style: .continuous))

            Text("Adjust these in Studio’s inspector. All new sessions will use these defaults.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }
}
