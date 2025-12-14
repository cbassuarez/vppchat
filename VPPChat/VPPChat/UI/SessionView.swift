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

        let seededConsoleSession = ConsoleSession(
            id: session.id,
            title: session.name,
            createdAt: session.createdAt,
            messages: SessionView.makeConsoleMessages(from: session)
        )

        _consoleViewModel = StateObject(wrappedValue: ConsoleViewModel(session: seededConsoleSession))
        _viewModel = StateObject(wrappedValue: SessionViewModel(
            sessionID: session.id,
            store: appViewModel.store,
            runtime: appViewModel.runtime,
            llmClient: appViewModel.llmClient
        ))
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
                sendPhase: sendPhase,
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
            if case .error = consoleViewModel.requestStatus {
                consoleViewModel.requestStatus = .idle
            }
        }
    }

    private var sendPhase: SendPhase {
        let trimmedDraft = viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch consoleViewModel.requestStatus {
        case .inFlight:
            return .sending
        case .error:
            return .error
        case .idle:
            return trimmedDraft.isEmpty ? .idleDisabled : .idleReady
        }
    }

    private func handleSend() {
        let trimmed = viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let header = appViewModel.runtime.makeHeader(tag: appViewModel.runtime.state.currentTag, modifiers: viewModel.currentModifiers)
        let composedText = "\(header)\n\(trimmed)"

        consoleViewModel.appendUserMessage(text: trimmed)
        persistUserMessage(text: composedText)

        viewModel.draftText = ""

        consoleViewModel.beginAssistantPlaceholder(modelLabel: "5.1-thinking (stub)")

        appViewModel.llmClient.sendMessage(header: header, body: trimmed) { result in
            switch result {
            case .success(let text):
                let validation = appViewModel.runtime.validateAssistantReply(text)
                consoleViewModel.completeAssistantReply(text: text, runtime: appViewModel.runtime)
                persistAssistantMessage(text: text, validation: validation)
            case .failure(let error):
                consoleViewModel.failAssistantReply(reason: error.localizedDescription)
            }
        }
    }

    private func retryLastUser() {
        consoleViewModel.retryLastUser { lastText in
            viewModel.draftText = lastText
            handleSend()
        }
    }
}

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
        let message = Message(
            id: UUID(),
            isUser: true,
            timestamp: Date(),
            body: text,
            tag: appViewModel.runtime.state.currentTag,
            cycleIndex: appViewModel.runtime.state.cycleIndex,
            assumptions: appViewModel.runtime.state.assumptions,
            sources: viewModel.currentSources,
            locus: appViewModel.runtime.state.locus,
            isValidVpp: true,
            validationIssues: []
        )

        appViewModel.store.appendMessage(message, to: session.id)
    }

    private func persistAssistantMessage(text: String, validation: VppRuntime.VppValidationResult) {
        let message = Message(
            id: UUID(),
            isUser: false,
            timestamp: Date(),
            body: text,
            tag: appViewModel.runtime.state.currentTag,
            cycleIndex: appViewModel.runtime.state.cycleIndex,
            assumptions: appViewModel.runtime.state.assumptions,
            sources: viewModel.currentSources,
            locus: appViewModel.runtime.state.locus,
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
