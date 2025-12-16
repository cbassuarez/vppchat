//
//  WorkspaceDB.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import Foundation
import GRDB

final class WorkspaceDB {
    let id: UUID
    let sqliteURL: URL
    let pool: DatabasePool

    init(workspaceID: UUID, sqliteURL: URL) throws {
        self.id = workspaceID
        self.sqliteURL = sqliteURL

        var config = Configuration()
        config.foreignKeysEnabled = true
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL;")
            try db.execute(sql: "PRAGMA synchronous = NORMAL;")
            try db.execute(sql: "PRAGMA busy_timeout = 2000;")
        }

        self.pool = try DatabasePool(path: sqliteURL.path, configuration: config)
        try Self.migrator.migrate(pool)
    }
}

// MARK: - Migrations

extension WorkspaceDB {
    enum SeedIDs {
        static let envMain = "00000000-0000-0000-0000-000000000001"
        static let projGettingStarted = "00000000-0000-0000-0000-000000000002"
        static let track1 = "00000000-0000-0000-0000-000000000003"
        static let sceneChat = "00000000-0000-0000-0000-000000000004"
        static let welcomeBlock = "00000000-0000-0000-0000-000000000005"
    }

    static var migrator: DatabaseMigrator = {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_init") { db in
            // Core tables
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS workspace_settings (
                id TEXT PRIMARY KEY NOT NULL,
                defaultModelID TEXT NOT NULL,
                defaultTemperature REAL NOT NULL,
                defaultContextStrategy TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS environments (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                sortIndex INTEGER NOT NULL,
                createdAt REAL NOT NULL,
                updatedAt REAL NOT NULL,
                deletedAt REAL NULL,
                deletedRootID TEXT NULL
            );

            CREATE TABLE IF NOT EXISTS projects (
                id TEXT PRIMARY KEY NOT NULL,
                environmentID TEXT NOT NULL REFERENCES environments(id) ON DELETE CASCADE,
                name TEXT NOT NULL,
                sortIndex INTEGER NOT NULL,
                createdAt REAL NOT NULL,
                updatedAt REAL NOT NULL,
                deletedAt REAL NULL,
                deletedRootID TEXT NULL
            );

            CREATE TABLE IF NOT EXISTS tracks (
                id TEXT PRIMARY KEY NOT NULL,
                projectID TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
                name TEXT NOT NULL,
                sortIndex INTEGER NOT NULL,
                lastOpenedSceneID TEXT NULL,
                createdAt REAL NOT NULL,
                updatedAt REAL NOT NULL,
                deletedAt REAL NULL,
                deletedRootID TEXT NULL
            );

            CREATE TABLE IF NOT EXISTS scenes (
                id TEXT PRIMARY KEY NOT NULL,
                trackID TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
                title TEXT NOT NULL,
                sortIndex INTEGER NOT NULL,
                createdAt REAL NOT NULL,
                updatedAt REAL NOT NULL,
                deletedAt REAL NULL,
                deletedRootID TEXT NULL
            );

            CREATE TABLE IF NOT EXISTS blocks (
                id TEXT PRIMARY KEY NOT NULL,
                sceneID TEXT NOT NULL REFERENCES scenes(id) ON DELETE CASCADE,
                kind TEXT NOT NULL,
                title TEXT NOT NULL,
                subtitle TEXT NULL,
                isCanonical INTEGER NOT NULL,
                documentText TEXT NULL,
                createdAt REAL NOT NULL,
                updatedAt REAL NOT NULL,
                deletedAt REAL NULL,
                deletedRootID TEXT NULL
            );

            CREATE TABLE IF NOT EXISTS messages (
                id TEXT PRIMARY KEY NOT NULL,
                blockID TEXT NOT NULL REFERENCES blocks(id) ON DELETE CASCADE,
                isUser INTEGER NOT NULL,
                timestamp REAL NOT NULL,
                body TEXT NOT NULL,
                tag TEXT NOT NULL,
                cycleIndex INTEGER NOT NULL,
                assumptions INTEGER NOT NULL,
                sources TEXT NOT NULL,
                sourcesTableJSON TEXT NOT NULL,
                locus TEXT NOT NULL,
                isValidVpp INTEGER NOT NULL,
                validationIssuesJSON TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_projects_env ON projects(environmentID);
            CREATE INDEX IF NOT EXISTS idx_tracks_project ON tracks(projectID);
            CREATE INDEX IF NOT EXISTS idx_scenes_track ON scenes(trackID);
            CREATE INDEX IF NOT EXISTS idx_blocks_scene ON blocks(sceneID);
            CREATE INDEX IF NOT EXISTS idx_messages_block ON messages(blockID);
            """)

            // FTS
            try db.execute(sql: """
            CREATE VIRTUAL TABLE IF NOT EXISTS fts_library USING fts5(
                entityKind,
                entityID,
                scopeEnvironmentID,
                scopeProjectID,
                scopeTrackID,
                scopeSceneID,
                title,
                body
            );
            """)

            // FTS triggers (blocks)
            try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS trg_blocks_ai_fts AFTER INSERT ON blocks BEGIN
              DELETE FROM fts_library WHERE entityKind='block' AND entityID=new.id;
              INSERT INTO fts_library(entityKind, entityID, scopeEnvironmentID, scopeProjectID, scopeTrackID, scopeSceneID, title, body)
              SELECT
                'block',
                new.id,
                e.id,
                p.id,
                t.id,
                s.id,
                new.title,
                COALESCE(new.documentText,'')
              FROM scenes s
              JOIN tracks t ON t.id = s.trackID
              JOIN projects p ON p.id = t.projectID
              JOIN environments e ON e.id = p.environmentID
              WHERE s.id = new.sceneID;
            END;

            CREATE TRIGGER IF NOT EXISTS trg_blocks_au_fts AFTER UPDATE ON blocks BEGIN
              DELETE FROM fts_library WHERE entityKind='block' AND entityID=old.id;
              INSERT INTO fts_library(entityKind, entityID, scopeEnvironmentID, scopeProjectID, scopeTrackID, scopeSceneID, title, body)
              SELECT
                'block',
                new.id,
                e.id,
                p.id,
                t.id,
                s.id,
                new.title,
                COALESCE(new.documentText,'')
              FROM scenes s
              JOIN tracks t ON t.id = s.trackID
              JOIN projects p ON p.id = t.projectID
              JOIN environments e ON e.id = p.environmentID
              WHERE s.id = new.sceneID;
            END;

            CREATE TRIGGER IF NOT EXISTS trg_blocks_ad_fts AFTER DELETE ON blocks BEGIN
              DELETE FROM fts_library WHERE entityKind='block' AND entityID=old.id;
            END;
            """)

            // FTS triggers (messages)
            try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS trg_messages_ai_fts AFTER INSERT ON messages BEGIN
              DELETE FROM fts_library WHERE entityKind='message' AND entityID=new.id;
              INSERT INTO fts_library(entityKind, entityID, scopeEnvironmentID, scopeProjectID, scopeTrackID, scopeSceneID, title, body)
              SELECT
                'message',
                new.id,
                e.id,
                p.id,
                t.id,
                s.id,
                b.title,
                new.body
              FROM blocks b
              JOIN scenes s ON s.id = b.sceneID
              JOIN tracks t ON t.id = s.trackID
              JOIN projects p ON p.id = t.projectID
              JOIN environments e ON e.id = p.environmentID
              WHERE b.id = new.blockID;
            END;

            CREATE TRIGGER IF NOT EXISTS trg_messages_au_fts AFTER UPDATE ON messages BEGIN
              DELETE FROM fts_library WHERE entityKind='message' AND entityID=old.id;
              INSERT INTO fts_library(entityKind, entityID, scopeEnvironmentID, scopeProjectID, scopeTrackID, scopeSceneID, title, body)
              SELECT
                'message',
                new.id,
                e.id,
                p.id,
                t.id,
                s.id,
                b.title,
                new.body
              FROM blocks b
              JOIN scenes s ON s.id = b.sceneID
              JOIN tracks t ON t.id = s.trackID
              JOIN projects p ON p.id = t.projectID
              JOIN environments e ON e.id = p.environmentID
              WHERE b.id = new.blockID;
            END;

            CREATE TRIGGER IF NOT EXISTS trg_messages_ad_fts AFTER DELETE ON messages BEGIN
              DELETE FROM fts_library WHERE entityKind='message' AND entityID=old.id;
            END;
            """)

            // Seed (idempotent, per-workspace DB)
            let now = Date().timeIntervalSince1970
            try db.execute(sql: """
            INSERT OR IGNORE INTO workspace_settings (id, defaultModelID, defaultTemperature, defaultContextStrategy)
            VALUES ('settings', 'default', 0.4, 'all');

            INSERT OR IGNORE INTO environments (id, name, sortIndex, createdAt, updatedAt, deletedAt, deletedRootID)
            VALUES ('\(SeedIDs.envMain)', 'Main', 0, \(now), \(now), NULL, NULL);

            INSERT OR IGNORE INTO projects (id, environmentID, name, sortIndex, createdAt, updatedAt, deletedAt, deletedRootID)
            VALUES ('\(SeedIDs.projGettingStarted)', '\(SeedIDs.envMain)', 'Getting Started', 0, \(now), \(now), NULL, NULL);

            INSERT OR IGNORE INTO tracks (id, projectID, name, sortIndex, lastOpenedSceneID, createdAt, updatedAt, deletedAt, deletedRootID)
            VALUES ('\(SeedIDs.track1)', '\(SeedIDs.projGettingStarted)', 'Track 1', 0, '\(SeedIDs.sceneChat)', \(now), \(now), NULL, NULL);

            INSERT OR IGNORE INTO scenes (id, trackID, title, sortIndex, createdAt, updatedAt, deletedAt, deletedRootID)
            VALUES ('\(SeedIDs.sceneChat)', '\(SeedIDs.track1)', 'Chat', 0, \(now), \(now), NULL, NULL);

            INSERT OR IGNORE INTO blocks (id, sceneID, kind, title, subtitle, isCanonical, documentText, createdAt, updatedAt, deletedAt, deletedRootID)
            VALUES ('\(SeedIDs.welcomeBlock)', '\(SeedIDs.sceneChat)', 'conversation', 'Welcome', NULL, 1, NULL, \(now), \(now), NULL, NULL);
            """)
        }

        return migrator
    }()
}
