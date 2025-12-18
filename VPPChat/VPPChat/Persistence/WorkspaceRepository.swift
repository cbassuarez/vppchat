//
//  WorkspaceRepository.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import Foundation
import GRDB

final class WorkspaceRepository {
    private enum SystemRole {
      static let envInboxProject = "env_inbox_project"
      static let envInboxTrack   = "env_inbox_track"
    }

    @discardableResult
    func ensureInboxContainers(for environmentID: UUID) throws -> (projectID: UUID, trackID: UUID) {
      try pool.write { db in
        let now = Date().timeIntervalSince1970

        // project
        if let pidStr: String = try String.fetchOne(db, sql: """
          SELECT id FROM projects
          WHERE environmentID=? AND deletedAt IS NULL AND isSystem=1 AND systemRole=?
          LIMIT 1;
        """, arguments: [environmentID.uuidString, SystemRole.envInboxProject]),
           let pid = UUID(uuidString: pidStr) {

          // track
          if let tidStr: String = try String.fetchOne(db, sql: """
            SELECT t.id FROM tracks t
            WHERE t.projectID=? AND t.deletedAt IS NULL AND t.isSystem=1 AND t.systemRole=?
            LIMIT 1;
          """, arguments: [pid.uuidString, SystemRole.envInboxTrack]),
             let tid = UUID(uuidString: tidStr) {
            return (pid, tid)
          }

          // create missing track
          let tid = UUID()
          let sortIndex = (try Int.fetchOne(db, sql: """
            SELECT COALESCE(MAX(sortIndex), -1) + 1 FROM tracks
            WHERE projectID=? AND deletedAt IS NULL;
          """, arguments: [pid.uuidString])) ?? 0

          try db.execute(sql: """
            INSERT INTO tracks
            (id, projectID, name, sortIndex, lastOpenedSceneID, createdAt, updatedAt, deletedAt, deletedRootID, isSystem, systemRole)
            VALUES (?, ?, ?, ?, NULL, ?, ?, NULL, NULL, 1, ?);
          """, arguments: [tid.uuidString, pid.uuidString, "Chats", sortIndex, now, now, SystemRole.envInboxTrack])

          return (pid, tid)
        }

        // create missing project (+ track)
        let pid = UUID()
        let projSort = (try Int.fetchOne(db, sql: """
          SELECT COALESCE(MAX(sortIndex), -1) + 1 FROM projects
          WHERE environmentID=? AND deletedAt IS NULL;
        """, arguments: [environmentID.uuidString])) ?? 0

        try db.execute(sql: """
          INSERT INTO projects
          (id, environmentID, name, sortIndex, createdAt, updatedAt, deletedAt, deletedRootID, isSystem, systemRole)
          VALUES (?, ?, ?, ?, ?, ?, NULL, NULL, 1, ?);
        """, arguments: [pid.uuidString, environmentID.uuidString, "Inbox", projSort, now, now, SystemRole.envInboxProject])

        let tid = UUID()
        try db.execute(sql: """
          INSERT INTO tracks
          (id, projectID, name, sortIndex, lastOpenedSceneID, createdAt, updatedAt, deletedAt, deletedRootID, isSystem, systemRole)
          VALUES (?, ?, ?, 0, NULL, ?, ?, NULL, NULL, 1, ?);
        """, arguments: [tid.uuidString, pid.uuidString, "Chats", now, now, SystemRole.envInboxTrack])

        return (pid, tid)
      }
    }

    struct EnvironmentNode: Identifiable, Hashable {
      var id: UUID
      var name: String
      var inboxTrackID: UUID?          // <— env chats live here
      var envChats: [SceneNode]        // <— scenes under inboxTrackID
      var projects: [ProjectNode]      // <— NON-system only
    }

    struct ProjectNode: Identifiable, Hashable {
      var id: UUID
      var environmentID: UUID
      var name: String
      var isSystem: Bool
      var systemRole: String?
      var tracks: [TrackNode]
    }

    struct TrackNode: Identifiable, Hashable {
      var id: UUID
      var projectID: UUID
      var name: String
      var isSystem: Bool
      var systemRole: String?
      var scenes: [SceneNode]
    }

    struct SceneNode: Identifiable, Hashable {
        var id: UUID
        var trackID: UUID
        var title: String
        var blocks: [BlockNode]
    }

    struct BlockNode: Identifiable, Hashable {
        var id: UUID
        var sceneID: UUID
        var kind: String
        var title: String
        var isCanonical: Bool
    }

    struct Snapshot {
        var environments: [Row]
        var projects: [Row]
        var tracks: [Row]
        var scenes: [Row]
        var blocks: [Row]
        var messages: [Row]
    }

    private let db: WorkspaceDB
     // Expose only what extensions / callers need (keeps db encapsulated)

    var pool: DatabasePool { db.pool }
    var sqliteURL: URL { db.sqliteURL }
    init(db: WorkspaceDB) {
        self.db = db
    }

    // MARK: - Read

    func fetchLibraryTree(includeDeleted: Bool = false) throws -> [EnvironmentNode] {
        try pool.read { database in
            let whereClause = includeDeleted ? "WHERE 1=1" : "WHERE deletedAt IS NULL"
            let envRows = try Row.fetchAll(database, sql: "SELECT id, name FROM environments \(whereClause) ORDER BY sortIndex ASC, updatedAt DESC;")


            var envs: [EnvironmentNode] = []
            envs.reserveCapacity(envRows.count)

            // Bulk load everything once, then assemble
            let projRows = try Row.fetchAll(database, sql: """
              SELECT id, environmentID, name, isSystem, systemRole
              FROM projects
              \(whereClause)
              AND (isSystem IS NULL OR isSystem=0)
              ORDER BY sortIndex ASC, updatedAt DESC;
            """)
            let trackRows = try Row.fetchAll(database, sql: """
              SELECT id, projectID, name, isSystem, systemRole
              FROM tracks
              \(whereClause)
              AND (isSystem IS NULL OR isSystem=0)
              ORDER BY sortIndex ASC, updatedAt DESC;
            """)
            let sceneRows = try Row.fetchAll(database, sql: "SELECT id, trackID, title FROM scenes \(whereClause) ORDER BY sortIndex ASC, updatedAt DESC;")
            let blockRows = try Row.fetchAll(database, sql: "SELECT id, sceneID, kind, title, isCanonical FROM blocks \(whereClause) ORDER BY isCanonical DESC, updatedAt DESC;")
            let inboxRows = try Row.fetchAll(database, sql: """
              SELECT p.environmentID as envID, t.id as trackID
              FROM tracks t
              JOIN projects p ON p.id = t.projectID
              WHERE p.deletedAt IS NULL AND t.deletedAt IS NULL
                AND t.isSystem=1 AND t.systemRole='env_inbox_track'
            """)
            let inboxTrackByEnv: [UUID: UUID] = Dictionary(
              uniqueKeysWithValues: inboxRows.compactMap {
                guard let env = UUID(uuidString: $0["envID"]),
                      let tid = UUID(uuidString: $0["trackID"]) else { return nil }
                return (env, tid)
              }
            )
            let inboxTrackIDs = Array(inboxTrackByEnv.values)
               let envChatSceneRows: [Row]
               if inboxTrackIDs.isEmpty {
                 envChatSceneRows = []
               } else {
                 let placeholders = inboxTrackIDs.map { _ in "?" }.joined(separator: ",")
                 envChatSceneRows = try Row.fetchAll(database, sql: """
                   SELECT id, trackID, title
                   FROM scenes
                   \(whereClause)
                   AND trackID IN (\(placeholders))
                   ORDER BY sortIndex ASC, updatedAt DESC;
                 """, arguments: StatementArguments(inboxTrackIDs.map(\.uuidString)))
               }
               let envChatsByTrack = Dictionary(grouping: envChatSceneRows, by: { UUID(uuidString: $0["trackID"])! })



            let projectsByEnv = Dictionary(grouping: projRows, by: { UUID(uuidString: $0["environmentID"])! })
            let tracksByProject = Dictionary(grouping: trackRows, by: { UUID(uuidString: $0["projectID"])! })
            let scenesByTrack = Dictionary(grouping: sceneRows, by: { UUID(uuidString: $0["trackID"])! })
            let blocksByScene = Dictionary(grouping: blockRows, by: { UUID(uuidString: $0["sceneID"])! })

            for er in envRows {
                let envID = UUID(uuidString: er["id"])!
                let envName: String = er["name"]

                let projNodes: [ProjectNode] = (projectsByEnv[envID] ?? []).map { pr in
                    let pid = UUID(uuidString: pr["id"])!
                    let pname: String = pr["name"]
                    let pIsSystem = (pr["isSystem"] as Int?) == 1
                    let pRole: String? = pr["systemRole"]

                    let trackNodes: [TrackNode] = (tracksByProject[pid] ?? []).map { tr in
                        let tid = UUID(uuidString: tr["id"])!
                        let tname: String = tr["name"]
                        let tIsSystem = (tr["isSystem"] as Int?) == 1
                        let tRole: String? = tr["systemRole"]


                        let sceneNodes: [SceneNode] = (scenesByTrack[tid] ?? []).map { sr in
                            let sid = UUID(uuidString: sr["id"])!
                            let stitle: String = sr["title"]

                            let bnodes: [BlockNode] = (blocksByScene[sid] ?? []).map { br in
                                BlockNode(
                                    id: UUID(uuidString: br["id"])!,
                                    sceneID: sid,
                                    kind: br["kind"],
                                    title: br["title"],
                                    isCanonical: (br["isCanonical"] as Int) == 1
                                )
                            }

                            return SceneNode(id: sid, trackID: tid, title: stitle, blocks: bnodes)
                        }

                        return TrackNode(id: tid, projectID: pid, name: tname, isSystem: tIsSystem, systemRole: tRole, scenes: sceneNodes)
                    }

                    return ProjectNode(id: pid, environmentID: envID, name: pname, isSystem: pIsSystem, systemRole: pRole, tracks: trackNodes)
                }

                let inboxTrackID = inboxTrackByEnv[envID]
                let envChats: [SceneNode] = (inboxTrackID.flatMap { envChatsByTrack[$0] } ?? []).map { sr in
                  SceneNode(id: UUID(uuidString: sr["id"])!, trackID: inboxTrackID!, title: sr["title"], blocks: [])
                }

                envs.append(EnvironmentNode(
                  id: envID,
                  name: envName,
                  inboxTrackID: inboxTrackID,
                  envChats: envChats,
                  projects: projNodes
                ))
            }

            return envs
        }
    }

    func snapshot(includeDeleted: Bool = true) throws -> Snapshot {
        try pool.read { database in
            let whereDeleted = includeDeleted ? "" : "WHERE deletedAt IS NULL"
            return Snapshot(
                environments: try Row.fetchAll(database, sql: "SELECT * FROM environments \(whereDeleted);"),
                projects: try Row.fetchAll(database, sql: "SELECT * FROM projects \(whereDeleted);"),
                tracks: try Row.fetchAll(database, sql: "SELECT * FROM tracks \(whereDeleted);"),
                scenes: try Row.fetchAll(database, sql: "SELECT * FROM scenes \(whereDeleted);"),
                blocks: try Row.fetchAll(database, sql: "SELECT * FROM blocks \(whereDeleted);"),
                messages: try Row.fetchAll(database, sql: "SELECT * FROM messages;")
            )
        }
    }

    // MARK: - Create

    @discardableResult
    func createEnvironment(name: String) throws -> UUID {
        let id = UUID()
        let now = Date().timeIntervalSince1970
        try db.pool.write { database in
            let sortIndex = (try Int.fetchOne(database, sql: "SELECT COALESCE(MAX(sortIndex), -1) + 1 FROM environments WHERE deletedAt IS NULL;")) ?? 0
            try database.execute(
                sql: "INSERT INTO environments (id, name, sortIndex, createdAt, updatedAt, deletedAt, deletedRootID) VALUES (?, ?, ?, ?, ?, NULL, NULL);",
                arguments: [id.uuidString, name, sortIndex, now, now]
            )
        }
        return id
    }

    @discardableResult
    func createProject(environmentID: UUID, name: String) throws -> UUID {
        let id = UUID()
        let now = Date().timeIntervalSince1970
        try db.pool.write { database in
            let sortIndex = (try Int.fetchOne(database, sql: "SELECT COALESCE(MAX(sortIndex), -1) + 1 FROM projects WHERE environmentID=? AND deletedAt IS NULL;", arguments: [environmentID.uuidString])) ?? 0
            try database.execute(
                sql: "INSERT INTO projects (id, environmentID, name, sortIndex, createdAt, updatedAt, deletedAt, deletedRootID) VALUES (?, ?, ?, ?, ?, ?, NULL, NULL);",
                arguments: [id.uuidString, environmentID.uuidString, name, sortIndex, now, now]
            )
            try database.execute(sql: "UPDATE environments SET updatedAt=? WHERE id=?;", arguments: [now, environmentID.uuidString])
        }
        return id
    }

    @discardableResult
    func createTrack(projectID: UUID, name: String) throws -> UUID {
        let id = UUID()
        let now = Date().timeIntervalSince1970
        try db.pool.write { database in
            let sortIndex = (try Int.fetchOne(database, sql: "SELECT COALESCE(MAX(sortIndex), -1) + 1 FROM tracks WHERE projectID=? AND deletedAt IS NULL;", arguments: [projectID.uuidString])) ?? 0
            try database.execute(
                sql: "INSERT INTO tracks (id, projectID, name, sortIndex, lastOpenedSceneID, createdAt, updatedAt, deletedAt, deletedRootID) VALUES (?, ?, ?, ?, NULL, ?, ?, NULL, NULL);",
                arguments: [id.uuidString, projectID.uuidString, name, sortIndex, now, now]
            )
            try database.execute(sql: "UPDATE projects SET updatedAt=? WHERE id=?;", arguments: [now, projectID.uuidString])
        }
        return id
    }

    @discardableResult
    func createScene(trackID: UUID, title: String) throws -> UUID {
        let id = UUID()
        let now = Date().timeIntervalSince1970
        try db.pool.write { database in
            let trackExists = try Int.fetchOne(
                  database,
                  sql: "SELECT 1 FROM tracks WHERE id=? AND deletedAt IS NULL LIMIT 1;",
                  arguments: [trackID.uuidString]
                ) != nil
                guard trackExists else {
                  throw NSError(
                    domain: "WorkspaceRepository",
                    code: 19,
                    userInfo: [NSLocalizedDescriptionKey:
                      "FK: createScene failed because topic \(trackID) is not in `tracks`. Ensure the topic is persisted before creating a scene."
                    ]
                  )
                }

            let sortIndex = (try Int.fetchOne(database, sql: "SELECT COALESCE(MAX(sortIndex), -1) + 1 FROM scenes WHERE trackID=? AND deletedAt IS NULL;", arguments: [trackID.uuidString])) ?? 0
            try database.execute(
                sql: "INSERT INTO scenes (id, trackID, title, sortIndex, createdAt, updatedAt, deletedAt, deletedRootID) VALUES (?, ?, ?, ?, ?, ?, NULL, NULL);",
                arguments: [id.uuidString, trackID.uuidString, title, sortIndex, now, now]
            )
            try database.execute(sql: "UPDATE tracks SET updatedAt=? WHERE id=?;", arguments: [now, trackID.uuidString])
        }
        return id
    }

    // MARK: - Rename

    func renameEnvironment(id: UUID, name: String) throws {
        let now = Date().timeIntervalSince1970
        try db.pool.write { database in
            try database.execute(sql: "UPDATE environments SET name=?, updatedAt=? WHERE id=?;", arguments: [name, now, id.uuidString])
        }
    }

    func renameProject(id: UUID, name: String) throws {
        let now = Date().timeIntervalSince1970
        try db.pool.write { database in
            try database.execute(sql: "UPDATE projects SET name=?, updatedAt=? WHERE id=?;", arguments: [name, now, id.uuidString])
        }
    }

    func renameTrack(id: UUID, name: String) throws {
        let now = Date().timeIntervalSince1970
        try db.pool.write { database in
            try database.execute(sql: "UPDATE tracks SET name=?, updatedAt=? WHERE id=?;", arguments: [name, now, id.uuidString])
        }
    }

    func renameScene(id: UUID, title: String) throws {
        let now = Date().timeIntervalSince1970
        try db.pool.write { database in
            try database.execute(sql: "UPDATE scenes SET title=?, updatedAt=? WHERE id=?;", arguments: [title, now, id.uuidString])
        }
    }

    // MARK: - Move

    func moveProject(projectID: UUID, toEnvironmentID envID: UUID) throws {
        let now = Date().timeIntervalSince1970
        try db.pool.write { database in
            try database.execute(sql: "UPDATE projects SET environmentID=?, updatedAt=? WHERE id=? AND deletedAt IS NULL;", arguments: [envID.uuidString, now, projectID.uuidString])
            try database.execute(sql: "UPDATE environments SET updatedAt=? WHERE id=?;", arguments: [now, envID.uuidString])
        }
    }

    func moveTrack(trackID: UUID, toProjectID projID: UUID) throws {
        let now = Date().timeIntervalSince1970
        try db.pool.write { database in
            try database.execute(sql: "UPDATE tracks SET projectID=?, updatedAt=? WHERE id=? AND deletedAt IS NULL;", arguments: [projID.uuidString, now, trackID.uuidString])
            try database.execute(sql: "UPDATE projects SET updatedAt=? WHERE id=?;", arguments: [now, projID.uuidString])
        }
    }

    func moveScene(sceneID: UUID, toTrackID trackID: UUID) throws {
        let now = Date().timeIntervalSince1970
        try db.pool.write { database in
            try database.execute(sql: "UPDATE scenes SET trackID=?, updatedAt=? WHERE id=? AND deletedAt IS NULL;", arguments: [trackID.uuidString, now, sceneID.uuidString])
            try database.execute(sql: "UPDATE tracks SET updatedAt=? WHERE id=?;", arguments: [now, trackID.uuidString])
        }
    }
// MARK: - Reordering (sortIndex)
    func setProjectOrder(environmentID: UUID, orderedProjectIDs: [UUID]) throws {
           let now = Date().timeIntervalSince1970
           try db.pool.write { database in

            for (idx, id) in orderedProjectIDs.enumerated() {
                try database.execute(
                    sql: "UPDATE projects SET sortIndex=?, updatedAt=? WHERE id=? AND environmentID=?;",
                    arguments: [idx, now, id.uuidString, environmentID.uuidString]
                )
            }
        }
    }

    func setTrackOrder(projectID: UUID, orderedTrackIDs: [UUID]) throws {
           let now = Date().timeIntervalSince1970
           try db.pool.write { database in
            for (idx, id) in orderedTrackIDs.enumerated() {
                try database.execute(
                    sql: "UPDATE tracks SET sortIndex=?, updatedAt=? WHERE id=? AND projectID=?;",
                    arguments: [idx, now, id.uuidString, projectID.uuidString]
                )
            }
        }
    }

    func setSceneOrder(trackID: UUID, orderedSceneIDs: [UUID]) throws {
            let now = Date().timeIntervalSince1970
            try db.pool.write { database in
            for (idx, id) in orderedSceneIDs.enumerated() {
                try database.execute(
                    sql: "UPDATE scenes SET sortIndex=?, updatedAt=? WHERE id=? AND trackID=?;",
                    arguments: [idx, now, id.uuidString, trackID.uuidString]
                )
            }
        }
    }

}
