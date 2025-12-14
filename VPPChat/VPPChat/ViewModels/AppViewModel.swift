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

    let llmClient: LlmClient
    private var cancellables = Set<AnyCancellable>()

    init(store: InMemoryStore = InMemoryStore(), runtime: VppRuntime = VppRuntime()) {
        self.store = store
        self.runtime = runtime
        self.llmClient = FakeLlmClient(runtime: runtime)

        if let firstFolder = store.folders.first {
            self.selectedFolderID = firstFolder.id
        }
        if let firstSession = store.sessions.first {
            self.selectedSessionID = firstSession.id
        }

        bindStore()
    }

    private func bindStore() {
        store.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
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
    }

    func createNewSession(in folder: Folder?) {
        let session = store.createSession(in: folder)
        selectedSessionID = session.id
        selectedFolderID = folder?.id ?? selectedFolderID
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
