import Foundation
import Combine
import SwiftUI

final class WorkspaceViewModel: ObservableObject {
    @Published var store: WorkspaceStore
    @Published var selectedProjectID: Project.ID?
    @Published var selectedTrackID: Track.ID?
    @Published var selectedSceneID: Scene.ID?

    // Shell coordination
    @Published var currentShellMode: ShellMode = .atlas
    var switchToShell: ((ShellMode) -> Void)?

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

// MARK: - Command Space

extension WorkspaceViewModel {
    func goToConsole() {
        currentShellMode = .console
        switchToShell?(.console)
    }

    func goToStudio() {
        currentShellMode = .studio
        switchToShell?(.studio)
    }

    func goToAtlas() {
        currentShellMode = .atlas
        switchToShell?(.atlas)
    }

    func commandSpaceItems(for query: String) -> [CommandSpaceItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var candidates: [(CommandSpaceItem, Date?)] = []

        // Sessions
        for session in consoleSessions {
            let subtitle = session.rootBlock?.displayPath ?? session.messages.last?.text
            let item = CommandSpaceItem(
                id: session.id,
                kind: .session,
                title: session.title,
                subtitle: subtitle,
                iconName: "bubble.left.and.text.bubble.fill",
                typeLabel: "SESSION",
                payload: .session(id: session.id)
            )
            candidates.append((item, session.lastUsedAt))
        }

        // Projects, tracks, scenes
        for project in store.allProjects {
            let projectItem = CommandSpaceItem(
                id: project.id,
                kind: .project,
                title: project.name,
                subtitle: nil,
                iconName: "folder.fill",
                typeLabel: "PROJECT",
                payload: .project(id: project.id)
            )
            candidates.append((projectItem, nil))

            for trackID in project.tracks {
                guard let track = store.track(id: trackID) else { continue }

                let trackItem = CommandSpaceItem(
                    id: track.id,
                    kind: .track,
                    title: track.name,
                    subtitle: project.name,
                    iconName: "rectangle.3.offgrid.bubble.left.fill",
                    typeLabel: "TRACK",
                    payload: .track(projectID: project.id, trackID: track.id)
                )
                candidates.append((trackItem, track.lastOpenedSceneID.flatMap { store.scene(id: $0)?.updatedAt }))

                for sceneID in track.scenes {
                    guard let scene = store.scene(id: sceneID) else { continue }
                    let subtitle = "\(track.name) · \(project.name)"
                    let sceneItem = CommandSpaceItem(
                        id: scene.id,
                        kind: .scene,
                        title: scene.title,
                        subtitle: subtitle,
                        iconName: "square.stack.3d.down.right.fill",
                        typeLabel: "SCENE",
                        payload: .scene(projectID: project.id, trackID: track.id, sceneID: scene.id)
                    )
                    candidates.append((sceneItem, scene.updatedAt))
                }
            }
        }

        // Canonical blocks
        let canonicalBlocks = store.allBlocksSortedByUpdatedAtDescending().filter { $0.isCanonical }
        for block in canonicalBlocks {
            guard let scene = store.scene(id: block.sceneID),
                  let track = store.track(id: scene.trackID),
                  let project = store.project(id: track.projectID) else { continue }

            let subtitle = "\(project.name) ▸ \(track.name) ▸ \(scene.title)"
            let item = CommandSpaceItem(
                id: block.id,
                kind: .block,
                title: block.title,
                subtitle: subtitle,
                iconName: "doc.text.fill",
                typeLabel: "BLOCK",
                payload: .block(id: block.id)
            )
            candidates.append((item, block.updatedAt))
        }

        // Actions
        let actions: [CommandSpaceItem] = [
            CommandSpaceItem(
                id: UUID(),
                kind: .action,
                title: "New Session",
                subtitle: "Create a fresh console session",
                iconName: "plus.bubble.fill",
                typeLabel: "ACTION",
                payload: .newSession
            ),
            CommandSpaceItem(
                id: UUID(),
                kind: .action,
                title: "New Project",
                subtitle: "Create a new project",
                iconName: "plus.square.on.square",
                typeLabel: "ACTION",
                payload: .newProject
            ),
            CommandSpaceItem(
                id: UUID(),
                kind: .action,
                title: "New Track",
                subtitle: "In the current project",
                iconName: "plus.rectangle.on.rectangle",
                typeLabel: "ACTION",
                payload: .newTrack(projectID: selectedProjectID)
            ),
            CommandSpaceItem(
                id: UUID(),
                kind: .action,
                title: "New Scene",
                subtitle: "In the current track",
                iconName: "plus.square.stack",
                typeLabel: "ACTION",
                payload: .newScene(projectID: selectedProjectID, trackID: selectedTrackID)
            )
        ]
        actions.forEach { candidates.append(($0, nil)) }

        if trimmed.isEmpty {
            return recentItems(from: candidates)
        }

        let filtered: [(CommandSpaceItem, Date?)]
        var searchTerm = trimmed
        if trimmed.hasPrefix(">") {
            let commandQuery = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
            searchTerm = String(commandQuery)
            let q = commandQuery.lowercased()
            filtered = candidates.filter { item, _ in
                guard item.kind == .action else { return false }
                if q.isEmpty { return true }
                let titleLC = item.title.lowercased()
                let subtitleLC = item.subtitle?.lowercased() ?? ""
                return titleLC.contains(q) || subtitleLC.contains(q)
            }
        } else {
            filtered = candidates
        }

        return rankCandidates(filtered, query: searchTerm)
    }

    private func recentItems(from candidates: [(CommandSpaceItem, Date?)]) -> [CommandSpaceItem] {
        var recents: [(CommandSpaceItem, Date?)] = []

        let sessions = consoleSessions.sorted { $0.lastUsedAt > $1.lastUsedAt }
        for session in sessions.prefix(3) {
            if let match = candidates.first(where: { $0.0.id == session.id }) {
                recents.append(match)
            }
        }

        let blocks = store.allBlocksSortedByUpdatedAtDescending().filter { $0.isCanonical }
        for block in blocks.prefix(3) {
            if let match = candidates.first(where: { $0.0.id == block.id }) {
                recents.append(match)
            }
        }

        if let sceneID = selectedSceneID,
           let match = candidates.first(where: { $0.0.id == sceneID }) {
            recents.insert(match, at: 0)
        }

        return rankCandidates(recents, query: "")
    }

    private func rankCandidates(_ candidates: [(CommandSpaceItem, Date?)], query: String) -> [CommandSpaceItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let scored = candidates.map { (item, recency) -> (CommandSpaceItem, Double) in
            var score: Double = 0
            let titleLC = item.title.lowercased()
            let subtitleLC = item.subtitle?.lowercased() ?? ""

            if !q.isEmpty {
                if titleLC.hasPrefix(q) {
                    score += 5.0
                } else if titleLC.contains(q) {
                    score += 3.0
                }

                if !subtitleLC.isEmpty {
                    if subtitleLC.hasPrefix(q) {
                        score += 2.0
                    } else if subtitleLC.contains(q) {
                        score += 1.0
                    }
                }
            }

            if let recency {
                score += recencyBoost(recency)
            }

            switch item.kind {
            case .session, .scene:
                score += 0.7
            case .block:
                score += 0.5
            case .project, .track:
                score += 0.3
            case .action:
                score += 0.4
            }

            return (item, score)
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.title < rhs.0.title
                }
                return lhs.1 > rhs.1
            }
            .map { $0.0 }
    }

    private func recencyBoost(_ date: Date) -> Double {
        let interval = Date().timeIntervalSince(date)
        let days = interval / 86_400
        let clamped = max(0.0, min(days, 7.0))
        return 1.0 - (clamped / 7.0)
    }

    func performCommandSpaceItem(_ item: CommandSpaceItem) {
        switch item.payload {
        case .session(let id):
            if consoleSessions.contains(where: { $0.id == id }) {
                selectedSessionID = id
                touchConsoleSession(id)
                goToConsole()
            }

        case .project(let id):
            if let project = store.project(id: id) {
                goToStudio()
                select(project: project)
            }

        case .track(let projectID, let trackID):
            if let project = store.project(id: projectID),
               let track = store.track(id: trackID) {
                goToStudio()
                select(project: project)
                select(track: track)
            }

        case .scene(let projectID, let trackID, let sceneID):
            if let project = store.project(id: projectID),
               let track = store.track(id: trackID),
               let scene = store.scene(id: sceneID) {
                goToStudio()
                select(project: project)
                select(track: track)
                select(scene: scene)
            }

        case .block(let id):
            guard let block = store.blocks[id],
                  let scene = store.scene(id: block.sceneID),
                  let track = store.track(id: scene.trackID),
                  let project = store.project(id: track.projectID) else { return }

            if currentShellMode == .console {
                let session = openConsole(for: block, project: project, track: track, scene: scene)
                touchConsoleSession(session.id)
                goToConsole()
            } else {
                select(project: project)
                select(track: track)
                select(scene: scene)
                goToStudio()
            }

        case .newSession:
            let session = newConsoleSession()
            touchConsoleSession(session.id)
            goToConsole()
            isCommandSpaceVisible = false

        case .newProject:
            let project = createProject()
            goToStudio()
            select(project: project)
            isCommandSpaceVisible = false

        case .newTrack(let projectID):
            let targetProjectID = projectID ?? selectedProjectID ?? store.allProjects.first?.id
            guard let track = createTrack(in: targetProjectID) else { return }
            if let project = store.project(id: track.projectID) {
                goToStudio()
                select(project: project)
                select(track: track)
            }
            isCommandSpaceVisible = false

        case .newScene(let projectID, let trackID):
            let resolvedTrackID: Track.ID? = {
                if let trackID { return trackID }
                if let projectID = projectID,
                   let project = store.project(id: projectID),
                   let firstTrack = project.tracks.first,
                   let track = store.track(id: firstTrack) {
                    return track.id
                }
                return selectedTrackID
            }()

            guard let scene = resolvedTrackID.flatMap({ createScene(in: $0) }) else { return }
            if let track = store.track(id: scene.trackID),
               let project = store.project(id: track.projectID) {
                goToStudio()
                select(project: project)
                select(track: track)
                select(scene: scene)
            }
            isCommandSpaceVisible = false
        }
    }

    @discardableResult
    private func createProject(name: String? = nil) -> Project {
        let index = store.allProjects.count + 1
        var project = Project(name: name ?? "Project \(index)")

        store.update(project: project)

        if let track = createTrack(in: project.id, name: "Track 1") {
            project.tracks = [track.id]
            project.lastOpenedTrackID = track.id
            store.update(project: project)
        }

        return project
    }

    @discardableResult
    private func createTrack(in projectID: Project.ID?, name: String? = nil) -> Track? {
        guard var project = store.project(id: projectID ?? selectedProjectID) ?? store.allProjects.first else {
            return nil
        }

        let index = project.tracks.count + 1
        let track = Track(projectID: project.id, name: name ?? "Track \(index)")

        project.tracks.append(track.id)
        project.lastOpenedTrackID = track.id
        store.update(track: track)
        store.update(project: project)

        if let scene = createScene(in: track.id, title: "Scene 1") {
            project.lastOpenedTrackID = track.id
            store.update(project: project)
            select(project: project)
            select(track: track)
            select(scene: scene)
        }

        return store.track(id: track.id)
    }

    @discardableResult
    private func createScene(in trackID: Track.ID, title: String? = nil) -> Scene? {
        guard var track = store.track(id: trackID) else { return nil }
        let index = track.scenes.count + 1
        let scene = Scene(trackID: track.id, title: title ?? "Scene \(index)")

        track.scenes.append(scene.id)
        track.lastOpenedSceneID = scene.id
        store.update(scene: scene)
        store.update(track: track)

        return store.scene(id: scene.id)
    }
}
