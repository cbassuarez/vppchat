import Foundation

// MARK: - Core Models

struct Folder: Identifiable, Hashable {
    var id: UUID
    var name: String
    var isPinned: Bool
    var sessions: [Session.ID]
}

struct Session: Identifiable, Hashable {
    var id: UUID
    var name: String
    var folderID: Folder.ID?
    var isPinned: Bool
    var locus: String?
    var createdAt: Date
    var updatedAt: Date
    var messages: [Message]

    // 🔹 Sprint 2: per-session LLM configuration
    var modelID: String = SessionDefaults.defaultModelID
    var temperature: Double = SessionDefaults.defaultTemperature
    var contextStrategy: LLMContextStrategy = SessionDefaults.defaultContextStrategy

}

struct Message: Identifiable, Hashable {
    var id: UUID
    var isUser: Bool
    var timestamp: Date
    var body: String
    var tag: VppTag
    var cycleIndex: Int
    var assumptions: Int
    var sources: VppSources
    var sourcesTable: [VppSourceRef] = []
    var locus: String?
    var isValidVpp: Bool
    var validationIssues: [String]
}

struct DocumentRef: Identifiable, Hashable {
    var id: UUID
    var sessionID: Session.ID
    var title: String
    var summary: String
    var messageIDs: [Message.ID]
}
