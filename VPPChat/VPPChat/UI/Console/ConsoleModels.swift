import Foundation

// Console message and session models for the chat surface.
enum ConsoleMessageRole: String, Codable, Equatable {
    case user
    case assistant
    case system
}

enum ConsoleMessageState: Equatable {
    case normal
    case pending
    case error(message: String)

    var isError: Bool {
        if case .error = self { return true }
        return false
    }

    var errorMessage: String? {
        if case let .error(msg) = self { return msg }
        return nil
    }

    var isPending: Bool {
        if case .pending = self { return true }
        return false
    }
}

enum RequestStatus: Equatable {
    case idle
    case inFlight
    case error(message: String?)
}

struct ConsoleMessage: Identifiable, Equatable {
    var id: UUID
    var role: ConsoleMessageRole
    var text: String
    var createdAt: Date

    var state: ConsoleMessageState

    /// Optional VPP validation result for assistant messages.
    var vppValidation: VppRuntime.VppValidationResult?

    /// Reserved for future sprints.
    var linkedBlockID: UUID?
    var linkedSessionID: UUID?

    init(
        id: UUID = UUID(),
        role: ConsoleMessageRole,
        text: String,
        createdAt: Date = Date(),
        state: ConsoleMessageState = .normal,
        vppValidation: VppRuntime.VppValidationResult? = nil,
        linkedBlockID: UUID? = nil,
        linkedSessionID: UUID? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.state = state
        self.vppValidation = vppValidation
        self.linkedBlockID = linkedBlockID
        self.linkedSessionID = linkedSessionID
    }
}

struct ConsoleSession: Identifiable, Equatable {
    var id: UUID
    var title: String
    var createdAt: Date

    var messages: [ConsoleMessage]
    var requestStatus: RequestStatus

    // per-session LLM config
    var modelID: String
    var temperature: Double
    var contextStrategy: LLMContextStrategy

    init(
        id: UUID = UUID(),
        title: String = "Session",
        createdAt: Date = Date(),
        messages: [ConsoleMessage] = [],
        requestStatus: RequestStatus = .idle,
        modelID: String = SessionDefaults.defaultModelID,
        temperature: Double = SessionDefaults.defaultTemperature,
        contextStrategy: LLMContextStrategy = SessionDefaults.defaultContextStrategy
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.messages = messages
        self.requestStatus = requestStatus

        self.modelID = modelID
        self.temperature = min(1.0, max(0.0, temperature))
        self.contextStrategy = contextStrategy
    }

    var hasPendingAssistant: Bool {
        messages.contains { $0.role == .assistant && $0.state.isPending }
    }

    var lastUserMessage: ConsoleMessage? {
        messages.last { $0.role == .user }
    }
}

