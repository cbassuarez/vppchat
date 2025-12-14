import Foundation

enum LLMRole: String, Codable {
    case system
    case user
    case assistant
}

struct LLMMessage: Identifiable, Codable {
    let id: UUID
    let role: LLMRole
    let content: String

    init(id: UUID = UUID(), role: LLMRole, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

struct LLMRequest {
    var modelID: String
    var temperature: Double
    var contextStrategy: LLMContextStrategy
    var messages: [LLMMessage]
}

struct LLMResponse {
    var text: String
}

protocol LLMClient {
    func send(_ request: LLMRequest) async throws -> LLMResponse
}

final class StubLLMClient: LLMClient {
    func send(_ request: LLMRequest) async throws -> LLMResponse {
        let delay = Double.random(in: 0.4...1.2)
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        let lastUser = request.messages.last { $0.role == .user }?.content
        let prefix = "[STUB • \(request.modelID)] "
        let text: String
        if let lastUser, !lastUser.isEmpty {
            text = prefix + "Echo: \(lastUser)"
        } else {
            text = prefix + "No user message in request. (Stubbed reply.)"
        }

        return LLMResponse(text: text)
    }
}

struct LLMClientFactory {
    static func makeClient(config: LLMConfigStore) -> LLMClient {
        // Sprint 6: always return stub regardless of selected mode.
        return StubLLMClient()
    }
}
