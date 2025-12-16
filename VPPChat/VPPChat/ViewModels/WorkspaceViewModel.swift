import Foundation
import Combine
import SwiftUI
import AppKit

final class WorkspaceViewModel: ObservableObject {
    private var autoNameTasks: [String: Task<Void, Never>] = [:]
    private var autoNamedKeys: Set<String> = []
    let instanceID = UUID()
    var llmClient: LLMClient
    @Published var store: WorkspaceStore
    @Published var selectedProjectID: Project.ID?
    @Published var selectedTrackID: Track.ID?
    @Published var selectedSceneID: Scene.ID?
    @Published var selectedBlockID: Block.ID?
    // Session model configuration (Console + Studio Inspector share this)
    @Published var consoleModelID: String =
        LLMModelCatalog.presets.first?.id ?? ""
    @Published var consoleTemperature: Double = 0.4
    private let namingTemperature: Double = 0.1
    @Published var consoleContextStrategy: LLMContextStrategy =
        LLMContextStrategy.allCases.first!
    
    // new chat wizard
    @Published var isNewEntityWizardPresented: Bool = false
    @Published var newEntityWizardInitialKind: NewEntityKind? = nil

    
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
    @Published var focusConsoleComposerToken: Int = 0
    @Published var vppRuntime: VppRuntime
    @Published var activeWorkspaceID: UUID = UUID()
    @Published private(set) var activeWorkspaceName: String = "Workspace"
    @Published var libraryTree: [WorkspaceRepository.EnvironmentNode] = []
    @Published var trashRoots: [WorkspaceRepository.TrashRoot] = []
    
    private var registry: WorkspaceRegistry?
    private var db: WorkspaceDB?
    private var repo: WorkspaceRepository?

    private var cancellables: Set<AnyCancellable> = []
    private var autoReplyTask: Task<Void, Never>?
        private var autoRepliedUserMessageIDs: Set<UUID> = []
        private var isAutoReplyRunning: Bool = false
    
        private func scheduleAutoReplyScan() {
            autoReplyTask?.cancel()
            autoReplyTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 120_000_000)
                await self?.autoReplyIfNeeded()
            }
        }
    
    @MainActor
    func quickNewChat(openInConsole: Bool) {
        // 1) Resolve (or create) a Track
        let targetTrackID: Track.ID = selectedTrackID
            ?? store.allProjects.first?.tracks.first
            ?? ensureDefaultPathAndReturnTrackID()

        // 2) Create a Scene in that Track (uses your existing helper below)
        guard let scene = createScene(in: targetTrackID, title: "New Scene") else { return }
        select(scene: scene)

        // 3) Create a Conversation block in that Scene
        let block = Block(
            sceneID: scene.id,
            kind: .conversation,
            title: "Chat",
            subtitle: nil,
            messages: [],
            documentText: nil,
            isCanonical: false,
            createdAt: .now,
            updatedAt: .now
        )
        store.add(block: block)
        select(block: block)
        selectedSessionID = block.id
        syncConsoleSessionsFromBlocks()

        // 4) Only open Console if requested *and* user is already in Console
        guard openInConsole, currentShellMode == .console else { return }

        if let track = store.track(id: scene.trackID),
           let project = store.project(id: track.projectID) {
            _ = openConsole(for: block, project: project, track: track, scene: scene)
            touchConsoleSessionForBlock(block.id)
        }
    }

    @MainActor
    private func ensureDefaultPathAndReturnTrackID() -> Track.ID {
        if let trackID = store.allProjects.first?.tracks.first { return trackID }
        let project = createProject(name: "Project 1")   // uses your existing helper
        return project.tracks.first!
    }

    private func touchConsoleSessionForBlock(_ blockID: Block.ID) {
        touchConsoleSession(blockID)
    }

        @MainActor
        private func autoReplyIfNeeded() async {
            guard !isAutoReplyRunning else { return }
            isAutoReplyRunning = true
            defer { isAutoReplyRunning = false }
    
            let cfg = LLMRequestConfig(
                modelID: consoleModelID,
                temperature: consoleTemperature,
                contextStrategy: consoleContextStrategy
            )
    
            for block in store.allBlocksSortedByUpdatedAtDescending().filter({ $0.kind == .conversation }) {
                guard let last = block.messages.last, last.isUser else { continue }
                if autoRepliedUserMessageIDs.contains(last.id) { continue }
    
                if let s = consoleSessions.first(where: { $0.id == block.id }),
                    case .inFlight = s.requestStatus {

                    continue
                }
    
                autoRepliedUserMessageIDs.insert(last.id)
                await sendPrompt(
                    last.body,
                    in: block.id,
                    config: cfg,
                    existingUserMessageID: last.id
                )
            }
        }

    init(
        store: WorkspaceStore = WorkspaceStore(),
        runtime: VppRuntime = VppRuntime(state: .default),
        llmClient: LLMClient
    ) {
        self.store = store
        self.vppRuntime = runtime
        self.llmClient = llmClient

        store.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    guard let self else { return }
                    self.objectWillChange.send()
                    DispatchQueue.main.async { [weak self] in
                        self?.syncConsoleSessionsFromBlocks()
                        self?.scheduleAutoReplyScan()
                    }
                }
                .store(in: &cancellables)

        bootstrapPersistence()
    }
// MARK: - Persistence bootstrap
    private func bootstrapPersistence() {
        do {
            var reg = try WorkspaceRegistry.loadOrCreate()
            registry = reg
            let active = try reg.activeWorkspaceID()
                ?? reg.entries.first(where: { $0.deletedAt == nil })?.id
                ?? (try reg.createWorkspace(name: "Default").id)
            try openWorkspace(active, registry: &reg)
        } catch {
            print("❌ Workspace bootstrap failed: \(error)")
        }
    }

    @MainActor
    func openWorkspace(_ id: UUID) throws {
        guard var reg = registry else { return }
        try openWorkspace(id, registry: &reg)
        registry = reg
    }

    @MainActor
    private func openWorkspace(_ id: UUID, registry reg: inout WorkspaceRegistry) throws {
        try reg.setActive(id)
        activeWorkspaceID = id
        activeWorkspaceName = reg.entry(for: id)?.name ?? "Workspace"
        let sqliteURL = reg.sqliteURL(for: id)
        db = try WorkspaceDB(workspaceID: id, sqliteURL: sqliteURL)
        repo = WorkspaceRepository(db: db!)
        store.setRepository(repo)                 // ✅ new helper on store
        try store.loadFromRepository()            // ✅ loads projects/tracks/scenes/blocks/messages
        syncConsoleSessionsFromBlocks()
        reloadLibraryTree()
        reloadTrash()
    }

    @MainActor
    func reloadLibraryTree() {
        guard let repo else { return }
        do { libraryTree = try repo.fetchLibraryTree(includeDeleted: false) }
        catch { print("❌ fetchLibraryTree failed: \(error)") }
    }

    @MainActor
    func reloadTrash() {
        guard let repo else { return }
        do { trashRoots = try repo.fetchTrashRoots() }
        catch { print("❌ fetchTrashRoots failed: \(error)") }
    }

    // MARK: - UI Actions (sidebar)
    @MainActor func uiCreateEnvironment() { uiPromptName(defaultName: "Environment") { [self] name in
        guard let repo else { return }
        do { _ = try repo.createEnvironment(name: name); try store.loadFromRepository(); reloadLibraryTree() } catch { print(error) }
    }}

    @MainActor func uiCreateProject(in envID: UUID) { uiPromptName(defaultName: "Project") { [self] name in
        guard let repo else { return }
        do { _ = try repo.createProject(environmentID: envID, name: name); try store.loadFromRepository(); reloadLibraryTree() } catch { print(error) }
    }}

    @MainActor func uiCreateTrack(in projectID: UUID) { uiPromptName(defaultName: "Track") { [self] name in
        guard let repo else { return }
        do { _ = try repo.createTrack(projectID: projectID, name: name); try store.loadFromRepository(); reloadLibraryTree() } catch { print(error) }
    }}

    @MainActor func uiCreateScene(in trackID: UUID) { uiPromptName(defaultName: "Scene") { [self] title in
        guard let repo else { return }
        do { _ = try repo.createScene(trackID: trackID, title: title); try store.loadFromRepository(); reloadLibraryTree() } catch { print(error) }
    }}

    @MainActor func uiRename(req: RenameRequest, newValue: String) {
        guard let repo else { return }
        do {
            switch req.kind {
            case .environment: try repo.renameEnvironment(id: req.entityID, name: newValue)
            case .project: try repo.renameProject(id: req.entityID, name: newValue)
            case .track: try repo.renameTrack(id: req.entityID, name: newValue)
            case .scene: try repo.renameScene(id: req.entityID, title: newValue)
            }
            try store.loadFromRepository()
            reloadLibraryTree()
        } catch { print(error) }
    }

    @MainActor func uiMoveProject(_ projectID: UUID, toEnvironment envID: UUID) {
        guard let repo else { return }
        do { try repo.moveProject(projectID: projectID, toEnvironmentID: envID); try store.loadFromRepository(); reloadLibraryTree() } catch { print(error) }
    }
    @MainActor func uiMoveTrack(_ trackID: UUID, toProject projID: UUID) {
        guard let repo else { return }
        do { try repo.moveTrack(trackID: trackID, toProjectID: projID); try store.loadFromRepository(); reloadLibraryTree() } catch { print(error) }
    }
    @MainActor func uiMoveScene(_ sceneID: UUID, toTrack trackID: UUID) {
        guard let repo else { return }
        do { try repo.moveScene(sceneID: sceneID, toTrackID: trackID); try store.loadFromRepository(); reloadLibraryTree() } catch { print(error) }
    }

    @MainActor func uiTrashEnvironment(_ id: UUID, title: String) { confirmTrash(title) { [weak self] in
        guard let self, let repo = self.repo else { return }
        do { try repo.trashEnvironment(id: id); try self.store.loadFromRepository(); self.reloadLibraryTree(); self.reloadTrash() } catch { print(error) }
    }}
    @MainActor func uiTrashProject(_ id: UUID, title: String) { confirmTrash(title) { [weak self] in
        guard let self, let repo = self.repo else { return }
        do { try repo.trashProject(id: id); try self.store.loadFromRepository(); self.reloadLibraryTree(); self.reloadTrash() } catch { print(error) }
    }}
    @MainActor func uiTrashTrack(_ id: UUID, title: String) { confirmTrash(title) { [weak self] in
        guard let self, let repo = self.repo else { return }
        do { try repo.trashTrack(id: id); try self.store.loadFromRepository(); self.reloadLibraryTree(); self.reloadTrash() } catch { print(error) }
    }}
    @MainActor func uiTrashScene(_ id: UUID, title: String) { confirmTrash(title) { [weak self] in
        guard let self, let repo = self.repo else { return }
        do { try repo.trashScene(id: id); try self.store.loadFromRepository(); self.reloadLibraryTree(); self.reloadTrash() } catch { print(error) }
    }}
    @MainActor func uiTrashBlock(_ id: UUID, title: String) { confirmTrash(title) { [weak self] in
        guard let self, let repo = self.repo else { return }
        do { try repo.trashBlock(id: id); try self.store.loadFromRepository(); self.reloadLibraryTree(); self.reloadTrash() } catch { print(error) }
    }}

    @MainActor func uiEmptyTrash() {
        guard let repo else { return }
        do { try repo.emptyTrash(); try store.loadFromRepository(); reloadLibraryTree(); reloadTrash() } catch { print(error) }
    }

    struct RestoreDestination: Identifiable { let id: UUID; let title: String }
    func restoreDestinations(for kind: RestoreRequest.Kind) -> [RestoreDestination] {
        switch kind {
        case .project:
            return libraryTree.map { .init(id: $0.id, title: $0.name) }
        case .track:
            return libraryTree.flatMap { env in env.projects.map { .init(id: $0.id, title: "\(env.name) ▸ \($0.name)") } }
        case .scene:
            return libraryTree.flatMap { env in
                env.projects.flatMap { p in
                    p.tracks.map { .init(id: $0.id, title: "\(env.name) ▸ \(p.name) ▸ \($0.name)") }
                }
            }
        default:
            return []
        }
    }
    func defaultRestoreDestination(for kind: RestoreRequest.Kind) -> UUID? {
        restoreDestinations(for: kind).first?.id
    }

    @MainActor func uiRestore(req: RestoreRequest, destinationID: UUID?) {
        guard let repo else { return }
        do {
            switch req.kind {
            case .environment:
                try repo.restoreEnvironment(id: req.entityID)
            case .project:
                guard let env = destinationID else { return }
                try repo.restoreProject(id: req.entityID, toEnvironmentID: env)
            case .track:
                guard let proj = destinationID else { return }
                try repo.restoreTrack(id: req.entityID, toProjectID: proj)
            case .scene:
                guard let track = destinationID else { return }
                try repo.restoreScene(id: req.entityID, toTrackID: track)
            case .block:
                // blocks restore in-place
                // (repo.restoreBlock can be added if you decide to allow restoring blocks explicitly)
                try repo.restoreScene(id: req.entityID, toTrackID: destinationID ?? UUID()) // no-op guard below
            }
            try store.loadFromRepository()
            reloadLibraryTree()
            reloadTrash()
        } catch { print(error) }
    }

    @MainActor func uiSelectScene(_ sceneID: UUID) {
        if let scene = store.scene(id: sceneID) {
            select(scene: scene)
        } else {
            selectedSceneID = sceneID
            selectedBlockID = nil
        }
        goToStudio()
    }

    @MainActor func uiSelectBlockInStudio(_ blockID: UUID, sceneID: UUID) {
        selectedSceneID = sceneID
        selectedBlockID = blockID
        goToStudio()
    }
    @MainActor func uiSelectConversationBlock(_ blockID: UUID, sceneID: UUID) {
        selectedSceneID = sceneID
        selectedBlockID = blockID
        selectedSessionID = blockID
        goToConsole()
    }

    // MARK: - Panels (macOS only, small + inline)
    private func uiPromptName(defaultName: String, onCommit: @escaping (String) -> Void) {
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Name"
        alert.informativeText = ""
        let tf = NSTextField(string: defaultName)
        tf.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = tf
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            let s = tf.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { onCommit(s) }
        }
        #endif
    }

    private func confirmTrash(_ title: String, onConfirm: @escaping () -> Void) {
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Move to Trash?"
        alert.informativeText = "“\(title)” will be moved to Trash. You can restore it later."
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { onConfirm() }
        #endif
    }

    @MainActor func uiExportWorkspace() {
        #if os(macOS)
        guard let repo, let reg = registry else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(activeWorkspaceName).vppworkspace"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        if panel.runModal() == .OK, let url = panel.url {
            do { try repo.exportWorkspace(to: url) } catch { print(error) }
        }
        #endif
    }

    @MainActor func uiImportWorkspace() {
        #if os(macOS)
        var reg = registry
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                var r = try WorkspaceRegistry.loadOrCreate()
                var entry = try r.createWorkspace(name: url.deletingPathExtension().lastPathComponent)
                try WorkspaceRepository.importWorkspacePayload(from: url, toWorkspaceID: entry.id)
                r.entries.append(entry)
                try r.save()
                registry = r
                try openWorkspace(entry.id, registry: &r)
            } catch { print(error) }
        }
        #endif
    }
    // MARK: - Console session lifecycle

    /// Ensure there is at least one console session and that selectedSessionID is set.
    func ensureDefaultConsoleSession() {
        syncConsoleSessionsFromBlocks()
        if consoleSessions.isEmpty {
            let welcome = store.ensureWelcomeConversationSeeded()
            syncConsoleSessionsFromBlocks()

            // Default console session is welcome, but don't "pin" the block selection in Studio.
            selectedSessionID = welcome.id

            if let scene = store.scene(id: welcome.sceneID) {
                select(scene: scene) // will clear selectedBlockID (see Fix 2)
            } else {
                selectedSceneID = welcome.sceneID
                selectedBlockID = nil
            }
            return
        }
            if selectedSessionID == nil {
                selectedSessionID = WorkspaceStore.canonicalWelcomeBlockID
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
        // ✅ 1:1 mapping: the ConsoleSession *is* the conversation Block
            if let idx = consoleSessions.firstIndex(where: { $0.id == block.id }) {
                consoleSessions[idx].rootBlock = path
                touchConsoleSession(block.id)
                selectedSessionID = block.id
                return consoleSessions[idx]
            }
        
            let seeded = ConsoleSession(
                id: block.id,
                title: block.title,
                createdAt: block.createdAt,
                lastUsedAt: block.updatedAt,
                rootBlock: path,
                messages: block.messages.map { m in
                    ConsoleMessage(
                        id: m.id,
                        role: m.isUser ? .user : .assistant,
                        text: m.body,
                        createdAt: m.timestamp,
                        state: .normal,
                        vppValidation: m.isUser ? nil : VppRuntime.VppValidationResult(isValid: m.isValidVpp, issues: m.validationIssues),
                        linkedSessionID: block.id
                    )
                },
                requestStatus: .idle,
                modelID: consoleModelID,
                temperature: consoleTemperature,
                contextStrategy: consoleContextStrategy
            )
            consoleSessions.insert(seeded, at: 0)
            selectedSessionID = seeded.id
            return seeded
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
        selectedBlockID = link.blockID
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
        selectedBlockID = nil

        // Keep Console pointing at this scene’s most recent conversation (if any),
        // without forcing an immediate shell switch.
        if let convo = store.blocks(in: scene)
            .filter({ $0.kind == .conversation })
            .sorted(by: { $0.updatedAt > $1.updatedAt })
            .first
        {
            selectedSessionID = convo.id
        } else {
            selectedSessionID = nil
        }
    }

    func selectNextScene() {
        guard let trackID = selectedTrackID,
              let track = store.track(id: trackID) else { return }

        let current = selectedSceneID ?? track.scenes.first
        guard
            let currentSceneID = current,
            let currentIndex = track.scenes.firstIndex(of: currentSceneID)
        else { return }

        guard currentIndex < track.scenes.index(before: track.scenes.endIndex) else { return }

        let nextIndex = track.scenes.index(after: currentIndex)
        guard let nextScene = store.scene(id: track.scenes[nextIndex]) else { return }

        select(scene: nextScene)
    }

    func selectPreviousScene() {
        guard let trackID = selectedTrackID,
              let track = store.track(id: trackID) else { return }

        let current = selectedSceneID ?? track.scenes.first
        guard
            let currentSceneID = current,
            let currentIndex = track.scenes.firstIndex(of: currentSceneID)
        else { return }

        guard currentIndex > track.scenes.startIndex else { return }

        let previousIndex = track.scenes.index(before: currentIndex)
        guard let previousScene = store.scene(id: track.scenes[previousIndex]) else { return }

        select(scene: previousScene)
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
        selectedBlockID = block.id
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

    func focusConsoleComposer() {
        focusConsoleComposerToken &+= 1
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
                title: "New Environment",
                subtitle: "Create a new top-level environment",
                iconName: "plus.square",
                typeLabel: "ACTION",
                payload: .newEnvironment
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

        // ✅ Wizard-routed actions
        case .newEnvironment:
            presentNewEntityWizard(initialKind: .environment)
            isCommandSpaceVisible = false

        case .newProject:
            presentNewEntityWizard(initialKind: .project)
            isCommandSpaceVisible = false

        case .newTrack(let projectID):
            let targetProjectID = projectID ?? selectedProjectID ?? store.allProjects.first?.id
            if let targetProjectID { selectedProjectID = targetProjectID }
            presentNewEntityWizard(initialKind: .track)
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

            if let resolvedTrackID {
                selectedTrackID = resolvedTrackID
                if let track = store.track(id: resolvedTrackID) {
                    selectedProjectID = track.projectID
                }
            }

            presentNewEntityWizard(initialKind: .scene)
            isCommandSpaceVisible = false

        // ✅ Existing behaviors (navigation)
        case .session(let id):
            if consoleSessions.contains(where: { $0.id == id }) {

                // ✅ If this session corresponds to a workspace Block, sync Studio selection
                if let block = store.block(id: id) {
                    select(block: block) // sets project/track/scene/block IDs coherently
                }

                selectedSessionID = id
                touchConsoleSession(id)
                goToConsole()
                isCommandSpaceVisible = false
            }

        case .project(let id):
            if let project = store.project(id: id) {
                goToStudio()
                select(project: project)
                isCommandSpaceVisible = false
            }

        case .track(let projectID, let trackID):
            if let project = store.project(id: projectID),
               let track = store.track(id: trackID) {
                goToStudio()
                select(project: project)
                select(track: track)
                isCommandSpaceVisible = false
            }

        case .scene(let projectID, let trackID, let sceneID):
            if let project = store.project(id: projectID),
               let track = store.track(id: trackID),
               let scene = store.scene(id: sceneID) {
                goToStudio()
                select(project: project)
                select(track: track)
                select(scene: scene)
                isCommandSpaceVisible = false
            }

        case .block(let id):
            guard let block = store.blocks[id],
                  let scene = store.scene(id: block.sceneID),
                  let track = store.track(id: scene.trackID),
                  let project = store.project(id: track.projectID)
            else { return }

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
            isCommandSpaceVisible = false

        // ✅ Keep this immediate (unless you want a “new session wizard” too)
        case .newSession:
            let session = newConsoleSession()
            touchConsoleSession(session.id)
            goToConsole()
            isCommandSpaceVisible = false
        }
    }
    
    @MainActor
    func uiOpenSceneInConsole(_ sceneID: Scene.ID) {
        guard let scene = store.scene(id: sceneID) else { return }

        let convo = store.blocks(in: scene)
            .filter { $0.kind == .conversation }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first ?? {
                let b = Block(
                    sceneID: scene.id,
                    kind: .conversation,
                    title: "Chat",
                    subtitle: nil,
                    messages: [],
                    documentText: nil,
                    isCanonical: false,
                    createdAt: .now,
                    updatedAt: .now
                )
                store.add(block: b)
                syncConsoleSessionsFromBlocks()
                return b
            }()

        selectedSessionID = convo.id
        touchConsoleSession(convo.id)
        goToConsole()
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

// MARK: - Semantic auto-naming
extension WorkspaceViewModel {

    private enum AutoNameKind: String {
        case conversation, scene, track, project
    }

    private struct NamePayload: Decodable {
        let name: String
        let summary: String?
    }

    private func autoNameKey(_ kind: AutoNameKind, _ id: UUID) -> String {
        "\(kind.rawValue):\(id.uuidString)"
    }

    private func isPlaceholder(_ s: String, prefix: String) -> Bool {
        // matches: "Project 1", "Track 12", "Scene 3", "Session 9"
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == prefix || trimmed.hasPrefix(prefix + " ") else { return false }
        let parts = trimmed.split(separator: " ")
        guard parts.count == 2 else { return trimmed == prefix }
        return Int(parts[1]) != nil
    }

    private func stripVppHeader(_ text: String) -> String {
        // user message often starts with a VPP header line; remove obvious header-ish first line
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let first = lines.first else { return text }
        let f = first.trimmingCharacters(in: .whitespacesAndNewlines)
        if f.hasPrefix("!<") || f.hasPrefix("<") {
            return lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shouldAutoNameConversation(_ block: Block) -> Bool {
        guard block.kind == .conversation else { return false }
        guard !block.isCanonical else { return false }
        return isPlaceholder(block.title, prefix: "Session") || block.title == "Session"
    }

    private func shouldAutoNameScene(_ scene: Scene) -> Bool {
        guard isPlaceholder(scene.title, prefix: "Scene") || scene.title == "Scene" else { return false }
        // avoid system containers if they ever come through as scenes
        if scene.title == "Console Chats" || scene.title == "Welcome" { return false }
        return true
    }

    private func shouldAutoNameTrack(_ track: Track) -> Bool {
        guard isPlaceholder(track.name, prefix: "Track") || track.name == "Track" else { return false }
        if track.name == "Sessions" || track.name == "Start Here" { return false }
        return true
    }

    private func shouldAutoNameProject(_ project: Project) -> Bool {
        guard isPlaceholder(project.name, prefix: "Project") || project.name == "Project" else { return false }
        if project.name == "Console" || project.name == "Getting Started" { return false }
        return true
    }

    @MainActor
    private func scheduleAutoName(_ kind: AutoNameKind, id: UUID, delayMs: UInt64 = 250, op: @escaping @MainActor () async -> Void) {
        let key = autoNameKey(kind, id)
        autoNameTasks[key]?.cancel()
        autoNameTasks[key] = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
            await op()
        }
    }

    private func buildConversationNamingContext(conversationID: UUID) -> String? {
        guard let block = store.block(id: conversationID) else { return nil }
        // use first user message as the semantic seed
        guard let firstUser = block.messages.first(where: { $0.isUser }) else { return nil }
        let seed = stripVppHeader(firstUser.body)
        return seed.isEmpty ? nil : seed
    }
    
    private func stripVppEnvelope(_ text: String) -> String {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        // Drop leading tag line like "!<g> ..." or "<g>"
        var start = 0
        if let first = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if first.hasPrefix("!<") || (first.hasPrefix("<") && first.contains(">")) {
                start = 1
            }
        }

        // Drop trailing footer like "[Version=v1.4 | Tag=... ]"
        var end = lines.count
        if let last = lines.last?.trimmingCharacters(in: .whitespacesAndNewlines),
           last.hasPrefix("[") && last.contains("Version=v1.4") && last.contains("Tag=<") && last.contains("Cycle=") {
            end = max(start, end - 1)
        }

        return lines[start..<end].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func clamp(_ s: String, _ maxChars: Int) -> String {
        guard s.count > maxChars else { return s }
        let idx = s.index(s.startIndex, offsetBy: maxChars)
        return String(s[..<idx]) + "…"
    }

    private func buildSceneNamingContext(sceneID: UUID) -> String? {
        guard let scene = store.scene(id: sceneID) else { return nil }
        let blocks = store.blocks(in: scene)
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(3)

        var parts: [String] = []
        for b in blocks {
            if b.kind == .conversation, let firstUser = b.messages.first(where: { $0.isUser }) {
                parts.append("Chat: " + stripVppHeader(firstUser.body))
            } else if b.kind == .document, let t = b.documentText, !t.isEmpty {
                parts.append("Doc: " + t)
            } else {
                parts.append("Block: " + b.title)
            }
        }
        let ctx = parts.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return ctx.isEmpty ? nil : ctx
    }

    private func buildTrackNamingContext(trackID: UUID) -> String? {
            guard
                let track = store.track(id: trackID),
                let project = store.project(id: track.projectID)
            else { return nil }
    
            // Sibling tracks (same project, excluding this one), max 5
            let siblingTrackNames: [String] = project.tracks
                .filter { $0 != track.id }
                .compactMap { store.track(id: $0)?.name }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(5)
                .map { "• \($0)" }
    
            // Scenes in this track, max 8
            let scenes: [Scene] = track.scenes.compactMap { store.scene(id: $0) }
            let sceneLines = scenes
                .prefix(8)
                .map { "• \($0.title)" }
    
            // Conversations across scenes: include title + short excerpt, capped
            var convoLines: [String] = []
            for scene in scenes {
                let convos = store.blocks(in: scene)
                    .filter { $0.kind == .conversation }
                    .sorted { $0.updatedAt > $1.updatedAt }
                    .prefix(2)
    
                for b in convos {
                    let userBodies = b.messages
                        .filter { $0.isUser }
                        .map { clamp(stripVppEnvelope($0.body), 260) }
                        .filter { !$0.isEmpty }
    
                    let firstFew = Array(userBodies.prefix(3))
                    let lastOne: [String] = {
                        guard let last = userBodies.last else { return [] }
                        return firstFew.contains(last) ? [] : [last]
                    }()
                    let selected = firstFew + lastOne
                    let excerpt = selected.joined(separator: "  ⟂  ")
    
                    let title = b.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    if excerpt.isEmpty {
                        convoLines.append("• \(title)")
                    } else {
                        convoLines.append("• \(title): \(excerpt)")
                    }
                }
            }
            convoLines = Array(convoLines.prefix(8))
    
            var out = ""
            out += "HIERARCHY\n"
            out += "Project: \(project.name)\n"
            out += "Track (current): \(track.name)\n\n"
    
            out += "SIBLING TRACKS (same project, max 5)\n"
            out += siblingTrackNames.isEmpty ? "• (none)\n\n" : siblingTrackNames.joined(separator: "\n") + "\n\n"
    
            out += "SCENES (this track, max 8)\n"
            out += sceneLines.isEmpty ? "• (none)\n\n" : sceneLines.joined(separator: "\n") + "\n\n"
    
            out += "CONVERSATIONS (titles + excerpts, max 8)\n"
            out += convoLines.isEmpty ? "• (none)\n" : convoLines.joined(separator: "\n")
    
            let ctx = out.trimmingCharacters(in: .whitespacesAndNewlines)
            return ctx.isEmpty ? nil : ctx
        }

    private func buildProjectNamingContext(projectID: UUID) -> String? {
        guard let project = store.project(id: projectID) else { return nil }
        let trackNames = project.tracks.compactMap { store.track(id: $0)?.name }.prefix(6)
        let ctx = trackNames.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return ctx.isEmpty ? nil : ctx
    }

    private func requestNameFromLLM(kind: AutoNameKind, context: String, modelID: String) async throws -> NamePayload {
        let system = """
        You generate short semantic names for an app’s workspace entities.

        Return STRICT JSON only:
        {"name":"...","summary":"...optional..."}

        Rules:
        - name: 2–6 words, Title Case, no quotes, no emojis, no trailing punctuation.
        - summary: optional; only include for scenes (1 sentence, <= 14 words).
        """

        let user = """
        Entity kind: \(kind.rawValue)
        Context:
        \(context.prefix(1200))
        """

        let req = LLMRequest(
            modelID: modelID,
            temperature: namingTemperature,
            contextStrategy: consoleContextStrategy,
            messages: [
                LLMMessage(role: .system, content: system),
                LLMMessage(role: .user, content: user)
            ]
        )

        let resp = try await llmClient.send(req)
        let raw = resp.text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse first JSON object in the response (defensive)
        if let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}") , start < end {
            let json = String(raw[start...end])
            let data = Data(json.utf8)
            if let decoded = try? JSONDecoder().decode(NamePayload.self, from: data) {
                return decoded
            }
        }

        // Fallback: treat the first non-empty line as the name
        let firstLine = raw.split(separator: "\n").map(String.init).first ?? "Untitled"
        return NamePayload(name: firstLine, summary: nil)
    }

    @MainActor
    private func applyConversationName(_ name: String, conversationID: UUID) {
        guard var block = store.block(id: conversationID) else { return }
        block.title = name
        block.updatedAt = .now
        store.update(block: block)
        syncConsoleSessionsFromBlocks()
    }

    @MainActor
    private func applySceneName(_ payload: NamePayload, sceneID: UUID) {
        guard var scene = store.scene(id: sceneID) else { return }
        scene.title = payload.name
        if let s = payload.summary, !s.isEmpty { scene.summary = s }
        scene.updatedAt = .now
        store.update(scene: scene)
        do { try repo?.renameScene(id: sceneID, title: payload.name) }
        catch { print("❌ renameScene failed:", error) }
        reloadLibraryTree()
    }

    @MainActor
    private func applyTrackName(_ name: String, trackID: UUID) {
        guard var track = store.track(id: trackID) else { return }
        track.name = name
        store.update(track: track)
        do { try repo?.renameTrack(id: trackID, name: name) }
        catch { print("❌ renameTrack failed:", error) }
        reloadLibraryTree()
    }

    @MainActor
    private func applyProjectName(_ name: String, projectID: UUID) {
        guard var project = store.project(id: projectID) else { return }
        project.name = name
        store.update(project: project)
        do { try repo?.renameProject(id: projectID, name: name) }
        catch { print("❌ renameProject failed:", error) }
        reloadLibraryTree()
    }

    /// Call this after the first user message is appended.
    @MainActor
    func maybeAutoNameCascade(fromConversation conversationID: UUID, modelID: String) {
        guard let convoBlock = store.block(id: conversationID) else { return }

        // Conversation
        if shouldAutoNameConversation(convoBlock) && !autoNamedKeys.contains(autoNameKey(.conversation, conversationID)) {
            scheduleAutoName(.conversation, id: conversationID) { [weak self] in
                guard let self else { return }
                guard let ctx = self.buildConversationNamingContext(conversationID: conversationID) else { return }
                do {
                    let payload = try await self.requestNameFromLLM(kind: .conversation, context: ctx, modelID: modelID)
                    await MainActor.run {
                        self.applyConversationName(payload.name, conversationID: conversationID)
                        self.autoNamedKeys.insert(self.autoNameKey(.conversation, conversationID))
                    }
                } catch {
                    print("❌ auto-name conversation failed:", error)
                }
            }
        }

        // Scene / Track / Project cascade (only if still placeholders)
        guard let scene = store.scene(id: convoBlock.sceneID) else { return }
        guard let track = store.track(id: scene.trackID) else { return }
        guard let project = store.project(id: track.projectID) else { return }

        if shouldAutoNameScene(scene) && !autoNamedKeys.contains(autoNameKey(.scene, scene.id)) {
            scheduleAutoName(.scene, id: scene.id) { [weak self] in
                guard let self else { return }
                guard let ctx = self.buildSceneNamingContext(sceneID: scene.id) else { return }
                do {
                    let payload = try await self.requestNameFromLLM(kind: .scene, context: ctx, modelID: modelID)
                    await MainActor.run {
                        self.applySceneName(payload, sceneID: scene.id)
                        self.autoNamedKeys.insert(self.autoNameKey(.scene, scene.id))
                    }
                } catch {
                    print("❌ auto-name scene failed:", error)
                }
            }
        }

        if shouldAutoNameTrack(track) && !autoNamedKeys.contains(autoNameKey(.track, track.id)) {
            scheduleAutoName(.track, id: track.id) { [weak self] in
                guard let self else { return }
                guard let ctx = self.buildTrackNamingContext(trackID: track.id) else { return }
                do {
                    let payload = try await self.requestNameFromLLM(kind: .track, context: ctx, modelID: modelID)
                    await MainActor.run {
                        self.applyTrackName(payload.name, trackID: track.id)
                        self.autoNamedKeys.insert(self.autoNameKey(.track, track.id))
                    }
                } catch {
                    print("❌ auto-name track failed:", error)
                }
            }
        }

        if shouldAutoNameProject(project) && !autoNamedKeys.contains(autoNameKey(.project, project.id)) {
            scheduleAutoName(.project, id: project.id) { [weak self] in
                guard let self else { return }
                guard let ctx = self.buildProjectNamingContext(projectID: project.id) else { return }
                do {
                    let payload = try await self.requestNameFromLLM(kind: .project, context: ctx, modelID: modelID)
                    await MainActor.run {
                        self.applyProjectName(payload.name, projectID: project.id)
                        self.autoNamedKeys.insert(self.autoNameKey(.project, project.id))
                    }
                } catch {
                    print("❌ auto-name project failed:", error)
                }
            }
        }
    }
}

// MARK: - LLM send pipeline

extension WorkspaceViewModel {
    struct LLMRequestConfig {
        var modelID: String
        var temperature: Double
        var contextStrategy: LLMContextStrategy
    }
    @MainActor
    func syncConsoleSessionsFromBlocks() {
        let convoBlocks = store
            .allBlocksSortedByUpdatedAtDescending()
            .filter { $0.kind == .conversation }

        // Upsert ConsoleSession for each conversation block (stable ID == block.id)
        for block in convoBlocks {
            if let idx = consoleSessions.firstIndex(where: { $0.id == block.id }) {
                // keep title + seed messages if missing
                consoleSessions[idx].title = block.title
                // ✅ if not actively sending, keep session transcript in lockstep with the block
                if case .inFlight = consoleSessions[idx].requestStatus {
                                // keep local pending placeholder while request is in flight
                            } else {
                                consoleSessions[idx].messages = block.messages.map { m in
                                    ConsoleMessage(
                                        id: m.id,
                                        role: m.isUser ? .user : .assistant,
                                        text: m.body,
                                        createdAt: m.timestamp,
                                        state: .normal,
                                        vppValidation: m.isUser ? nil : VppRuntime.VppValidationResult(isValid: m.isValidVpp, issues: m.validationIssues),
                                        linkedSessionID: block.id,
                                        sources: m.sources,
                                        sourcesTable: m.sourcesTable
                                    )
                                }
                            }
                consoleSessions[idx].lastUsedAt = max(consoleSessions[idx].lastUsedAt, block.updatedAt)
            } else {
                let seeded = ConsoleSession(
                    id: block.id,
                    title: block.title,
                    createdAt: block.createdAt,
                    lastUsedAt: block.updatedAt,
                    rootBlock: nil,
                    messages: block.messages.map { m in
                        ConsoleMessage(
                            id: m.id,
                            role: m.isUser ? .user : .assistant,
                            text: m.body,
                            createdAt: m.timestamp,
                            state: .normal,
                            vppValidation: m.isUser ? nil : VppRuntime.VppValidationResult(isValid: m.isValidVpp, issues: m.validationIssues),
                            linkedSessionID: block.id
                        )
                    },
                    requestStatus: .idle,
                    modelID: SessionDefaults.defaultModelID,
                    temperature: SessionDefaults.defaultTemperature,
                    contextStrategy: SessionDefaults.defaultContextStrategy
                )
                consoleSessions.insert(seeded, at: 0)
            }
        }
    }

    @MainActor
    private func upsertConsoleSessionIndex(for sessionID: ConsoleSession.ID) -> Int {
        if let idx = consoleSessions.firstIndex(where: { $0.id == sessionID }) {
            return idx
        }

        // Seed so Studio/Atlas sends don't silently no-op.
        // Title will be refined later once we bind this to a Block/Scene hierarchy.
        let seeded = ConsoleSession(
            id: sessionID,
            title: "Session",
            createdAt: Date(),
            lastUsedAt: Date(),
            rootBlock: nil,
            messages: [],
            requestStatus: .idle,
            modelID: SessionDefaults.defaultModelID,
            temperature: SessionDefaults.defaultTemperature,
            contextStrategy: SessionDefaults.defaultContextStrategy
        )
        consoleSessions.insert(seeded, at: 0)
        return 0
    }
    func copyLastAssistantMessage() {
        guard let session = consoleSessions.last else { return }
        guard let msg = session.messages.last(where: { $0.role == .assistant }) else { return }

        let s = MarkdownCopyText.renderedText(from: msg.text)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
    @MainActor
    func createConsoleConversation(title: String? = nil) -> Block.ID? {
        // pick a safe scene to attach the block to
        let fallbackSceneID: Scene.ID? = selectedSceneID
            ?? store.allProjects.first
                .flatMap { $0.tracks.first }
                .flatMap { store.track(id: $0)?.scenes.first }

        guard let sceneID = fallbackSceneID else { return nil }

        let newBlock = Block(
            sceneID: sceneID,
            kind: .conversation,
            title: title ?? "Session \(consoleSessions.count + 1)",
            subtitle: nil,
            messages: [],
            documentText: nil,
            isCanonical: false,
            createdAt: .now,
            updatedAt: .now
        )
        store.add(block: newBlock)
        selectedSessionID = newBlock.id
        selectedBlockID = newBlock.id
        return newBlock.id
    }

    @MainActor
    func presentNewEntityWizard(initialKind: NewEntityKind? = nil) {
        newEntityWizardInitialKind = initialKind
        isNewEntityWizardPresented = true
    }

    @MainActor
    func uiCreateViaWizard(
        kind: NewEntityKind,
        envID: UUID?,
        projectID: UUID?,
        trackID: UUID?,
        name: String
    ) throws -> UUID {
        guard let repo else { throw NSError(domain: "Workspace", code: 1) }

        let createdID: UUID

        switch kind {
        case .environment:
            createdID = try repo.createEnvironment(name: name)
            // no selection change required, but we can reload.
        case .project:
            guard let envID else { throw NSError(domain: "Workspace", code: 2) }
            createdID = try repo.createProject(environmentID: envID, name: name)
        case .track:
            guard let projectID else { throw NSError(domain: "Workspace", code: 3) }
            createdID = try repo.createTrack(projectID: projectID, name: name)
        case .scene:
            guard let trackID else { throw NSError(domain: "Workspace", code: 4) }
            createdID = try repo.createScene(trackID: trackID, title: name)
        }

        try store.loadFromRepository()
        reloadLibraryTree()

        // Best-effort selection updates (no forced shell switch)
        switch kind {
        case .environment:
            break
        case .project:
            selectedProjectID = createdID
        case .track:
            selectedTrackID = createdID
            if let track = store.track(id: createdID) { selectedProjectID = track.projectID }
        case .scene:
            selectedSceneID = createdID
            if let scene = store.scene(id: createdID) {
                selectedTrackID = scene.trackID
                if let track = store.track(id: scene.trackID) {
                    selectedProjectID = track.projectID
                }
            }
        }

        return createdID
    }


    @MainActor
    func sendPrompt(
        _ text: String,
        in sessionID: ConsoleSession.ID,
        config: LLMRequestConfig,
        assumptions: AssumptionsConfig = .none,          // ✅ add
        sourcesTable: [VppSourceRef] = [],
        existingUserMessageID: UUID? = nil
    ) async {
        print("SEND enter instanceID=\(instanceID) sessionID=\(sessionID) model=\(config.modelID)")
        let index = upsertConsoleSessionIndex(for: sessionID)
        var session = consoleSessions[index]
        let timestamp = Date()
        // Keep runtime assumptions count in sync so makeFooter() is accurate
        vppRuntime.setAssumptions(assumptions.persistedCount)
        // ✅ Replies should persist into the *conversation block*:
            // - if this session is "about" a studio block, use that blockID
            // - otherwise, the sessionID itself is the conversation ID
        let conversationID = session.rootBlock?.blockID ?? sessionID

        let existingSceneID = store.block(id: conversationID)?.sceneID
        let resolvedSceneID =
            existingSceneID
            ?? session.rootBlock?.sceneID
            ?? selectedSceneID
            ?? store.allProjects.first
                .flatMap { $0.tracks.first }
                .flatMap { store.track(id: $0)?.scenes.first }

        _ = store.ensureConversationBlock(
            id: conversationID,
            title: session.title,
            sceneID: resolvedSceneID
        )

        
            let userID = existingUserMessageID ?? UUID()
        let userMessage = ConsoleMessage(
            id: userID,
            role: .user,
            text: text,
            createdAt: timestamp,
            state: .normal
        )
        let pendingMessage = ConsoleMessage(
            role: .assistant,
            text: "",
            createdAt: timestamp,
            state: .pending
        )

        if !session.messages.contains(where: { $0.id == userID }) {
                session.messages.append(userMessage)
            }
        session.messages.append(pendingMessage)
        session.lastUsedAt = Date()
        session.requestStatus = .inFlight(stage: .sending, startedAt: timestamp)
        consoleSessions[index] = session
        // Premium + truthful: brief “Sending…” then “Receiving…” while we wait.
         Task { @MainActor [weak self] in
             guard let self else { return }
             try? await Task.sleep(nanoseconds: 220_000_000)
             guard let latestIndex = self.consoleSessions.firstIndex(where: { $0.id == sessionID }) else { return }
             if case let .inFlight(stage, startedAt) = self.consoleSessions[latestIndex].requestStatus,
                stage == .sending {
                 self.consoleSessions[latestIndex].requestStatus = .inFlight(stage: .receiving, startedAt: startedAt)
             }
         }

        
        // ✅ persist user message into WorkspaceStore Block
        let st = vppRuntime.state
        let sourcesSummary = VppSources.summary(for: sourcesTable)
        let blockUser = Message(
            id: userID,
            isUser: true,
            timestamp: timestamp,
            body: text,
            tag: st.currentTag,
            cycleIndex: st.cycleIndex,
            assumptions: assumptions.persistedCount,
            sources: sourcesSummary,
            sourcesTable: sourcesTable,
            locus: st.locus,
            isValidVpp: true,
            validationIssues: []
        )
        store.appendMessage(to: conversationID, blockUser)
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.maybeAutoNameCascade(fromConversation: conversationID, modelID: config.modelID)
        }


        // ✅ build request messages
        var requestMessages: [LLMMessage] = session.messages
            .filter { $0.id != pendingMessage.id }
            .map { message in
            let role: LLMRole
            switch message.role {
            case .system: role = .system
            case .user: role = .user
            case .assistant: role = .assistant
            }
            return LLMMessage(id: message.id, role: role, content: message.text)
        }
        // ✅ ALWAYS-on base VPP system prompt (must be first system message)
        requestMessages.insert(LLMMessage(role: .system, content: VppSystemPrompt.base), at: 0)
        // ✅ EPHEMERAL assumptions attachment (not persisted in session.messages)
        if let attachment = assumptions.assumptionsAttachmentText {
            requestMessages.insert(
                LLMMessage(role: .system, content: attachment),
                at: 0
            )
        }
        // ✅ EPHEMERAL sources instruction + table for “footer A + per-message sources table”
        if !sourcesTable.isEmpty {
                   let table = sourcesTable.asVppSourcesTableMarkdown()
                  requestMessages.insert(
                    LLMMessage(role: .system, content: VppSystemPrompt.sourcesInstruction(tableMarkdown: table)),
                    at: 0
                  )
                 }

        let request = LLMRequest(
            modelID: config.modelID,
            temperature: config.temperature,
            contextStrategy: config.contextStrategy,
            messages: requestMessages
        )

        do {
            
            print("SEND calling llmClient…")
            let response = try await llmClient.send(request)
            
            print("SEND llmClient returned chars=\(response.text.count)")
           
                       // ✅ Make VPP compliance deterministic (no reliance on the model)
                       // For now: Sources token is derived from the known call context:
                       let sourcesToken = sourcesTable.isEmpty ? "none" : "web"
                       let coerced = coerceVppAssistantReply(response.text, sourcesToken: sourcesToken)

            guard let latestIndex = consoleSessions.firstIndex(where: { $0.id == sessionID }) else { return }
            var latestSession = consoleSessions[latestIndex]

            if let pendingIndex = latestSession.messages.firstIndex(where: { $0.id == pendingMessage.id }) {
                latestSession.messages[pendingIndex].text = coerced
                latestSession.messages[pendingIndex].state = .normal
                latestSession.messages[pendingIndex].vppValidation = vppRuntime.validateAssistantReply(coerced)
            }
            
            // ✅ persist assistant reply into WorkspaceStore Block
            let st2 = vppRuntime.state
            let validation = vppRuntime.validateAssistantReply(coerced)
            let parsedTable = vppRuntime.parseSourcesTable(from: coerced)
            let assistantSourcesSummary: VppSources = {
                if !parsedTable.isEmpty { return VppSources.summary(for: parsedTable) }
                if let token = vppRuntime.extractFooterSourcesValue(response.text),
                   let simple = VppSources(rawValue: token) {
                    return simple
                }
                return .none
            }()

            let assistantTimestamp = Date()
            let blockAssistant = Message(
                id: pendingMessage.id,
                isUser: false,
                timestamp: assistantTimestamp,
                body: coerced,
                tag: st2.currentTag,
                cycleIndex: st2.cycleIndex,
                assumptions: 0,
                sources: assistantSourcesSummary,
                sourcesTable: parsedTable,
                locus: st2.locus,
                isValidVpp: validation.isValid,
                validationIssues: validation.issues
            )
            store.appendMessage(to: conversationID, blockAssistant)

            
             // ✅ keep console list in sync with new/updated block
             syncConsoleSessionsFromBlocks()
            
            latestSession.requestStatus = .idle
            consoleSessions[latestIndex] = latestSession

            // footer ingestion keeps tag/cycle/locus in sync
            vppRuntime.ingestFooterLine(coerced)

        } catch {
            guard let latestIndex = consoleSessions.firstIndex(where: { $0.id == sessionID }) else { return }
            var latestSession = consoleSessions[latestIndex]

            if let pendingIndex = latestSession.messages.firstIndex(where: { $0.id == pendingMessage.id }) {
                let msg = "⚠️ \(error.localizedDescription)"
                latestSession.messages[pendingIndex].text = msg
                latestSession.messages[pendingIndex].state = .error(message: error.localizedDescription)
            }
            // ✅ persist assistant error into WorkspaceStore Block so syncConsoleSessionsFromBlocks won’t resurrect a “pending” UI state
                      let conversationID = latestSession.rootBlock?.blockID ?? sessionID
                      let st2 = vppRuntime.state
                      let assistantTimestamp = Date()
                      let blockAssistant = Message(
                        id: pendingMessage.id,
                        isUser: false,
                        timestamp: assistantTimestamp,
                        body: "⚠️ \(error.localizedDescription)",
                        tag: st2.currentTag,
                        cycleIndex: st2.cycleIndex,
                        assumptions: 0,
                        sources: .none,
                        sourcesTable: [],
                        locus: st2.locus,
                        isValidVpp: false,
                        validationIssues: ["LLM request failed: \(error.localizedDescription)"]
                      )
                      store.appendMessage(to: conversationID, blockAssistant)
                      syncConsoleSessionsFromBlocks()

            latestSession.requestStatus = .idle
            consoleSessions[latestIndex] = latestSession

            print("SEND error:", error)
        }
    }
    private func coerceVppAssistantReply(_ raw: String, sourcesToken: String) -> String {
      var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

      // 1) Ensure leading tag line exists
      let expectedTagLine = "<\(vppRuntime.state.currentTag.rawValue)>"
      let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
      let firstNonEmptyIndex = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })

      if let idx = firstNonEmptyIndex {
        let first = lines[idx].trimmingCharacters(in: .whitespacesAndNewlines)
        if !first.hasPrefix("<") {
          text = expectedTagLine + "\n\n" + text
        }
      } else {
        text = expectedTagLine
      }

      // 2) Ensure footer exists (exactly one)
      let footer = vppRuntime.makeFooter(sources: .none, sourceTokens: [sourcesToken])
      let outLines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

      let hasFooter = outLines.last.map { last in
        let s = last.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.hasPrefix("[") && s.contains("Version=v1.4") && s.contains("Tag=<") && s.contains("Cycle=")
      } ?? false

      if !hasFooter {
        text += "\n\n" + footer
      }

      return text
    }

}
