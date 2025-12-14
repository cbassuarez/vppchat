import SwiftUI

// SessionView displays a transcript and composer for the selected session.
struct SessionView: View {
    @ObservedObject private var appViewModel: AppViewModel
    @StateObject private var viewModel: SessionViewModel
    @StateObject private var consoleViewModel: ConsoleViewModel

    private let session: Session

    init(session: Session, appViewModel: AppViewModel) {
        self.session = session
        self._appViewModel = ObservedObject(initialValue: appViewModel)

        // Seed a ConsoleSession from the persisted Session messages.
        let seededConsoleSession = ConsoleSession(
            id: session.id,
            title: session.name,
            createdAt: session.createdAt,
            messages: SessionView.makeConsoleMessages(from: session)
        )

        _consoleViewModel = StateObject(
            wrappedValue: ConsoleViewModel(session: seededConsoleSession)
        )

        _viewModel = StateObject(
            wrappedValue: SessionViewModel(
                sessionID: session.id,
                store: appViewModel.store,
                runtime: appViewModel.runtime,
                llmClient: appViewModel.llmClient
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            MessageListView(
                messages: consoleViewModel.messages,
                onRetry: retryLastUser
            )

            ComposerView(
                draft: $viewModel.draftText,
                modifiers: $viewModel.currentModifiers,
                sources: $viewModel.currentSources,
                runtime: appViewModel.runtime,
                requestStatus: consoleViewModel.requestStatus,
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
        .onChange(of: viewModel.draftText) { _ in
            // If we were in an error state, editing the draft clears it.
            if case .error = consoleViewModel.requestStatus {
                consoleViewModel.requestStatus = .idle
            }
        }
    }

    // MARK: - Sending pipeline

    private func handleSend() {
        let trimmed = viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let header = appViewModel.runtime.makeHeader(
            tag: appViewModel.runtime.state.currentTag,
            modifiers: viewModel.currentModifiers
        )
        let composedText = "\(header)\n\(trimmed)"

        // Append user message to console + persist it with full VPP header.
        consoleViewModel.appendUserMessage(text: composedText)
        persistUserMessage(text: composedText)

        // Clear composer
        viewModel.draftText = ""

        // Create pending assistant placeholder.
        consoleViewModel.beginAssistantPlaceholder(modelLabel: "5.1-thinking (stub)")

        // NOTE: In Sprint 1 this can be backed by a stub llmClient.
        appViewModel.llmClient.sendMessage(header: header, body: trimmed) { result in
            switch result {
            case .success(let text):
                // Update the pending assistant bubble + VPP validation.
                consoleViewModel.completeAssistantReply(
                    text: text,
                    runtime: appViewModel.runtime
                )

                // Ingest footer to sync tag / cycle / locus from the assistant.
                updateRuntimeFromFooter(in: text)

                // Persist assistant message (with validation mirrored into the store).
                let validation = appViewModel.runtime.validateAssistantReply(text)
                persistAssistantMessage(text: text, validation: validation)

            case .failure(let error):
                consoleViewModel.failAssistantReply(reason: error.localizedDescription)
            }
        }
    }

    private func retryLastUser() {
        consoleViewModel.retryLastUser { lastText in
            // Reuse last user text as current draft and re-send.
            viewModel.draftText = lastText
            handleSend()
        }
    }

    // MARK: - Runtime footer ingestion
    /// Uses the last non-empty line of the assistant's reply as a footer
    /// and feeds it into VppRuntime to keep tag/cycle/locus in sync.
    private func updateRuntimeFromFooter(in text: String) {
        // Simple split on newlines; we don't actually need empty subsequences here
        let lines = text.split(whereSeparator: \.isNewline)

        if let lastLine = lines.last(where: {
            !$0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
        }) {
            appViewModel.runtime.ingestFooterLine(String(lastLine))
        }
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
