import SwiftUI

struct ConsoleShellView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @EnvironmentObject private var workspace: WorkspaceViewModel

    @State private var draftText: String = ""
    @State private var modifiers = VppModifiers()
    @State private var sources: VppSources = .none

    var body: some View {
        HStack(spacing: 16) {
            sessionsList
                .frame(width: 260)

            if let selected = workspace.selectedConsoleSession {
                VStack(spacing: 0) {
                    MessageListView(messages: selected.messages, sessionID: selected.id, onRetry: retryLastUser)

                    ComposerView(
                        draft: $draftText,
                        modifiers: $modifiers,
                        sources: $sources,
                        runtime: workspace.vppRuntime,
                        sendPhase: sendPhase,
                        sendAction: handleSend,
                        tagSelection: { workspace.vppRuntime.setTag($0) },
                        stepCycle: workspace.vppRuntime.nextInCycle,
                        resetCycle: workspace.vppRuntime.newCycle
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                            .fill(AppTheme.Colors.surface1)

                        RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                            .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                    }
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                )
            } else {
                consolePlaceholder
            }

        }
        .onAppear {
            workspace.ensureDefaultConsoleSession()
        }
        .onChange(of: workspace.selectedSessionID) { newValue in
            if let id = newValue {
                workspace.touchConsoleSession(id)
            }
        }
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
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                    .fill(AppTheme.Colors.surface1)
            }
            .clipShape(
                RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
            )
        )
    }

    private var sessionsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Sessions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
                Button {
                    workspace.newConsoleSession()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
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
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                .fill(AppTheme.Colors.surface2)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                        .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.10), radius: 6, x: 6, y: 6)
        )
    }

    private var sendPhase: SendPhase {
        let trimmedDraft = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        let status = workspace.selectedConsoleSession?.requestStatus ?? .idle

        switch status {
        case .inFlight:
            return .sending
        case .error:
            return .error
        case .idle:
            return trimmedDraft.isEmpty ? .idleDisabled : .idleReady
        }
    }

    private func handleSend() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard var session = workspace.selectedConsoleSession else { return }

        let header = workspace.vppRuntime.makeHeader(tag: workspace.vppRuntime.state.currentTag, modifiers: modifiers)

        let userMessage = ConsoleMessage(
            role: .user,
            text: trimmed,
            state: .normal
        )

        session.messages.append(userMessage)
        session.lastUsedAt = Date()

        let placeholder = ConsoleMessage(
            role: .assistant,
            text: "",
            state: .pending
        )
        session.messages.append(placeholder)
        session.requestStatus = .inFlight

        workspace.selectedConsoleSession = session
        draftText = ""

        appViewModel.llmClient.sendMessage(header: header, body: trimmed) { result in
            DispatchQueue.main.async {
                guard var activeSession = workspace.selectedConsoleSession else { return }
                switch result {
                case .success(let text):
                    if let idx = activeSession.messages.lastIndex(where: { $0.state.isPending }) {
                        var reply = activeSession.messages[idx]
                        reply.text = text
                        let validation = workspace.vppRuntime.validateAssistantReply(text)
                        reply.vppValidation = validation
                        reply.state = .normal
                        activeSession.messages[idx] = reply
                    }
                    activeSession.requestStatus = .idle
                case .failure(let error):
                    if let idx = activeSession.messages.lastIndex(where: { $0.state.isPending }) {
                        var reply = activeSession.messages[idx]
                        reply.state = .error(message: error.localizedDescription)
                        activeSession.messages[idx] = reply
                    }
                    activeSession.requestStatus = .error(message: error.localizedDescription)
                }
                workspace.selectedConsoleSession = activeSession
            }
        }
    }

    private func retryLastUser() {
        guard let lastUser = workspace.selectedConsoleSession?.lastUserMessage else { return }
        draftText = lastUser.text
        handleSend()
    }
}
