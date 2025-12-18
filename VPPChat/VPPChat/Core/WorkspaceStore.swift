import Foundation
import Combine
import GRDB

final class WorkspaceStore: ObservableObject {
private var repo: WorkspaceRepository?
    var requestAutoTitleScene: (@MainActor (UUID) async -> Void)?
    private var requestedAutoTitleSceneIDs: Set<UUID> = []

    private var didBootstrapFromRepo = false
    var isSeedOnlyWorkspace: Bool {
      // “seed-only” = nothing beyond the seeded Getting Started container + canonical messages,
      // ignoring the Console container if it exists.

      // 1) Projects: only allow Getting Started + Console
      let userProjectExists = projects.values.contains { p in
        p.name != gettingStartedProjectName && p.name != consoleProjectName
      }
      if userProjectExists { return false }

      // 2) topics: only allow Basics + Sessions
      let userTrackExists = tracks.values.contains { t in
        t.name != gettingStartedTrackName && t.name != consoleTrackName
      }
      if userTrackExists { return false }

      // 3) chats: only allow Welcome + Console Chats
      let userSceneExists = scenes.values.contains { s in
        s.title != gettingStartedSceneTitle && s.title != consoleSceneTitle
      }
      if userSceneExists { return false }

      // 4) messages: allow only canonical welcome + (optional) canonical model messages
      let allowedCanonical: Set<UUID> = [
        Self.canonicalWelcomeBlockID,
        Self.canonicalModelDocBlockID,
        Self.canonicalModelChatBlockID
      ]

      let hasAnyUserBlock = blocks.values.contains { b in
        if b.isCanonical { return !allowedCanonical.contains(b.id) }
        return true
      }

      return hasAnyUserBlock == false
    }


    static let canonicalModelDocBlockID = UUID(uuidString: "00000000-0000-0000-0000-000000000008")!
     static let canonicalModelChatBlockID = UUID(uuidString: "00000000-0000-0000-0000-000000000009")!


  @discardableResult
  func ensureGettingStartedModelSeeded() -> (doc: Block, chat: Block) {
      let sceneID = ensureGettingStartedSceneID()

    let docText = """
    **How work is organized**

    Environment → Project → Topic → Chat → Messages

    - **Environment**: top-level space
    - **Project**: a body of work inside an environment
    - **Topic**: parallel lanes inside a project
    - **Chat**: a container for messages
    - **Messages**: Chat (turns) and Docs (notes)
    """

    // Doc block (idempotent)
    let docID = Self.canonicalModelDocBlockID
    let doc = Block(
      id: docID,
      sceneID: sceneID,
      kind: .document,
      title: "How Work Is Organized",
      subtitle: "READ ME FIRST",
      messages: [],
      documentText: docText,
      isCanonical: true,
      createdAt: .now,
      updatedAt: .now
    )
    blocks[docID] = doc
    persistUpsertBlock(doc)

    // Chat block (idempotent)
    let chatID = Self.canonicalModelChatBlockID
    var chat = blocks[chatID] ?? Block(
      id: chatID,
      sceneID: sceneID,
      kind: .conversation,
      title: "Setup Assistant",
      subtitle: "Tell me what you’re working on",
      messages: [],
      documentText: nil,
      isCanonical: true,
      createdAt: .now,
      updatedAt: .now
    )
    chat.sceneID = sceneID
    chat.kind = .conversation
    chat.title = "Setup Assistant"
    chat.subtitle = "Tell me what you’re working on"
    chat.isCanonical = true
    blocks[chatID] = chat
    persistUpsertBlock(chat)

    // Seed first assistant message only if empty
    if blocks[chatID]?.messages.isEmpty == true {
      let m = Message(
        id: UUID(),
        isUser: false,
        timestamp: .now,
        body: "Tell me what you’re working on — I’ll propose a Project ▸ Topic ▸ Chat plan.",
        tag: .g,
        cycleIndex: 1,
        assumptions: 0,
        sources: .none,
        sourcesTable: [],
        locus: "Onboarding",
        isValidVpp: true,
        validationIssues: []
      )
      appendMessage(to: chatID, m)
    }

    objectWillChange.send()
    return (blocks[docID]!, blocks[chatID]!)
  }

    func setRepository(_ repo: WorkspaceRepository?) {
        self.repo = repo
        guard repo != nil, didBootstrapFromRepo == false else { return }
           didBootstrapFromRepo = true
           do { try loadFromRepository() } catch { print("❌ loadFromRepository failed: \(error)") }
           _ = ensureWelcomeConversationSeeded()
        objectWillChange.send()

    }

    func loadFromRepository() throws {
        guard let repo else { return }
        let snap = try repo.snapshot(includeDeleted: false)

        // ⚠️ Minimal implementation: rebuild in-memory dictionaries from DB.
        // This assumes you already store messages/chats/topics/projects in dictionaries as seen in your code.
        // 1) Clear
        blocks.removeAll()
        scenes.removeAll()
        tracks.removeAll()
        projects.removeAll()

        // 2) Rehydrate base graph (projects/tracks/scenes)
        // These initializers must exist in your models:
        // Project(id:name:tracks:lastOpenedTrackID:)
        // Track(id:projectID:name:scenes:lastOpenedSceneID:)
        // Scene(id:trackID:title:)

        // Projects
        for r in snap.projects {
            let id = UUID(uuidString: r["id"])!
            let name: String = r["name"]
            projects[id] = Project(id: id, name: name)
        }
        // topics
        for r in snap.tracks {
            let id = UUID(uuidString: r["id"])!
            let projectID = UUID(uuidString: r["projectID"])!
            let name: String = r["name"]
            tracks[id] = Track(id: id, projectID: projectID, name: name)
                        if var p = projects[projectID] {
                            p.tracks.append(id)
                            projects[projectID] = p
                        }
        }
        // chats
        for r in snap.scenes {
            let id = UUID(uuidString: r["id"])!
            let trackID = UUID(uuidString: r["trackID"])!
            let title: String = r["title"]
            scenes[id] = Scene(id: id, trackID: trackID, title: title)
                        if var t = tracks[trackID] {
                            t.scenes.append(id)
                            tracks[trackID] = t
                        }
        }

        // messages
        for r in snap.blocks {
            let id = UUID(uuidString: r["id"])!
            let sceneID = UUID(uuidString: r["sceneID"])!
            let kindRaw: String = r["kind"]
            let title: String = r["title"]
            let subtitle: String? = r["subtitle"]
            let isCanonicalInt: Int = r["isCanonical"]
            let isCanonical = isCanonicalInt == 1
            let documentText: String? = r["documentText"]

            let createdAtSeconds: Double = r["createdAt"]
                        let updatedAtSeconds: Double = r["updatedAt"]
                        let createdAt = Date(timeIntervalSince1970: createdAtSeconds)
                        let updatedAt = Date(timeIntervalSince1970: updatedAtSeconds)
            
                        // ✅ Block.Kind doesn’t exist in your model — your kind enum is top-level.
                        let kind = BlockKind(rawValue: kindRaw) ?? .document

            blocks[id] = Block(
                id: id,
                sceneID: sceneID,
                kind: kind,
                title: title,
                subtitle: subtitle,
                messages: [],
                documentText: documentText,
                isCanonical: isCanonical,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }

        // Messages → attach to messages
        for r in snap.messages {
            let id = UUID(uuidString: r["id"])!
            let blockID = UUID(uuidString: r["blockID"])!
            let isUserInt: Int = r["isUser"]
                        let isUser = isUserInt == 1
                        let timestampSeconds: Double = r["timestamp"]
                        let timestamp = Date(timeIntervalSince1970: timestampSeconds)
            let body: String = r["body"]
            let tagRaw: String = r["tag"]
            let cycleIndex: Int = r["cycleIndex"]
            let assumptions: Int = r["assumptions"]
            let sources: String = r["sources"]
            let sourcesTableJSON: String = r["sourcesTableJSON"]
            let locus: String = r["locus"]
            let isValidVppInt: Int = r["isValidVpp"]
            let isValidVpp = isValidVppInt == 1
            let validationIssuesJSON: String = r["validationIssuesJSON"]
            
            // ✅ DB stores tag as TEXT; Message expects VppTag
            let tag = VppTag(rawValue: tagRaw) ?? .g

            // Your Message initializer differs; map here to your existing type.
            let msg = Message(
                id: id,
                isUser: isUser,
                timestamp: timestamp,
                body: body,
                tag: tag,
                cycleIndex: cycleIndex,
                assumptions: assumptions,
                sources: VppSources(rawValue: sources) ?? .none,
                sourcesTable: (try? JSONDecoder().decode([VppSourceRef].self, from: Data(sourcesTableJSON.utf8))) ?? [],
                locus: locus,
                isValidVpp: isValidVpp,
                validationIssues: (try? JSONDecoder().decode([String].self, from: Data(validationIssuesJSON.utf8))) ?? []
            )

            // ✅ Block is a struct; mutate via local var + reassign
                        if var b = blocks[blockID] {
                            b.messages.append(msg)
                            blocks[blockID] = b
                        }
        }

        // Notify
        objectWillChange.send()
    }
    // MARK: - Canonical onboarding
    static let canonicalWelcomeMessageID = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
    static let canonicalWelcomeBlockID = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
        private var gettingStartedProjectName: String { "Getting Started" }
    private var gettingStartedTrackName: String { "Basics" }
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
            objectWillChange.send()
            purgeLegacyWelcomeArtifacts()
            
                    let sceneID = ensureGettingStartedSceneID()
                    let id = Self.canonicalWelcomeBlockID
            let msgID = Self.canonicalWelcomeMessageID

                    let welcomeBody = """
            Welcome to **VPP Studio** 👋
            
            This is the **single canonical Welcome chat** shared across **Console / Studio / Atlas**.
            
            ### How this app is structured
            **Project ▸ Topic ▸ Chat ▸ Messages**
            - **Conversation messages** are “turns” (Console shows the same thing).
            - **Documents** are saved notes (from Console “Save block”, etc.).
            
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
                        id: msgID,
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
                        let hasWelcomeMessage = existing.messages.contains(where: { $0.id == msgID })
                               let hasCorrectBody = existing.messages.first(where: { $0.id == msgID })?.body == welcomeBody
                               let needsShapeRepair =
                                   existing.sceneID != sceneID ||
                                   existing.kind != .conversation ||
                                   existing.title != "Welcome" ||
                                   existing.subtitle != "G_1 · 0 assumptions · GETTING-STARTED" ||
                                   existing.isCanonical != true
                       
                               // If everything is already correct, do nothing (no updatedAt churn).
                               if !needsShapeRepair && hasWelcomeMessage && hasCorrectBody {
                                   return existing
                               }
                       
                               // Repair in-place (stable IDs). Keep updatedAt stable unless we’re creating it from scratch.
                               existing.sceneID = sceneID
                               existing.kind = .conversation
                               existing.title = "Welcome"
                               existing.subtitle = "G_1 · 0 assumptions · GETTING-STARTED"
                               existing.isCanonical = true
                       
                               // Ensure exactly one canonical welcome assistant message.
                               existing.messages.removeAll(where: { $0.locus == "Welcome" || $0.id == msgID })
                               existing.messages = [welcomeAssistant]
                       
                               blocks[id] = existing
                        objectWillChange.send()

                               persistUpsertBlock(existing)
                               persistAppendMessage(blockID: id, message: welcomeAssistant, newBlockUpdatedAt: existing.updatedAt)
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
            objectWillChange.send()
            persistUpsertBlock(block)
            persistAppendMessage(blockID: id, message: welcomeAssistant, newBlockUpdatedAt: block.updatedAt)
                    return block
        }
    func block(id: Block.ID?) -> Block? {
        guard let id else { return nil }
        return blocks[id]
    }

    func update(block: Block) {
        objectWillChange.send()
        blocks[block.id] = block
        persistUpsertBlock(block)

    }

    // MARK: - Console container (Project ▸ Topic ▸ Chat)

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

    // MARK: - Getting Started container (Project ▸ Topic ▸ Scene)
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
        add(block: block)
        return block
    }
    init() {}

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
        persistUpsertBlock(block)
    }

    private func seedDemoData() {
        // Production seed: single canonical Welcome only
            _ = ensureWelcomeConversationSeeded()
    }
    
    @MainActor
    func appendMessage(to blockID: Block.ID, _ message: Message) {
        guard var block = blocks[blockID] else { return }
        if block.messages.contains(where: { $0.id == message.id }) { return }
        block.messages.append(message)
        block.updatedAt = .now
        blocks[blockID] = block
        
        // ✅ Persist: message row + bump block.updatedAt in DB (no-op if repo not set)
                persistAppendMessage(blockID: blockID, message: message, newBlockUpdatedAt: block.updatedAt)
        
                // ✅ Auto-title: only for newly-created chats (placeholder title)
        if message.isUser, let sceneID = blocks[blockID]?.sceneID {
              maybeRequestCompletionAutoTitle(sceneID: sceneID)
            }

    }

// MARK: - Persistence (write-through)
    private func persistUpsertBlock(_ block: Block) {
        guard let repo else { return }
        do {
            let createdAt = block.createdAt.timeIntervalSince1970
            let updatedAt = block.updatedAt.timeIntervalSince1970
            try repo.pool.write { db in
                let args = (StatementArguments([
                                   block.id.uuidString,
                                   block.sceneID.uuidString,
                                   block.kind.rawValue,
                                   block.title,
                                   block.subtitle,          // String?
                                   block.isCanonical ? 1 : 0,
                                   block.documentText,      // String?
                                   createdAt,
                                   updatedAt
                               ]) ?? StatementArguments())
                try db.execute(sql: """
                  INSERT OR REPLACE INTO blocks
                  (id, sceneID, kind, title, subtitle, isCanonical, documentText, createdAt, updatedAt, deletedAt, deletedRootID)
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL);
                  """, arguments: args)
            }
        } catch {
            print("❌ persistUpsertBlock failed: \(error)")
        }
    }

    private func persistAppendMessage(blockID: UUID, message: Message, newBlockUpdatedAt: Date) {
        guard let repo else { return }
        do {
            let sourcesTableJSON = String(data: (try JSONEncoder().encode(message.sourcesTable)), encoding: .utf8) ?? "[]"
            let issuesJSON = String(data: (try JSONEncoder().encode(message.validationIssues)), encoding: .utf8) ?? "[]"
            try repo.pool.write { db in
                // message
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
                // bump block.updatedAt
                try db.execute(
                    sql: "UPDATE blocks SET updatedAt=? WHERE id=?;",
                    arguments: [newBlockUpdatedAt.timeIntervalSince1970, blockID.uuidString]
                )
            }
        } catch {
            print("❌ persistAppendMessage failed: \(error)")
        }
    }

    // MARK: - Auto chat naming (after first user turn)
    @MainActor
      private func maybeRequestCompletionAutoTitle(sceneID: UUID) {
        guard let scene = scenes[sceneID] else { return }
        guard scene.title == "Untitled" else { return }
        guard requestedAutoTitleSceneIDs.insert(sceneID).inserted else { return } // one-shot
        guard let requestAutoTitleScene else { return }
        Task { await requestAutoTitleScene(sceneID) }
      }

    func allBlocksSortedByUpdatedAtDescending() -> [Block] {
        blocks.values.sorted { $0.updatedAt > $1.updatedAt }
    }
    // MARK: - Migration / purge
        func purgeLegacyWelcomeArtifacts() {
            // 1) Remove the old demo project (seed-only)
            if let demo = projects.values.first(where: { $0.name == "GlassGPT Export" }) {
                // remove topics + chats
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
