import Foundation

enum BlockKind: String, Codable, CaseIterable, Hashable {
    case conversation
    case document
    case reference
}

struct Project: Identifiable, Hashable {
    let id: UUID
    var name: String
    var tracks: [Track.ID]
    var lastOpenedTrackID: Track.ID?
    var isSystem: Bool
    var systemRole: String?
    

    init(id: UUID = UUID(), name: String, isSystem: Bool = false, systemRole: String? = nil, tracks: [Track.ID] = [], lastOpenedTrackID: Track.ID? = nil) {
        self.id = id
        self.name = name
        self.isSystem = isSystem
        self.systemRole = systemRole

        self.tracks = tracks
        self.lastOpenedTrackID = lastOpenedTrackID
    }
}

struct Track: Identifiable, Hashable {
    let id: UUID
    var projectID: Project.ID
    var name: String
    var isSystem: Bool
    var systemRole: String?
    var scenes: [Scene.ID]
    var lastOpenedSceneID: Scene.ID?

    init(id: UUID = UUID(), projectID: Project.ID, name: String, isSystem: Bool = false, systemRole: String? = nil, scenes: [Scene.ID] = [], lastOpenedSceneID: Scene.ID? = nil) {
        self.id = id
        self.projectID = projectID
        self.name = name
        self.isSystem = isSystem
        self.systemRole = systemRole

        self.scenes = scenes
        self.lastOpenedSceneID = lastOpenedSceneID
    }
}

struct Scene: Identifiable, Hashable {
    let id: UUID
    var trackID: Track.ID
    var environmentID: UUID?
    var title: String
    var summary: String?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), trackID: Track.ID, title: String, summary: String? = nil, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.trackID = trackID
        self.title = title
        self.summary = summary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct Block: Identifiable, Hashable {
    let id: UUID
    var sceneID: Scene.ID
    var kind: BlockKind
    var title: String
    var subtitle: String?
    var messages: [Message]
    var documentText: String?
    var isCanonical: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        sceneID: Scene.ID,
        kind: BlockKind,
        title: String,
        subtitle: String? = nil,
        messages: [Message] = [],
        documentText: String? = nil,
        isCanonical: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.sceneID = sceneID
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.messages = messages
        self.documentText = documentText
        self.isCanonical = isCanonical
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func == (lhs: Block, rhs: Block) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
