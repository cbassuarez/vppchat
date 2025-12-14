import Foundation

enum ConsoleMessageRole: String, Codable, Hashable {
    case user
    case assistant
    case system
}

enum ConsoleMessageState: Equatable, Codable {
    case normal
    case pending
    case error(message: String)

    private enum CodingKeys: String, CodingKey { case type, message }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "normal":
            self = .normal
        case "pending":
            self = .pending
        case "error":
            let message = try container.decodeIfPresent(String.self, forKey: .message)
            self = .error(message: message ?? "")
        default:
            self = .normal
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .normal:
            try container.encode("normal", forKey: .type)
        case .pending:
            try container.encode("pending", forKey: .type)
        case .error(let message):
            try container.encode("error", forKey: .type)
            try container.encode(message, forKey: .message)
        }
    }

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

enum RequestStatus: Equatable, Codable {
    case idle
    case inFlight
    case error(message: String?)
}

struct LinkedBlockPath: Codable, Hashable {
    var projectID: Project.ID
    var trackID: Track.ID
    var sceneID: Scene.ID
    var blockID: Block.ID

    /// Preformatted label like "Project ▸ Track ▸ Scene"
    var displayPath: String
}

struct ConsoleMessage: Identifiable, Codable, Hashable {
    let id: UUID
    var role: ConsoleMessageRole
    var text: String
    var createdAt: Date

    /// Optional linkage to a Studio block.
    var linkedBlock: LinkedBlockPath?

    var state: ConsoleMessageState

    /// Optional VPP validation result for assistant messages.
    var vppValidation: VppRuntime.VppValidationResult?

    init(
        id: UUID = UUID(),
        role: ConsoleMessageRole,
        text: String,
        createdAt: Date = Date(),
        linkedBlock: LinkedBlockPath? = nil,
        state: ConsoleMessageState = .normal,
        vppValidation: VppRuntime.VppValidationResult? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.linkedBlock = linkedBlock
        self.state = state
        self.vppValidation = vppValidation
    }
}

struct ConsoleSession: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var createdAt: Date
    var lastUsedAt: Date

    /// Optional "root" block this session was spawned from.
    var rootBlock: LinkedBlockPath?

    /// Messages in this session.
    var messages: [ConsoleMessage]

    var requestStatus: RequestStatus

    init(
        id: UUID = UUID(),
        title: String = "Session",
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        rootBlock: LinkedBlockPath? = nil,
        messages: [ConsoleMessage] = [],
        requestStatus: RequestStatus = .idle
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.rootBlock = rootBlock
        self.messages = messages
        self.requestStatus = requestStatus
    }

    var hasPendingAssistant: Bool {
        messages.contains { $0.role == .assistant && $0.state.isPending }
    }

    var lastUserMessage: ConsoleMessage? {
        messages.last { $0.role == .user }
    }
}
