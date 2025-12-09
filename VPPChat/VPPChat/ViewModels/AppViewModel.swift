import Foundation
import Combine

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
}
