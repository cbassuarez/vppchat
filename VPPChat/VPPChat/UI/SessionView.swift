import SwiftUI

// SessionView displays a transcript and composer for the selected session.
import SwiftUI

// SessionView displays a transcript and composer for the selected session.
struct SessionView: View {
    @ObservedObject private var appViewModel: AppViewModel
    @EnvironmentObject private var workspace: WorkspaceViewModel

    @StateObject private var viewModel: SessionViewModel
    @State private var assumptions: AssumptionsConfig = .none

    private let session: Session

    init(session: Session, appViewModel: AppViewModel) {
        self.session = session
        self._appViewModel = ObservedObject(initialValue: appViewModel)

        _viewModel = StateObject(
            wrappedValue: SessionViewModel(runtime: appViewModel.runtime)
        )
    }

    // MARK: - Workspace-backed console session

    private var consoleSessionIndex: Int? {
        workspace.consoleSessions.firstIndex(where: { $0.id == session.id })
    }

    private var consoleSession: ConsoleSession? {
        guard let idx = consoleSessionIndex else { return nil }
        return workspace.consoleSessions[idx]
    }

    private var requestStatus: RequestStatus {
        consoleSession?.requestStatus ?? .idle
    }

    private var consoleMessages: [ConsoleMessage] {
        consoleSession?.messages ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            MessageListView(
                sessionID: session.id,
                messages: consoleMessages,
                onRetry: retryLastUser
            )

            ComposerView(
                draft: $viewModel.draftText,
                modifiers: $viewModel.currentModifiers,
                sources: $viewModel.currentSources,
                assumptions: $assumptions,
                runtime: appViewModel.runtime,
                requestStatus: requestStatus,
                sendAction: handleSend,
                tagSelection: viewModel.setTag,
                stepCycle: viewModel.stepCycle,
                resetCycle: viewModel.resetCycle
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .navigationTitle(session.name)
        .background(NoiseBackground())
        .onAppear {
            // Ensure a workspace ConsoleSession exists for this store Session id
                appViewModel.ensureConsoleSessionExists(for: session)
                workspace.selectedSessionID = session.id
        }
        .onChange(of: viewModel.draftText) { _ in
            // Clear error state when the user edits the draft (workspace-backed)
            if case .error = requestStatus,
               let idx = consoleSessionIndex {
                workspace.consoleSessions[idx].requestStatus = .idle
            }
        }
    }

    // MARK: - Sending pipeline (workspace-routed)

    private func handleSend() {
        let trimmed = viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        appViewModel.ensureConsoleSessionExists(for: session)
        workspace.selectedSessionID = session.id   //  make the target explicit
        // build outgoing user text (header + optional --assumptions flag + body)
        let composedText = makeOutgoingUserBody(
            draft: viewModel.draftText,
            runtime: appViewModel.runtime,
            modifiers: viewModel.currentModifiers,
            assumptions: assumptions
        )

        

        // clear composer immediately
        viewModel.draftText = ""


        // ✅ route through WorkspaceViewModel.sendPrompt
        let cfg = WorkspaceViewModel.LLMRequestConfig(
            modelID: consoleSession?.modelID ?? session.modelID,
            temperature: consoleSession?.temperature ?? session.temperature,
            contextStrategy: consoleSession?.contextStrategy ?? session.contextStrategy
        )

        Task { @MainActor in
                await workspace.sendPrompt(composedText, in: session.id, config: cfg)
            }

        // ✅ reset after queueing send
        assumptions = .none
    }

    private func makeOutgoingUserBody(
        draft: String,
        runtime: VppRuntime,
        modifiers: VppModifiers,
        assumptions: AssumptionsConfig
    ) -> String {
        var header = runtime.makeHeader(tag: runtime.state.currentTag, modifiers: modifiers)
        if let flag = assumptions.headerFlag { header += " \(flag)" }
        return header + "\n" + draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func retryLastUser() {
        guard let session = consoleSession else { return }

        if let lastUser = session.messages.last(where: { $0.role == .user })?.text {
            // Strip the leading VPP header line, keep the body as the draft
            viewModel.draftText = stripHeaderLineIfPresent(from: lastUser)
            handleSend()
        }
    }

    private func stripHeaderLineIfPresent(from text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard let first = lines.first else { return text }

        let firstLine = first.trimmingCharacters(in: .whitespacesAndNewlines)
        if firstLine.hasPrefix("!<") {
            // return everything after the first line
            return lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    @MainActor
    private func ensureWorkspaceConsoleSessionSeeded() {
        if workspace.consoleSessions.contains(where: { $0.id == session.id }) { return }

        let seeded = ConsoleSession(
            id: session.id,
            title: session.name,
            createdAt: session.createdAt,
            messages: SessionView.makeConsoleMessages(from: session)
        )

        workspace.consoleSessions.insert(seeded, at: 0)
        workspace.selectedSessionID = seeded.id
    }

    @MainActor
    private func persistLatestAssistantIfAvailable() {
        guard let s = consoleSession else { return }
        guard s.requestStatus == .idle else { return }

        guard let latestAssistant = s.messages.last(where: { $0.role == .assistant }),
              !latestAssistant.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        let validation = appViewModel.runtime.validateAssistantReply(latestAssistant.text)
        persistAssistantMessage(text: latestAssistant.text, validation: validation)
    }
}

// MARK: - Mapping from store Session → ConsoleSession messages

extension SessionView {
    static func makeConsoleMessages(from session: Session) -> [ConsoleMessage] {
        session.messages.map { message in
            ConsoleMessage(
                id: message.id,
                role: message.isUser ? .user : .assistant,
                text: message.body,
                createdAt: message.timestamp,
                state: .normal,
                vppValidation: VppRuntime.VppValidationResult(
                    isValid: message.isValidVpp,
                    issues: message.validationIssues
                ),
                linkedSessionID: session.id
            )
        }
    }

    private func persistUserMessage(text: String) {
        let state = appViewModel.runtime.state

        let message = Message(
            id: UUID(),
            isUser: true,
            timestamp: Date(),
            body: text,
            tag: state.currentTag,
            cycleIndex: state.cycleIndex,
            assumptions: state.assumptions,
            sources: viewModel.currentSources,
            locus: state.locus,
            isValidVpp: true,
            validationIssues: []
        )

        appViewModel.store.appendMessage(message, to: session.id)
    }

    private func persistAssistantMessage(
        text: String,
        validation: VppRuntime.VppValidationResult
    ) {
        let state = appViewModel.runtime.state

        let message = Message(
            id: UUID(),
            isUser: false,
            timestamp: Date(),
            body: text,
            tag: state.currentTag,
            cycleIndex: state.cycleIndex,
            assumptions: state.assumptions,
            sources: viewModel.currentSources,
            locus: state.locus,
            isValidVpp: validation.isValid,
            validationIssues: validation.issues
        )

        appViewModel.store.appendMessage(message, to: session.id)
    }
}

#Preview {
    let appVM = AppViewModel()
    if let session = appVM.store.sessions.first {
        SessionView(session: session, appViewModel: appVM)
    }
}
