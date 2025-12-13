import Foundation
import Combine

final class WorkspaceStore: ObservableObject {
    @Published private(set) var projects: [Project.ID: Project] = [:]
    @Published private(set) var tracks: [Track.ID: Track] = [:]
    @Published private(set) var scenes: [Scene.ID: Scene] = [:]
    @Published private(set) var blocks: [Block.ID: Block] = [:]

    init() {
        seedDemoData()
    }

    var allProjects: [Project] {
        projects.values.sorted { $0.name < $1.name }
    }

    func project(id: Project.ID?) -> Project? {
        guard let id else { return nil }
        return projects[id]
    }

    func track(id: Track.ID?) -> Track? {
        guard let id else { return nil }
        return tracks[id]
    }

    func scene(id: Scene.ID?) -> Scene? {
        guard let id else { return nil }
        return scenes[id]
    }

    func track(for sceneID: Scene.ID) -> Track? {
        guard let scene = scene(id: sceneID) else { return nil }
        return track(id: scene.trackID)
    }

    func project(for trackID: Track.ID) -> Project? {
        guard let track = track(id: trackID) else { return nil }
        return project(id: track.projectID)
    }

    func project(for block: Block) -> Project? {
        guard let track = track(for: block.sceneID) else { return nil }
        return project(id: track.projectID)
    }

    func blocks(in scene: Scene) -> [Block] {
        blocks.values
            .filter { $0.sceneID == scene.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func update(project: Project) {
        projects[project.id] = project
    }

    func update(track: Track) {
        tracks[track.id] = track
    }

    func update(scene: Scene) {
        scenes[scene.id] = scene
    }

    func add(block: Block) {
        blocks[block.id] = block
    }

    private func seedDemoData() {
        var project = Project(name: "GlassGPT Export")
        var track = Track(projectID: project.id, name: "Workspace Alpha")
        var scene = Scene(trackID: track.id, title: "Initial Draft", summary: "First export brainstorm")

        let initialMessage = Message(
            id: UUID(),
            isUser: true,
            timestamp: .now,
            body: "Let's explore how to export VPP transcripts into a glassy Studio UI.",
            tag: .g,
            cycleIndex: 1,
            assumptions: 0,
            sources: .none,
            locus: "Studio",
            isValidVpp: true,
            validationIssues: []
        )

        let block = Block(
            sceneID: scene.id,
            kind: BlockKind.conversation,
            title: "Initial export brainstorm",
            subtitle: "G_1 · 0 assumptions · DMOSH-ENGINE",
            messages: [initialMessage],
            isCanonical: true,
            createdAt: .now,
            updatedAt: .now
        )

        project.tracks = [track.id]
        project.lastOpenedTrackID = track.id

        track.scenes = [scene.id]
        track.lastOpenedSceneID = scene.id

        projects[project.id] = project
        tracks[track.id] = track
        scenes[scene.id] = scene
        blocks[block.id] = block
    }

    func allBlocksSortedByUpdatedAtDescending() -> [Block] {
        blocks.values.sorted { $0.updatedAt > $1.updatedAt }
    }
}
