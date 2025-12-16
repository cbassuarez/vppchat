//
//  WorkspaceRepository+ExportImport.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//

import Foundation

extension WorkspaceRepository {
    // Export workspace folder as a .vppworkspace package directory (no zip dependency).
    func exportWorkspace(to url: URL) throws {
        let fm = FileManager.default
        let srcFolder = sqliteURL.deletingLastPathComponent()  // .../<workspaceID>/
        if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
        try fm.copyItem(at: srcFolder, to: url)
    }

    // Import is handled at registry/controller level (creates new workspaceID folder).
    // Keep this here as a helper to copy payload into a destination workspace folder.
    static func importWorkspacePayload(from url: URL, toWorkspaceID newID: UUID) throws {
        let fm = FileManager.default
        try AppSupportPaths.ensureWorkspaceFolders(id: newID)
        let destFolder = AppSupportPaths.workspaceFolder(id: newID)
        // Copy sqlite + blobs if present
        let srcSQLite = url.appendingPathComponent("workspace.sqlite")
        let destSQLite = destFolder.appendingPathComponent("workspace.sqlite")
        if fm.fileExists(atPath: srcSQLite.path) {
            if fm.fileExists(atPath: destSQLite.path) { try fm.removeItem(at: destSQLite) }
            try fm.copyItem(at: srcSQLite, to: destSQLite)
        }
        let srcBlobs = url.appendingPathComponent("blobs")
        let destBlobs = destFolder.appendingPathComponent("blobs")
        if fm.fileExists(atPath: srcBlobs.path) {
            if fm.fileExists(atPath: destBlobs.path) { try fm.removeItem(at: destBlobs) }
            try fm.copyItem(at: srcBlobs, to: destBlobs)
        }
    }
}
