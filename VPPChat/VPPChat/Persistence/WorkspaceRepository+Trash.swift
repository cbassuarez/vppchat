//
//  WorkspaceRepository+Trash.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import Foundation
import GRDB

extension WorkspaceRepository {
    enum TrashKind: String, Codable, Hashable {
        case environment, project, track, scene, block
    }

    struct TrashRoot: Identifiable, Hashable {
        var id: UUID
        var kind: TrashKind
        var title: String
        var deletedAt: Date
        var childCount: Int
    }

    func fetchTrashRoots() throws -> [TrashRoot] {
        try pool.read { database in
            // Roots are entities where deletedRootID is NULL (we use deletedRootID to mark cascaded descendants)
            let env = try Row.fetchAll(database, sql: """
              SELECT id, name, deletedAt FROM environments
              WHERE deletedAt IS NOT NULL AND deletedRootID IS NULL
              ORDER BY deletedAt DESC;
            """)
            let proj = try Row.fetchAll(database, sql: """
              SELECT id, name, deletedAt FROM projects
              WHERE deletedAt IS NOT NULL AND deletedRootID IS NULL
              ORDER BY deletedAt DESC;
            """)
            let trk = try Row.fetchAll(database, sql: """
              SELECT id, name, deletedAt FROM tracks
              WHERE deletedAt IS NOT NULL AND deletedRootID IS NULL
              ORDER BY deletedAt DESC;
            """)
            let scn = try Row.fetchAll(database, sql: """
              SELECT id, title as name, deletedAt FROM scenes
              WHERE deletedAt IS NOT NULL AND deletedRootID IS NULL
              ORDER BY deletedAt DESC;
            """)
            let blk = try Row.fetchAll(database, sql: """
              SELECT id, title, deletedAt FROM blocks
              WHERE deletedAt IS NOT NULL AND deletedRootID IS NULL
              ORDER BY deletedAt DESC;
            """)

            func d(_ seconds: Double) -> Date { Date(timeIntervalSince1970: seconds) }

            var roots: [TrashRoot] = []

            for r in env {
                let id = UUID(uuidString: r["id"])!
                let name: String = r["name"]
                let deletedAt = d(r["deletedAt"])
                let childCount = (try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM projects WHERE deletedRootID=?;", arguments: [id.uuidString])) ?? 0
                roots.append(.init(id: id, kind: .environment, title: name, deletedAt: deletedAt, childCount: childCount))
            }
            for r in proj {
                let id = UUID(uuidString: r["id"])!
                let name: String = r["name"]
                let deletedAt = d(r["deletedAt"])
                let childCount = (try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM tracks WHERE deletedRootID=?;", arguments: [id.uuidString])) ?? 0
                roots.append(.init(id: id, kind: .project, title: name, deletedAt: deletedAt, childCount: childCount))
            }
            for r in trk {
                let id = UUID(uuidString: r["id"])!
                let name: String = r["name"]
                let deletedAt = d(r["deletedAt"])
                let childCount = (try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM scenes WHERE deletedRootID=?;", arguments: [id.uuidString])) ?? 0
                roots.append(.init(id: id, kind: .track, title: name, deletedAt: deletedAt, childCount: childCount))
            }
            for r in scn {
                let id = UUID(uuidString: r["id"])!
                let name: String = r["name"]
                let deletedAt = d(r["deletedAt"])
                let childCount = (try Int.fetchOne(database, sql: "SELECT COUNT(*) FROM blocks WHERE deletedRootID=?;", arguments: [id.uuidString])) ?? 0
                roots.append(.init(id: id, kind: .scene, title: name, deletedAt: deletedAt, childCount: childCount))
            }
            for r in blk {
                let id = UUID(uuidString: r["id"])!
                let title: String = r["title"]
                let deletedAt = d(r["deletedAt"])
                roots.append(.init(id: id, kind: .block, title: title, deletedAt: deletedAt, childCount: 0))
            }

            return roots.sorted(by: { $0.deletedAt > $1.deletedAt })
        }
    }

    // MARK: - Trash (cascade)

    func trashEnvironment(id: UUID) throws { try trashRoot(kind: .environment, id: id) }
    func trashProject(id: UUID) throws { try trashRoot(kind: .project, id: id) }
    func trashTrack(id: UUID) throws { try trashRoot(kind: .track, id: id) }
    func trashScene(id: UUID) throws { try trashRoot(kind: .scene, id: id) }
    func trashBlock(id: UUID) throws { try trashRoot(kind: .block, id: id) }

    private func trashRoot(kind: TrashKind, id: UUID) throws {
        let now = Date().timeIntervalSince1970
        try pool.write { database in
            func mark(_ table: String, idsSQL: String, args: [DatabaseValueConvertible]) throws {
                try database.execute(
                    sql: """
                    UPDATE \(table)
                    SET deletedAt=?, deletedRootID=COALESCE(deletedRootID, ?), updatedAt=updatedAt
                    WHERE id IN (\(idsSQL)) AND deletedAt IS NULL;
                    """,
                    arguments: [now, id.uuidString] + StatementArguments(args)
                )
            }

            switch kind {
            case .environment:
                try database.execute(sql: "UPDATE environments SET deletedAt=?, deletedRootID=NULL WHERE id=? AND deletedAt IS NULL;", arguments: [now, id.uuidString])
                // projects under env
                try database.execute(sql: "UPDATE projects SET deletedAt=?, deletedRootID=? WHERE environmentID=? AND deletedAt IS NULL;", arguments: [now, id.uuidString, id.uuidString])
                // tracks under those projects
                try database.execute(sql: """
                  UPDATE tracks SET deletedAt=?, deletedRootID=?
                  WHERE projectID IN (SELECT id FROM projects WHERE environmentID=?)
                  AND deletedAt IS NULL;
                """, arguments: [now, id.uuidString, id.uuidString])
                // scenes under those tracks
                try database.execute(sql: """
                  UPDATE scenes SET deletedAt=?, deletedRootID=?
                  WHERE trackID IN (
                    SELECT t.id FROM tracks t
                    JOIN projects p ON p.id = t.projectID
                    WHERE p.environmentID=?
                  )
                  AND deletedAt IS NULL;
                """, arguments: [now, id.uuidString, id.uuidString])
                // blocks under those scenes
                try database.execute(sql: """
                  UPDATE blocks SET deletedAt=?, deletedRootID=?
                  WHERE sceneID IN (
                    SELECT s.id FROM scenes s
                    JOIN tracks t ON t.id = s.trackID
                    JOIN projects p ON p.id = t.projectID
                    WHERE p.environmentID=?
                  )
                  AND deletedAt IS NULL;
                """, arguments: [now, id.uuidString, id.uuidString])

            case .project:
                try database.execute(sql: "UPDATE projects SET deletedAt=?, deletedRootID=NULL WHERE id=? AND deletedAt IS NULL;", arguments: [now, id.uuidString])
                try database.execute(sql: "UPDATE tracks SET deletedAt=?, deletedRootID=? WHERE projectID=? AND deletedAt IS NULL;", arguments: [now, id.uuidString, id.uuidString])
                try database.execute(sql: """
                  UPDATE scenes SET deletedAt=?, deletedRootID=?
                  WHERE trackID IN (SELECT id FROM tracks WHERE projectID=?)
                  AND deletedAt IS NULL;
                """, arguments: [now, id.uuidString, id.uuidString])
                try database.execute(sql: """
                  UPDATE blocks SET deletedAt=?, deletedRootID=?
                  WHERE sceneID IN (
                    SELECT s.id FROM scenes s
                    JOIN tracks t ON t.id = s.trackID
                    WHERE t.projectID=?
                  )
                  AND deletedAt IS NULL;
                """, arguments: [now, id.uuidString, id.uuidString])

            case .track:
                try database.execute(sql: "UPDATE tracks SET deletedAt=?, deletedRootID=NULL WHERE id=? AND deletedAt IS NULL;", arguments: [now, id.uuidString])
                try database.execute(sql: "UPDATE scenes SET deletedAt=?, deletedRootID=? WHERE trackID=? AND deletedAt IS NULL;", arguments: [now, id.uuidString, id.uuidString])
                try database.execute(sql: "UPDATE blocks SET deletedAt=?, deletedRootID=? WHERE sceneID IN (SELECT id FROM scenes WHERE trackID=?) AND deletedAt IS NULL;", arguments: [now, id.uuidString, id.uuidString])

            case .scene:
                try database.execute(sql: "UPDATE scenes SET deletedAt=?, deletedRootID=NULL WHERE id=? AND deletedAt IS NULL;", arguments: [now, id.uuidString])
                try database.execute(sql: "UPDATE blocks SET deletedAt=?, deletedRootID=? WHERE sceneID=? AND deletedAt IS NULL;", arguments: [now, id.uuidString, id.uuidString])

            case .block:
                try database.execute(sql: "UPDATE blocks SET deletedAt=?, deletedRootID=NULL WHERE id=? AND deletedAt IS NULL;", arguments: [now, id.uuidString])
            }
        }
    }

    // MARK: - Restore (destination picker)

    func restoreEnvironment(id: UUID) throws {
        try restoreRoot(kind: .environment, id: id, newParentID: nil)
    }

    func restoreProject(id: UUID, toEnvironmentID envID: UUID) throws {
        try restoreRoot(kind: .project, id: id, newParentID: envID)
    }

    func restoreTrack(id: UUID, toProjectID projectID: UUID) throws {
        try restoreRoot(kind: .track, id: id, newParentID: projectID)
    }

    func restoreScene(id: UUID, toTrackID trackID: UUID) throws {
        try restoreRoot(kind: .scene, id: id, newParentID: trackID)
    }

    private func restoreRoot(kind: TrashKind, id: UUID, newParentID: UUID?) throws {
        let now = Date().timeIntervalSince1970
        try pool.write { database in
            // Restore root + descendants that share deletedRootID = root id OR root itself (deletedRootID NULL)
            func clearDeleted(_ table: String, whereSQL: String, args: [DatabaseValueConvertible]) throws {
                try database.execute(
                    sql: "UPDATE \(table) SET deletedAt=NULL, deletedRootID=NULL, updatedAt=? WHERE \(whereSQL);",
                    arguments: [now] + StatementArguments(args)
                )
            }

            switch kind {
            case .environment:
                try clearDeleted("environments", whereSQL: "id=?", args: [id.uuidString])
                try clearDeleted("projects", whereSQL: "deletedRootID=?", args: [id.uuidString])
                try clearDeleted("tracks", whereSQL: "deletedRootID=?", args: [id.uuidString])
                try clearDeleted("scenes", whereSQL: "deletedRootID=?", args: [id.uuidString])
                try clearDeleted("blocks", whereSQL: "deletedRootID=?", args: [id.uuidString])

            case .project:
                guard let envID = newParentID else { return }
                try database.execute(sql: "UPDATE projects SET environmentID=? WHERE id=?;", arguments: [envID.uuidString, id.uuidString])
                try clearDeleted("projects", whereSQL: "id=?", args: [id.uuidString])
                try clearDeleted("tracks", whereSQL: "deletedRootID=?", args: [id.uuidString])
                try clearDeleted("scenes", whereSQL: "deletedRootID=?", args: [id.uuidString])
                try clearDeleted("blocks", whereSQL: "deletedRootID=?", args: [id.uuidString])

            case .track:
                guard let projID = newParentID else { return }
                try database.execute(sql: "UPDATE tracks SET projectID=? WHERE id=?;", arguments: [projID.uuidString, id.uuidString])
                try clearDeleted("tracks", whereSQL: "id=?", args: [id.uuidString])
                try clearDeleted("scenes", whereSQL: "deletedRootID=?", args: [id.uuidString])
                try clearDeleted("blocks", whereSQL: "deletedRootID=?", args: [id.uuidString])

            case .scene:
                guard let trackID = newParentID else { return }
                try database.execute(sql: "UPDATE scenes SET trackID=? WHERE id=?;", arguments: [trackID.uuidString, id.uuidString])
                try clearDeleted("scenes", whereSQL: "id=?", args: [id.uuidString])
                try clearDeleted("blocks", whereSQL: "deletedRootID=?", args: [id.uuidString])

            case .block:
                try clearDeleted("blocks", whereSQL: "id=?", args: [id.uuidString])
            }
        }
    }

    // MARK: - Empty trash (hard delete)

    func emptyTrash() throws {
        try pool.write { database in
            // Delete messages whose parent blocks are trashed
            try database.execute(sql: """
              DELETE FROM messages
              WHERE blockID IN (SELECT id FROM blocks WHERE deletedAt IS NOT NULL);
            """)
            // Delete trashed blocks
            try database.execute(sql: "DELETE FROM blocks WHERE deletedAt IS NOT NULL;")
            // Then scenes/tracks/projects/environments
            try database.execute(sql: "DELETE FROM scenes WHERE deletedAt IS NOT NULL;")
            try database.execute(sql: "DELETE FROM tracks WHERE deletedAt IS NOT NULL;")
            try database.execute(sql: "DELETE FROM projects WHERE deletedAt IS NOT NULL;")
            try database.execute(sql: "DELETE FROM environments WHERE deletedAt IS NOT NULL;")
            // Clear FTS rows referencing deleted entities (best effort)
            try database.execute(sql: """
              DELETE FROM fts_library
              WHERE entityKind IN ('block','message')
              AND (
                entityKind='block' AND entityID NOT IN (SELECT id FROM blocks)
                OR entityKind='message' AND entityID NOT IN (SELECT id FROM messages)
              );
            """)
        }
    }
}
