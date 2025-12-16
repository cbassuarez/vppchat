//
//  WorkspaceRegistry.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import Foundation

struct WorkspaceRegistry: Codable {
    struct Entry: Codable, Identifiable, Hashable {
        var id: UUID
        var name: String
        var createdAt: Date
        var lastOpenedAt: Date
        var deletedAt: Date?
    }

    var entries: [Entry] = []

    static let activeWorkspaceKey = "vppchat.activeWorkspaceID"

    static func loadOrCreate() throws -> WorkspaceRegistry {
        try AppSupportPaths.ensureBaseFolders()
        let url = AppSupportPaths.registryURL
        if !FileManager.default.fileExists(atPath: url.path) {
            var reg = WorkspaceRegistry()
            let entry = try reg.createWorkspace(name: "Default")
            reg.entries = [entry]
            try reg.save()
            UserDefaults.standard.set(entry.id.uuidString, forKey: activeWorkspaceKey)
            return reg
        }
        let data = try Data(contentsOf: url)
        var reg = try JSONDecoder().decode(WorkspaceRegistry.self, from: data)

        // Ensure at least one non-deleted workspace exists
        if reg.entries.filter({ $0.deletedAt == nil }).isEmpty {
            let entry = try reg.createWorkspace(name: "Default")
            reg.entries.append(entry)
            try reg.save()
            UserDefaults.standard.set(entry.id.uuidString, forKey: activeWorkspaceKey)
        }
        return reg
    }

    func save() throws {
        let url = AppSupportPaths.registryURL
        let data = try JSONEncoder().encode(self)
        try data.write(to: url, options: [.atomic])
    }

    mutating func createWorkspace(name: String) throws -> Entry {
        let entry = Entry(
            id: UUID(),
            name: name,
            createdAt: Date(),
            lastOpenedAt: Date(),
            deletedAt: nil
        )
        try AppSupportPaths.ensureWorkspaceFolders(id: entry.id)
        return entry
    }

    func activeWorkspaceID() -> UUID? {
        guard let s = UserDefaults.standard.string(forKey: WorkspaceRegistry.activeWorkspaceKey),
              let id = UUID(uuidString: s) else { return nil }
        return id
    }

    mutating func setActive(_ id: UUID) throws {
        UserDefaults.standard.set(id.uuidString, forKey: WorkspaceRegistry.activeWorkspaceKey)
        if let i = entries.firstIndex(where: { $0.id == id }) {
            entries[i].lastOpenedAt = Date()
            try save()
        }
    }

    func entry(for id: UUID) -> Entry? {
        entries.first(where: { $0.id == id })
    }

    func sqliteURL(for id: UUID) -> URL {
        AppSupportPaths.workspaceSQLiteURL(id: id)
    }
}
