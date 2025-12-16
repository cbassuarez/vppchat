//
//  AppSupportPaths.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import Foundation

enum AppSupportPaths {
    static let appFolderName = "VPPChat"

    static var appSupportRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(appFolderName, isDirectory: true)
    }

    static var registryURL: URL {
        appSupportRoot.appendingPathComponent("registry.json", isDirectory: false)
    }

    static var workspacesRoot: URL {
        appSupportRoot.appendingPathComponent("Workspaces", isDirectory: true)
    }

    static func workspaceFolder(id: UUID) -> URL {
        workspacesRoot.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    static func workspaceSQLiteURL(id: UUID) -> URL {
        workspaceFolder(id: id).appendingPathComponent("workspace.sqlite", isDirectory: false)
    }

    static func workspaceBlobsURL(id: UUID) -> URL {
        workspaceFolder(id: id).appendingPathComponent("blobs", isDirectory: true)
    }

    static func ensureBaseFolders() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: appSupportRoot, withIntermediateDirectories: true)
        try fm.createDirectory(at: workspacesRoot, withIntermediateDirectories: true)
    }

    static func ensureWorkspaceFolders(id: UUID) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: workspaceFolder(id: id), withIntermediateDirectories: true)
        try fm.createDirectory(at: workspaceBlobsURL(id: id), withIntermediateDirectories: true)
    }
}
