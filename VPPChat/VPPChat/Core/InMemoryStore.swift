import Foundation
import Combine

final class InMemoryStore: ObservableObject {
    @Published var folders: [Folder]
    @Published var sessions: [Session]

    init(folders: [Folder] = [], sessions: [Session] = []) {
        if folders.isEmpty && sessions.isEmpty {
            let seeded = InMemoryStore.makeDefault()
            self.folders = seeded.folders
            self.sessions = seeded.sessions
        } else {
            self.folders = folders
            self.sessions = sessions
        }
    }

    static func makeDefault() -> (folders: [Folder], sessions: [Session]) {
        let defaultFolder = Folder(id: UUID(), name: "General", isPinned: true, sessions: [])
        let sessionID = UUID()
        let now = Date()
        let placeholderMessages: [Message] = [
            Message(
                id: UUID(),
                isUser: true,
                timestamp: now.addingTimeInterval(-300),
                body: "!<g> --correct\nHello, VPPConsole!",
                tag: .g,
                cycleIndex: 1,
                assumptions: 0,
                sources: .none,
                locus: "VPPConsole",
                isValidVpp: true,
                validationIssues: []
            ),
            Message(
                id: UUID(),
                isUser: false,
                timestamp: now.addingTimeInterval(-290),
                body: "<q> Thanks for trying the app.\n[Version=v1.4 | Tag=<q_1> | Sources=<none> | Assumptions=0 | Cycle=1/3 | Locus=VPPConsole]",
                tag: .q,
                cycleIndex: 1,
                assumptions: 0,
                sources: .none,
                locus: "VPPConsole",
                isValidVpp: true,
                validationIssues: []
            )
        ]

        let defaultSession = Session(
            id: sessionID,
            name: "Welcome Session",
            folderID: defaultFolder.id,
            isPinned: true,
            locus: "VPPConsole",
            createdAt: now,
            updatedAt: now,
            messages: placeholderMessages
        )

        var folder = defaultFolder
        folder.sessions = [sessionID]
        return ([folder], [defaultSession])
    }

    func folder(for session: Session.ID) -> Folder? {
        folders.first { $0.sessions.contains(session) }
    }

    func session(id: Session.ID?) -> Session? {
        guard let id else { return nil }
        return sessions.first { $0.id == id }
    }

    func appendMessage(_ message: Message, to sessionID: Session.ID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[index].messages.append(message)
        sessions[index].updatedAt = Date()
    }

    func createSession(in folder: Folder?) -> Session {
        let now = Date()
        let session = Session(
            id: UUID(),
            name: "Session \(sessions.count + 1)",
            folderID: folder?.id,
            isPinned: false,
            locus: folder?.name ?? "VPPConsole",
            createdAt: now,
            updatedAt: now,
            messages: []
        )
        sessions.append(session)
        if let folderID = folder?.id, let index = folders.firstIndex(where: { $0.id == folderID }) {
            folders[index].sessions.append(session.id)
        }
        return session
    }

    func createFolder(name: String) -> Folder {
        let folder = Folder(id: UUID(), name: name, isPinned: false, sessions: [])
        folders.append(folder)
        return folder
    }

    func togglePin(folder: Folder) {
        guard let index = folders.firstIndex(of: folder) else { return }
        folders[index].isPinned.toggle()
    }

    func togglePin(session: Session) {
        guard let index = sessions.firstIndex(of: session) else { return }
        sessions[index].isPinned.toggle()
    }
}
