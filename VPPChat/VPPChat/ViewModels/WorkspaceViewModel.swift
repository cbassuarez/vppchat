import Foundation
import Combine
import SwiftUI

final class WorkspaceViewModel: ObservableObject {
    @Published var store: WorkspaceStore
    @Published var selectedProjectID: Project.ID?
    @Published var selectedTrackID: Track.ID?
    @Published var selectedSceneID: Scene.ID?

    // MARK: - Console sessions

    @Published var consoleSessions: [ConsoleSession] = []
    @Published var selectedSessionID: ConsoleSession.ID?

    var selectedConsoleSession: ConsoleSession? {
        get {
            guard let id = selectedSessionID else { return nil }
            return consoleSessions.first(where: { $0.id == id })
        }
        set {
            guard let newValue = newValue else { return }
            if let idx = consoleSessions.firstIndex(where: { $0.id == newValue.id }) {
                consoleSessions[idx] = newValue
            } else {
                consoleSessions.insert(newValue, at: 0)
            }
            selectedSessionID = newValue.id
        }
    }

    @Published var isCommandSpaceVisible: Bool = false
    @Published var vppRuntime: VppRuntime

    private var cancellables: Set<AnyCancellable> = []

    init(store: WorkspaceStore = WorkspaceStore(), runtime: VppRuntime = VppRuntime(state: .default)) {
        self.store = store
        self.vppRuntime = runtime

        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        if let project = store.allProjects.first {
            selectedProjectID = project.id
            if let trackID = project.tracks.first,
               let track = store.track(id: trackID),
               let sceneID = track.lastOpenedSceneID ?? track.scenes.first {
                selectedTrackID = track.id
                selectedSceneID = sceneID
            }
        }
    }

    // MARK: - Console session lifecycle

    /// Ensure there is at least one console session and that selectedSessionID is set.
    func ensureDefaultConsoleSession() {
        if consoleSessions.isEmpty {
            let session = ConsoleSession(title: "Session 1")
            consoleSessions = [session]
            selectedSessionID = session.id
        } else if selectedSessionID == nil {
            selectedSessionID = consoleSessions.first?.id
        }
    }

    /// Create a new console session (optionally linked to a root block) and select it.
    @discardableResult
    func newConsoleSession(
        title: String? = nil,
        rootBlock: LinkedBlockPath? = nil
    ) -> ConsoleSession {
        let index = consoleSessions.count + 1
        let session = ConsoleSession(
            title: title ?? "Session \(index)",
            rootBlock: rootBlock
        )

        // Most recent first
        consoleSessions.insert(session, at: 0)
        selectedSessionID = session.id
        return session
    }

    /// Update last-used timestamp when a session becomes active.
    func touchConsoleSession(_ id: ConsoleSession.ID) {
        guard let idx = consoleSessions.firstIndex(where: { $0.id == id }) else { return }
        consoleSessions[idx].lastUsedAt = Date()
    }

    // MARK: - Console ↔ Studio / Atlas navigation

    /// Open or create a console session "about" a given block.
    /// Call this from Studio or Atlas when the user chooses "Open in Console" / "Send to Console".
    @discardableResult
    func openConsole(
        for block: Block,
        project: Project,
        track: Track,
        scene: Scene
    ) -> ConsoleSession {
        let path = LinkedBlockPath(
            projectID: project.id,
            trackID: track.id,
            sceneID: scene.id,
            blockID: block.id,
            displayPath: "\(project.name) ▸ \(track.name) ▸ \(scene.title)"
        )

        // 1. If a session is already rooted at this block, reuse it.
        if let existing = consoleSessions.first(where: {
            $0.rootBlock?.blockID == path.blockID
        }) {
            touchConsoleSession(existing.id)
            selectedSessionID = existing.id
            return existing
        }

        // 2. Otherwise, create a fresh session, using the block title as label.
        let title = block.title.isEmpty ? project.name : block.title
        let session = newConsoleSession(title: title, rootBlock: path)
        return session
    }

    struct SaveBlockSelection {
        var project: Project
        var track: Track
        var scene: Scene
        var title: String
        var isCanonical: Bool
    }

    /// Persist a new Block derived from a console message, and attach a breadcrumb.
    func saveBlock(
        from message: ConsoleMessage,
        in sessionID: ConsoleSession.ID,
        selection: SaveBlockSelection
    ) {
        let newBlock = Block(
            sceneID: selection.scene.id,
            kind: .document,
            title: selection.title,
            subtitle: nil,
            messages: [],
            documentText: message.text,
            isCanonical: selection.isCanonical
        )

        store.add(block: newBlock)

        let link = LinkedBlockPath(
            projectID: selection.project.id,
            trackID: selection.track.id,
            sceneID: selection.scene.id,
            blockID: newBlock.id,
            displayPath: "\(selection.project.name) ▸ \(selection.track.name) ▸ \(selection.scene.title)"
        )

        guard let sIndex = consoleSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        guard let mIndex = consoleSessions[sIndex].messages.firstIndex(where: { $0.id == message.id }) else { return }

        consoleSessions[sIndex].messages[mIndex].linkedBlock = link
    }

    /// Navigate Studio selection to the given LinkedBlockPath.
    /// Hook this into the "Filed in: ..." breadcrumb tap.
    func navigateToBlock(with link: LinkedBlockPath) {
        selectedProjectID = link.projectID
        selectedTrackID = link.trackID
        selectedSceneID = link.sceneID
    }

    var selectedProject: Project? {
        store.project(id: selectedProjectID)
    }

    var selectedTrack: Track? {
        store.track(id: selectedTrackID)
    }

    var selectedScene: Scene? {
        store.scene(id: selectedSceneID)
    }

    func select(project: Project) {
        selectedProjectID = project.id
        if let trackID = project.lastOpenedTrackID ?? project.tracks.first,
           let track = store.track(id: trackID) {
            select(track: track)
        }
    }

    func select(track: Track) {
        selectedTrackID = track.id
        if let sceneID = track.lastOpenedSceneID ?? track.scenes.first,
           let scene = store.scene(id: sceneID) {
            select(scene: scene)
        }
    }

    func select(scene: Scene) {
        selectedSceneID = scene.id
    }

    func select(block: Block) {
        guard let scene = store.scene(id: block.sceneID),
              let track = store.track(id: scene.trackID),
              let project = store.project(id: track.projectID) else {
            return
        }

        selectedProjectID = project.id
        selectedTrackID = track.id
        selectedSceneID = scene.id
    }
}
