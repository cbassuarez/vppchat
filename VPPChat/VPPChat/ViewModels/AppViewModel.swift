import Foundation
import Combine
import SwiftUI
#if os(macOS)
import AppKit
#endif

// AppViewModel coordinates global app state, selection, and shared services.
final class AppViewModel: ObservableObject {
    @Published var store: InMemoryStore
    @Published var runtime: VppRuntime
    @Published var selectedFolderID: Folder.ID?
    @Published var selectedSessionID: Session.ID?
    @Published var workspace: WorkspaceViewModel

    private var isSyncingSessions = false

    let llmClient: LlmClient
    private var cancellables = Set<AnyCancellable>()

    init(store: InMemoryStore = InMemoryStore(), runtime: VppRuntime = VppRuntime()) {
        self.store = store
        self.runtime = runtime
        self.llmClient = FakeLlmClient(runtime: runtime) // can delete later; kept for now
        self.workspace = WorkspaceViewModel(runtime: runtime)
        if let firstFolder = store.folders.first {
            self.selectedFolderID = firstFolder.id
        }
        if let firstSession = store.sessions.first {
            self.selectedSessionID = firstSession.id
        }

        bindStore()
        syncWorkspaceFromStore()
        if let selectedSessionID { workspace.selectedSessionID = selectedSessionID }
    }

    private func bindStore() {
        workspace.$consoleSessions
                    .sink { [weak self] _ in
                        guard let self else { return }
                        self.objectWillChange.send()
                        self.syncStoreFromWorkspace()
                    }
                    .store(in: &cancellables)
        
                workspace.$selectedSessionID
                    .sink { [weak self] id in
                        guard let self else { return }
                        if self.selectedSessionID != id { self.selectedSessionID = id }
                    }
                    .store(in: &cancellables)
    }

    var selectedSession: Session? {
        store.session(id: selectedSessionID)
    }

    var selectedFolder: Folder? {
        store.folders.first { $0.id == selectedFolderID }
    }

    func selectFolder(_ folder: Folder) {
        selectedFolderID = folder.id
    }

    func selectSession(_ session: Session) {
        selectedSessionID = session.id
        ensureConsoleSessionExists(for: session)
        workspace.selectedSessionID = session.id
    }

    func createNewSession(in folder: Folder?) {
        let session = store.createSession(in: folder)
        selectedSessionID = session.id
        selectedFolderID = folder?.id ?? selectedFolderID
        ensureConsoleSessionExists(for: session)
        workspace.selectedSessionID = session.id
    }

    func createNewFolder(named name: String) {
        let folder = store.createFolder(name: name)
        selectedFolderID = folder.id
    }

    func showSettings() {
#if os(macOS)
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
#endif
    }
}

extension AppViewModel {
    /// Generic binding into a Session's property by ID (for Console inspectors).
    func binding<Value>(
        for sessionID: Session.ID,
        keyPath: WritableKeyPath<Session, Value>,
        default defaultValue: Value
    ) -> Binding<Value> {
        Binding(
            get: {
                // Look up the live session in the store
                self.store.sessions.first(where: { $0.id == sessionID })?[keyPath: keyPath]
                ?? defaultValue
            },
            set: { newValue in
                guard let index = self.store.sessions.firstIndex(where: { $0.id == sessionID }) else { return }
                self.store.sessions[index][keyPath: keyPath] = newValue
                // Make sure views depending on AppViewModel update
                self.objectWillChange.send()
            }
        )
    }
}

// MARK: - Session parity bridge (InMemoryStore <-> WorkspaceViewModel)

 extension AppViewModel {
    func ensureDefaultSession() {
        if store.sessions.isEmpty {
            createNewSession(in: selectedFolder)
            return
        }
        syncWorkspaceFromStore()
        if selectedSessionID == nil {
            selectedSessionID = store.sessions.first?.id
        }
        if let selectedSessionID {
            workspace.selectedSessionID = selectedSessionID
        }
    }

    func ensureConsoleSessionExists(for session: Session) {
        // Upsert a ConsoleSession with same UUID.
        let console = consoleSession(from: session)
        if let idx = workspace.consoleSessions.firstIndex(where: { $0.id == console.id }) {
            workspace.consoleSessions[idx].title = console.title
            // If workspace has no messages yet but store does, seed them.
            if workspace.consoleSessions[idx].messages.isEmpty && !console.messages.isEmpty {
                workspace.consoleSessions[idx].messages = console.messages
            }
        } else {
            workspace.consoleSessions.insert(console, at: 0)
        }
    }

    func syncWorkspaceFromStore() {
        guard !isSyncingSessions else { return }
        isSyncingSessions = true
        defer { isSyncingSessions = false }

        for s in store.sessions {
            ensureConsoleSessionExists(for: s)
        }
    }

    func syncStoreFromWorkspace() {
        guard !isSyncingSessions else { return }
        isSyncingSessions = true
        defer { isSyncingSessions = false }

        // Upsert store.sessions for every console session.
        for console in workspace.consoleSessions {
            if let idx = store.sessions.firstIndex(where: { $0.id == console.id }) {
                // Update existing Session
                store.sessions[idx].name = console.title
                store.sessions[idx].updatedAt = console.lastUsedAt
                store.sessions[idx].modelID = console.modelID
                store.sessions[idx].temperature = console.temperature
                store.sessions[idx].contextStrategy = console.contextStrategy
                store.sessions[idx].messages = messages(from: console)
            } else {
                // Create new Session with same id
                let new = Session(
                    id: console.id,
                    name: console.title,
                    folderID: nil,
                    isPinned: false,
                    locus: console.rootBlock?.displayPath,
                    createdAt: console.createdAt,
                    updatedAt: console.lastUsedAt,
                    messages: messages(from: console),
                    modelID: console.modelID,
                    temperature: console.temperature,
                    contextStrategy: console.contextStrategy
                )
                store.sessions.insert(new, at: 0)
            }
        }
    }

    func consoleSession(from session: Session) -> ConsoleSession {
        let msgs: [ConsoleMessage] = session.messages.map { m in
            let role: ConsoleMessageRole = m.isUser ? .user : .assistant
            let validation: VppRuntime.VppValidationResult? = m.isUser
                ? nil
                : VppRuntime.VppValidationResult(isValid: m.isValidVpp, issues: m.validationIssues)

            return ConsoleMessage(
                id: m.id,
                role: role,
                text: m.body,
                createdAt: m.timestamp,
                linkedBlock: nil,
                state: .normal,
                vppValidation: validation,
                linkedSessionID: session.id
            )
        }

        return ConsoleSession(
            id: session.id,
            title: session.name,
            createdAt: session.createdAt,
            lastUsedAt: session.updatedAt,
            rootBlock: nil,
            messages: msgs,
            requestStatus: .idle,
            modelID: session.modelID,
            temperature: session.temperature,
            contextStrategy: session.contextStrategy
        )
    }

    func messages(from console: ConsoleSession) -> [Message] {
        console.messages
            .filter { $0.role != .system }
            .map { cm in
                let isUser = (cm.role == .user)
                return Message(
                    id: cm.id,
                    isUser: isUser,
                    timestamp: cm.createdAt,
                    body: cm.text,
                    tag: .c,                       // conservative default; your VPP parser can refine later
                    cycleIndex: runtime.state.cycleIndex,
                    assumptions: runtime.state.assumptions,
                    sources: .none,
                    locus: runtime.state.locus,
                    isValidVpp: cm.vppValidation?.isValid ?? true,
                    validationIssues: cm.vppValidation?.issues ?? []
                )
            }
    }
}
