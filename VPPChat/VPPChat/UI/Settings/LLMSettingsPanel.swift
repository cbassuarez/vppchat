import SwiftUI

struct LLMSettingsPanel: View {
    @EnvironmentObject private var llmConfig: LLMConfigStore
    @State private var localKey: String = ""
    @State private var revealKey: Bool = false
        @State private var didLoad: Bool = false
    
        @State private var showSavedPill: Bool = false
        @State private var saveDebounceTask: Task<Void, Never>? = nil
        @State private var keySaveTask: Task<Void, Never>? = nil
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            apiKeySection
            clientModeSection
            WebRetrievalPolicyRow()
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
            DispatchQueue.main.async { didLoad = true }
        }
        .onChange(of: localKey) { newValue in
                    guard didLoad else { return }
                    keySaveTask?.cancel()
                    keySaveTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        await MainActor.run {
                            llmConfig.apiKey = newValue
                            flashSaved()
                        }
                    }
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

            HStack(spacing: 8) {
                            statusPill
                            if showSavedPill {
                                savedPill
                            }
                        }
        }
    }
    
    private var statusPill: some View {
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
    
        private var savedPill: some View {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                Text("Saved")
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
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OpenAI API Key")
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Colors.textSubtle)

            HStack(spacing: 8) {
                Group {
                                    if revealKey {
                                        TextField("sk-...", text: $localKey)
                                    } else {
                                        SecureField("sk-...", text: $localKey)
                                    }
                                }
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(AppTheme.Colors.surface1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                                )
                
                                Button {
                                    revealKey.toggle()
                                } label: {
                                    Image(systemName: revealKey ? "eye.slash" : "eye")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(AppTheme.Colors.textSecondary)
                                        .frame(width: 30, height: 30)
                                }
                                .buttonStyle(.plain)
                                .background(AppTheme.Colors.surface1)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                                )
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
            flashSaved()
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
}

private extension LLMSettingsPanel {
    func flashSaved() {
        withAnimation(.easeOut(duration: 0.15)) { showSavedPill = true }
        saveDebounceTask?.cancel()
        saveDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.15)) { showSavedPill = false }
            }
        }
    }
}
