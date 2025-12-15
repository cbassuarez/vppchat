import SwiftUI

struct ConsoleShellView: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    @EnvironmentObject private var appViewModel: AppViewModel
    var body: some View {
        HStack(spacing: 16) {
            ConsoleSessionSidebar()
                .environmentObject(workspace)
                .frame(width: 260)

            if let selected = workspace.selectedConsoleSession {
                HStack(spacing: 0) {
                    ConsoleSessionView(session: selected)
                        .environmentObject(workspace)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    ConsoleSessionInspectorView(
                        modelID: sessionBinding(keyPath: \ConsoleSession.modelID, default: SessionDefaults.defaultModelID),
                        temperature: sessionBinding(keyPath: \ConsoleSession.temperature, default: SessionDefaults.defaultTemperature),
                        contextStrategy: sessionBinding(keyPath: \ConsoleSession.contextStrategy, default: SessionDefaults.defaultContextStrategy)
                    )
                    .frame(width: 260)
                    .padding(.leading, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .panelBackground()
            } else {
                consolePlaceholder
            }
        }
        .onAppear {
            appViewModel.ensureDefaultSession()
        }
    }

    private func sessionBinding<T>(keyPath: WritableKeyPath<ConsoleSession, T>, default defaultValue: T) -> Binding<T> {
        Binding(
            get: { workspace.selectedConsoleSession?[keyPath: keyPath] ?? defaultValue },
            set: { newValue in
                guard var session = workspace.selectedConsoleSession else { return }
                session[keyPath: keyPath] = newValue
                workspace.selectedConsoleSession = session
            }
        )
    }

    private var consolePlaceholder: some View {
        VStack(spacing: 8) {
            Text("No session selected")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("Create or select a session in the sidebar to begin.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .panelBackground()
    }

}

// MARK: - Sidebar

private struct ConsoleSessionSidebar: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    @EnvironmentObject private var appViewModel: AppViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Sessions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
                Button {
                    appViewModel.createNewSession(in: appViewModel.selectedFolder)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.plain)
            }

            List(selection: $workspace.selectedSessionID) {
                ForEach(workspace.consoleSessions) { session in
                    Text(session.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .tag(session.id as ConsoleSession.ID?)
                        .onTapGesture {
                            workspace.selectedSessionID = session.id
                            workspace.touchConsoleSession(session.id)
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.surface2)
        }
        .padding(12)
        .panelBackground()
    }
}

// MARK: - Main session view

private struct ConsoleSessionView: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    @EnvironmentObject private var llmConfig: LLMConfigStore
    @FocusState private var composerFocused: Bool
    @State private var lastComposerFocusToken: Int = 0
    @State private var draftText: String = ""
    @State private var modifiers: VppModifiers = VppModifiers()
    @State private var sources: VppSources = .none
    @State private var assumptions: AssumptionsConfig = .none

    let session: ConsoleSession

    private var currentMessages: [ConsoleMessage] {
        workspace.selectedConsoleSession?.messages ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            MessageListView(
                sessionID: session.id,
                messages: currentMessages,
                onRetry: nil
            )

            ComposerView(
                draft: $draftText,
                modifiers: $modifiers,
                sources: $sources,
                assumptions: $assumptions,
                runtime: workspace.vppRuntime,
                requestStatus: workspace.selectedConsoleSession?.requestStatus ?? .idle,
                sendAction: handleSend,
                tagSelection: { workspace.vppRuntime.setTag($0) },
                stepCycle: { workspace.vppRuntime.nextInCycle() },
                resetCycle: { workspace.vppRuntime.newCycle() },
                focusBinding: $composerFocused
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .navigationTitle(session.title)
        .background(AppTheme.Colors.surface2)
        .onReceive(workspace.$focusConsoleComposerToken) { token in
            guard token != lastComposerFocusToken else { return }
            lastComposerFocusToken = token
            composerFocused = true
        }
    }

    private func handleSend() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let header = workspace.vppRuntime.makeHeader(
            tag: workspace.vppRuntime.state.currentTag,
            modifiers: modifiers
        )
        let composedText = "\(header)\n\(trimmed)"

        draftText = ""

        let config = WorkspaceViewModel.LLMRequestConfig(
            modelID: llmConfig.defaultModelID,
            temperature: llmConfig.defaultTemperature,
            contextStrategy: llmConfig.defaultContextStrategy
        )

        Task {
            await workspace.sendPrompt(composedText, in: session.id, config: config)
        }
    }
}
