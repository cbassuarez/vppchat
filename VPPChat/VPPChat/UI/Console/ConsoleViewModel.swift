import Foundation
import Combine

final class ConsoleViewModel: ObservableObject {
    @Published var session: ConsoleSession

    init(session: ConsoleSession = ConsoleSession()) {
        self.session = session
    }

    var requestStatus: RequestStatus {
        get { session.requestStatus }
        set { session.requestStatus = newValue }
    }

    var messages: [ConsoleMessage] {
        get { session.messages }
        set { session.messages = newValue }
    }
    private var hasPendingAssistant: Bool {
           messages.contains { $0.role == .assistant && $0.state.isPending }
       }

       private var lastUserMessage: ConsoleMessage? {
           messages.last { $0.role == .user }
       }
    // 🔹 Sprint 2 – expose LLM config

    var modelID: String {
        get { session.modelID }
        set { session.modelID = newValue }
    }

    var temperature: Double {
        get { session.temperature }
        set { session.temperature = min(1.0, max(0.0, newValue)) }
    }

    var contextStrategy: LLMContextStrategy {
        get { session.contextStrategy }
        set { session.contextStrategy = newValue }
    }

    // MARK: - Sending pipeline

    func appendUserMessage(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let msg = ConsoleMessage(
            role: .user,
            text: trimmed,
            state: .normal
        )

        var updated = messages
        updated.append(msg)
        messages = updated
    }

    func beginAssistantPlaceholder(modelLabel: String) {
        // Do not create multiple pending assistant messages.
        guard !hasPendingAssistant else { return }

        let placeholder = ConsoleMessage(
            role: .assistant,
            text: "",
            state: .pending
        )

        var updated = messages
        updated.append(placeholder)
        messages = updated
        requestStatus = .inFlight(stage: .sending, startedAt: Date())
    }

    /// Complete the pending assistant message as a normal reply.
    func completeAssistantReply(text: String, runtime: VppRuntime) {
        guard let idx = messages.lastIndex(where: { $0.role == .assistant && $0.state.isPending }) else {
            // No pending placeholder; nothing to complete.
            return
        }

        var updated = messages
        var reply = updated[idx]
        reply.text = text

        // Run VPP validation on the full reply text.
        let validation = runtime.validateAssistantReply(text)
        reply.vppValidation = validation
        reply.state = .normal

        updated[idx] = reply
        messages = updated
        requestStatus = .idle
    }

    /// Mark the pending assistant message as an error with a reason.
    func failAssistantReply(reason: String?) {
        guard let idx = messages.lastIndex(where: { $0.role == .assistant && $0.state.isPending }) else {
            return
        }

        var updated = messages
        var errorMsg = updated[idx]
        errorMsg.state = .error(message: reason ?? "Network error")
        updated[idx] = errorMsg
        messages = updated

        requestStatus = .error(message: reason)
    }

    /// Retry by replaying the last user message, if available.
    func retryLastUser(sendHandler: (String) -> Void) {
        guard let lastUser = lastUserMessage else { return }
        sendHandler(lastUser.text)
    }
}
