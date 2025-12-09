import Foundation
import Combine

final class SessionViewModel: ObservableObject {
    @Published var draftText: String = ""
    @Published var currentModifiers: VppModifiers
    @Published var currentSources: VppSources = .none

    private let store: InMemoryStore
    private let runtime: VppRuntime
    private let llmClient: LlmClient
    private let sessionID: Session.ID

    init(sessionID: Session.ID, store: InMemoryStore, runtime: VppRuntime, llmClient: LlmClient) {
        self.sessionID = sessionID
        self.store = store
        self.runtime = runtime
        self.llmClient = llmClient
        self.currentModifiers = VppModifiers()
    }

    func send() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let header = runtime.makeHeader(tag: runtime.state.currentTag, modifiers: currentModifiers)

        let userMessage = Message(
            id: UUID(),
            isUser: true,
            timestamp: Date(),
            body: "\(header)\n\(trimmed)",
            tag: runtime.state.currentTag,
            cycleIndex: runtime.state.cycleIndex,
            assumptions: runtime.state.assumptions,
            sources: currentSources,
            locus: runtime.state.locus,
            isValidVpp: true,
            validationIssues: []
        )
        store.appendMessage(userMessage, to: sessionID)

        llmClient.sendMessage(header: header, body: trimmed) { [weak self] result in
            guard let self else { return }
            let assistantBody: String
            switch result {
            case .success(let text):
                assistantBody = text
            case .failure:
                assistantBody = "<c> Unable to send message.\n\(self.runtime.makeFooter(sources: self.currentSources))"
            }

            let validation = self.runtime.validateAssistantReply(assistantBody)

            let assistantMessage = Message(
                id: UUID(),
                isUser: false,
                timestamp: Date(),
                body: assistantBody,
                tag: self.runtime.state.currentTag,
                cycleIndex: self.runtime.state.cycleIndex,
                assumptions: self.runtime.state.assumptions,
                sources: self.currentSources,
                locus: self.runtime.state.locus,
                isValidVpp: validation.isValid,
                validationIssues: validation.issues
            )
            self.store.appendMessage(assistantMessage, to: self.sessionID)
        }

        draftText = ""
    }

    func setTag(_ tag: VppTag) {
        runtime.setTag(tag)
    }

    func stepCycle() {
        runtime.nextInCycle()
    }

    func resetCycle() {
        runtime.newCycle()
    }
}
