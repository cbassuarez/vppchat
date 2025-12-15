import Foundation
import Combine

final class WorkspaceStore: ObservableObject {
    // MARK: - Canonical onboarding
        static let canonicalWelcomeBlockID = UUID(uuidString: "A3B1C7F2-1D6A-4D1A-9C4D-5D2C1E7A9F11")!
        private var gettingStartedProjectName: String { "Getting Started" }
        private var gettingStartedTrackName: String { "Start Here" }
        private var gettingStartedSceneTitle: String { "Welcome" }
    @Published private(set) var projects: [Project.ID: Project] = [:]
    @Published private(set) var tracks: [Track.ID: Track] = [:]
    @Published private(set) var scenes: [Scene.ID: Scene] = [:]
    @Published private(set) var blocks: [Block.ID: Block] = [:]
// MARK: - Block access / mutation
    private func ensurePrimaryChatSceneID() -> Scene.ID {
            if let project = allProjects.first,
               let trackID = project.lastOpenedTrackID ?? project.tracks.first,
               let track = tracks[trackID],
               let sceneID = track.lastOpenedSceneID ?? track.scenes.first {
                return sceneID
            }
            return ensureConsoleSceneID()
        }
    
        @discardableResult
        func ensureWelcomeConversationSeeded() -> Block {
            purgeLegacyWelcomeArtifacts()
            
                    let sceneID = ensureGettingStartedSceneID()
                    let id = Self.canonicalWelcomeBlockID
            
                    let welcomeBody = """
            Welcome to **VPP Studio** 👋
            
            This is the **single canonical Welcome chat** shared across **Console / Studio / Atlas**.
            
            ### How this app is structured
            **Project ▸ Track ▸ Scene ▸ Block**
            - **Conversation blocks** are “sessions” (Console shows the same thing).
            - **Document blocks** are saved notes (from Console “Save block”, etc.).
            
            ### How to talk to the system (VPP)
            Start your message with a tag on line 1:
            - `!<g>` grounding / concept
            - `!<q>` questions
            - `!<o>` outputs / implementation
            - `!<c>` corrections
            
            ### Try this now
            Paste this into Console or Studio and send:
            `!<g>`
            `What are we building, and what should I do next?`
            
            If you ever feel lost: open **Command Space**, search “Welcome”, and jump back here.
            """
            
                    let welcomeAssistant = Message(
                        id: UUID(),
                        isUser: false,
                        timestamp: .now,
                        body: welcomeBody,
                        tag: .g,
                        cycleIndex: 1,
                        assumptions: 0,
                        sources: .none,
                        locus: "Welcome",
                        isValidVpp: true,
                        validationIssues: []
                    )
            
                    if var existing = blocks[id] {
                        // Upsert-in-place (stable ID)
                        existing.sceneID = sceneID
                        existing.kind = .conversation
                        existing.title = "Welcome"
                        existing.subtitle = "G_1 · 0 assumptions · GETTING-STARTED"
                        existing.isCanonical = true
                        existing.messages = [welcomeAssistant]
                        existing.updatedAt = .now
                        blocks[id] = existing
                        return existing
                    }
            
                    let block = Block(
                        id: id,
                        sceneID: sceneID,
                        kind: .conversation,
                        title: "Welcome",
                        subtitle: "G_1 · 0 assumptions · GETTING-STARTED",
                        messages: [welcomeAssistant],
                        documentText: nil,
                        isCanonical: true,
                        createdAt: .now,
                        updatedAt: .now
                    )
                    blocks[id] = block
                    return block
        }
    func block(id: Block.ID?) -> Block? {
        guard let id else { return nil }
        return blocks[id]
    }

    func update(block: Block) {
        objectWillChange.send()
        blocks[block.id] = block
    }

    // MARK: - Console container (Project ▸ Track ▸ Scene)

    private var consoleProjectName: String { "Console" }
    private var consoleTrackName: String { "Sessions" }
    private var consoleSceneTitle: String { "Console Chats" }

    func ensureConsoleSceneID() -> Scene.ID {
        // 1) project
        var project: Project
        if let existing = projects.values.first(where: { $0.name == consoleProjectName }) {
            project = existing
        } else {
            project = Project(name: consoleProjectName)
            projects[project.id] = project
        }

        // 2) track
        var track: Track
        if let existingTrack = project.tracks.compactMap({ tracks[$0] }).first(where: { $0.name == consoleTrackName }) {
            track = existingTrack
        } else {
            track = Track(projectID: project.id, name: consoleTrackName)
            tracks[track.id] = track
            project.tracks.append(track.id)
            project.lastOpenedTrackID = track.id
            projects[project.id] = project
        }

        // 3) scene
        if let existingScene = track.scenes.compactMap({ scenes[$0] }).first(where: { $0.title == consoleSceneTitle }) {
            return existingScene.id
        }

        var scene = Scene(
            trackID: track.id,
            title: consoleSceneTitle,
            summary: "All console conversations"
        )
        scenes[scene.id] = scene
        track.scenes.append(scene.id)
        track.lastOpenedSceneID = scene.id
        tracks[track.id] = track
        return scene.id
    }

    // MARK: - Getting Started container (Project ▸ Track ▸ Scene)
        func ensureGettingStartedSceneID() -> Scene.ID {
            // 1) project
            var project: Project
            if let existing = projects.values.first(where: { $0.name == gettingStartedProjectName }) {
                project = existing
            } else {
                project = Project(name: gettingStartedProjectName)
                projects[project.id] = project
            }
    
            // 2) track
            var track: Track
            if let existingTrack = project.tracks.compactMap({ tracks[$0] }).first(where: { $0.name == gettingStartedTrackName }) {
                track = existingTrack
            } else {
                track = Track(projectID: project.id, name: gettingStartedTrackName)
                tracks[track.id] = track
                project.tracks.append(track.id)
                project.lastOpenedTrackID = track.id
                projects[project.id] = project
            }
    
            // 3) scene
            if let existingScene = track.scenes.compactMap({ scenes[$0] }).first(where: { $0.title == gettingStartedSceneTitle }) {
                return existingScene.id
            }
    
            let scene = Scene(
                trackID: track.id,
                title: gettingStartedSceneTitle,
                summary: "Onboarding and core workflow"
            )
            scenes[scene.id] = scene
            track.scenes.append(scene.id)
            track.lastOpenedSceneID = scene.id
            tracks[track.id] = track
            return scene.id
        }
    
    /// Creates (or returns) a conversation block whose **id is the ConsoleSession UUID**.
    /// This is the parity bridge: ConsoleSession <-> Block (kind: .conversation).
    func ensureConversationBlock(id: Block.ID, title: String, sceneID: Scene.ID? = nil) -> Block {
        if let existing = blocks[id] { return existing }

        let resolvedSceneID = sceneID ?? ensurePrimaryChatSceneID()
        let block = Block(
            id: id,
            sceneID: resolvedSceneID,
            kind: .conversation,
            title: title,
            subtitle: nil,
            messages: [],
            documentText: nil,
            isCanonical: false,
            createdAt: .now,
            updatedAt: .now
        )
        blocks[block.id] = block
        return block
    }
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
        objectWillChange.send()
        blocks[block.id] = block
    }

    private func seedDemoData() {
        // Production seed: single canonical Welcome only
            _ = ensureWelcomeConversationSeeded()
    }

    func allBlocksSortedByUpdatedAtDescending() -> [Block] {
        blocks.values.sorted { $0.updatedAt > $1.updatedAt }
    }
    // MARK: - Migration / purge
        func purgeLegacyWelcomeArtifacts() {
            // 1) Remove the old demo project (seed-only)
            if let demo = projects.values.first(where: { $0.name == "GlassGPT Export" }) {
                // remove tracks + scenes
                for trackID in demo.tracks {
                    if let t = tracks[trackID] {
                        for sceneID in t.scenes { scenes.removeValue(forKey: sceneID) }
                    }
                    tracks.removeValue(forKey: trackID)
                }
                projects.removeValue(forKey: demo.id)
            }

            // 2) Remove the old seeded conversation blocks (but do NOT touch user-made “Welcome”)
            let legacyWelcomeTitles: Set<String> = ["Welcome session", "welcome", "Welcome"]
            let shouldRemoveSeededWelcome: (Block) -> Bool = { b in
                guard b.kind == .conversation else { return false }
                guard legacyWelcomeTitles.contains(b.title) else { return false }
                // Only purge the known seed shape (single assistant line + seed locus),
                // so we don’t delete a user’s real “Welcome” conversation.
                guard b.messages.count == 1, b.messages.first?.isUser == false else { return false }
                guard b.messages.first?.locus == "Welcome" else { return false }
                return b.id != Self.canonicalWelcomeBlockID
            }

            let shouldRemoveSeededInitialExport: (Block) -> Bool = { b in
                guard b.kind == .conversation else { return false }
                guard b.title == "Initial export brainstorm" else { return false }
                // seed-only fingerprint
                return (b.subtitle?.contains("DMOSH-ENGINE") == true) && b.isCanonical
            }

            for (id, b) in blocks where shouldRemoveSeededWelcome(b) || shouldRemoveSeededInitialExport(b) {
                blocks.removeValue(forKey: id)
            }
        }

}
