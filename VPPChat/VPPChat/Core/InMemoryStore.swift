import Foundation
import Combine
import GRDB

final class InMemoryStore: ObservableObject {
    @Published var folders: [Folder]
    @Published var sessions: [Session]
    var repo: WorkspaceRepository?
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
        return ([defaultFolder], [])
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
        // ✅ DB write-through (no-op if repo not set yet)
            guard let repo else { return }
            do {
                let blockID = sessionID  // sessions currently map 1:1 to conversation blocks
                let sourcesTableJSON = String(data: (try JSONEncoder().encode(message.sourcesTable)), encoding: .utf8) ?? "[]"
                let issuesJSON = String(data: (try JSONEncoder().encode(message.validationIssues)), encoding: .utf8) ?? "[]"
                try repo.pool.write { db in
                    try db.execute(sql: """
                      INSERT OR REPLACE INTO messages
                      (id, blockID, isUser, timestamp, body, tag, cycleIndex, assumptions, sources, sourcesTableJSON, locus, isValidVpp, validationIssuesJSON)
                      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                    """, arguments: [
                        message.id.uuidString,
                        blockID.uuidString,
                        message.isUser ? 1 : 0,
                        message.timestamp.timeIntervalSince1970,
                        message.body,
                        message.tag.rawValue,
                        message.cycleIndex,
                        message.assumptions,
                        message.sources.rawValue,
                        sourcesTableJSON,
                        message.locus,
                        message.isValidVpp ? 1 : 0,
                        issuesJSON
                    ])
                }
            } catch {
                print("❌ appendMessage persistence failed: \(error)")
            }
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
