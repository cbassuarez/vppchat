import Foundation

enum CommandSpaceItemKind: Hashable {
    case session
    case project
    case track
    case scene
    case block
    case action
}

struct CommandSpaceItem: Identifiable, Hashable {
    let id: UUID
    let kind: CommandSpaceItemKind
    let title: String
    let subtitle: String?
    let iconName: String
    let typeLabel: String

    enum Payload: Hashable {
        case session(id: ConsoleSession.ID)
        case project(id: Project.ID)
        case track(projectID: Project.ID, trackID: Track.ID)
        case scene(projectID: Project.ID, trackID: Track.ID, sceneID: Scene.ID)
        case block(id: Block.ID)

        case newSession
        case newProject
        case newTrack(projectID: Project.ID?)
        case newScene(projectID: Project.ID?, trackID: Track.ID?)
    }

    let payload: Payload
}
