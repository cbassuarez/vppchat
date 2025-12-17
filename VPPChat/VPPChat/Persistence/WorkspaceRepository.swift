//
//  WorkspaceRepository.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import Foundation
import GRDB

final class WorkspaceRepository {
    struct EnvironmentNode: Identifiable, Hashable {
        var id: UUID
        var name: String
        var projects: [ProjectNode]
    }

    struct ProjectNode: Identifiable, Hashable {
        var id: UUID
        var environmentID: UUID
        var name: String
        var tracks: [TrackNode]
    }

    struct TrackNode: Identifiable, Hashable {
        var id: UUID
        var projectID: UUID
        var name: String
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
            let whereDeleted = includeDeleted ? "" : "WHERE deletedAt IS NULL"
            let envRows = try Row.fetchAll(database, sql: "SELECT id, name FROM environments \(whereDeleted) ORDER BY sortIndex ASC, updatedAt DESC;")

            var envs: [EnvironmentNode] = []
            envs.reserveCapacity(envRows.count)

            // Bulk load everything once, then assemble
            let projRows = try Row.fetchAll(database, sql: "SELECT id, environmentID, name FROM projects \(whereDeleted) ORDER BY sortIndex ASC, updatedAt DESC;")
            let trackRows = try Row.fetchAll(database, sql: "SELECT id, projectID, name FROM tracks \(whereDeleted) ORDER BY sortIndex ASC, updatedAt DESC;")
            let sceneRows = try Row.fetchAll(database, sql: "SELECT id, trackID, title FROM scenes \(whereDeleted) ORDER BY sortIndex ASC, updatedAt DESC;")
            let blockRows = try Row.fetchAll(database, sql: "SELECT id, sceneID, kind, title, isCanonical FROM blocks \(whereDeleted) ORDER BY isCanonical DESC, updatedAt DESC;")

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

                    let trackNodes: [TrackNode] = (tracksByProject[pid] ?? []).map { tr in
                        let tid = UUID(uuidString: tr["id"])!
                        let tname: String = tr["name"]

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

                        return TrackNode(id: tid, projectID: pid, name: tname, scenes: sceneNodes)
                    }

                    return ProjectNode(id: pid, environmentID: envID, name: pname, tracks: trackNodes)
                }

                envs.append(EnvironmentNode(id: envID, name: envName, projects: projNodes))
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
                      "FK: createScene failed because track \(trackID) is not in `tracks`. Ensure the track is persisted before creating a scene."
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
}
