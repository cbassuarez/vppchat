import Foundation

// MARK: - Console session + message models

enum ConsoleMessageRole: String, Codable, Hashable {
    case user
    case assistant
    case system
}

struct LinkedBlockPath: Codable, Hashable {
    var projectID: Project.ID
    var trackID: Track.ID
    var sceneID: Scene.ID
    var blockID: Block.ID

    /// Preformatted label like "Project ▸ Topic ▸ Scene"
    var displayPath: String
}

struct ConsoleMessage: Identifiable {
    let id: UUID
    var role: ConsoleMessageRole
    var text: String
    var createdAt: Date
    var sources: VppSources
    var sourcesTable: [VppSourceRef]

    /// Optional linkage to a Studio block.
    var linkedBlock: LinkedBlockPath?

    // Existing console-specific metadata
    var state: ConsoleMessageState
    var vppValidation: VppRuntime.VppValidationResult?
    var linkedSessionID: UUID?

    init(
        id: UUID = UUID(),
        role: ConsoleMessageRole,
        text: String,
        createdAt: Date = Date(),
        linkedBlock: LinkedBlockPath? = nil,
        state: ConsoleMessageState = .normal,
        vppValidation: VppRuntime.VppValidationResult? = nil,
        linkedSessionID: UUID? = nil,
        sources: VppSources = .none,
        sourcesTable: [VppSourceRef] = []
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.linkedBlock = linkedBlock
        self.state = state
        self.vppValidation = vppValidation
        self.linkedSessionID = linkedSessionID
        self.sources = sources
        self.sourcesTable = sourcesTable
    }
}

struct ConsoleSession: Identifiable {
    let id: UUID
    var title: String
    var createdAt: Date
    var lastUsedAt: Date

    /// Optional "root" block this session was spawned from.
    var rootBlock: LinkedBlockPath?

    /// Messages in this session.
    var messages: [ConsoleMessage]

    // Console settings
    var requestStatus: RequestStatus
    var modelID: String
    var temperature: Double
    var contextStrategy: LLMContextStrategy

    init(
        id: UUID = UUID(),
        title: String = "Session",
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        rootBlock: LinkedBlockPath? = nil,
        messages: [ConsoleMessage] = [],
        requestStatus: RequestStatus = .idle,
        modelID: String = SessionDefaults.defaultModelID,
        temperature: Double = SessionDefaults.defaultTemperature,
        contextStrategy: LLMContextStrategy = SessionDefaults.defaultContextStrategy
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.rootBlock = rootBlock
        self.messages = messages
        self.requestStatus = requestStatus
        self.modelID = modelID
        self.temperature = min(1.0, max(0.0, temperature))
        self.contextStrategy = contextStrategy
    }
}
