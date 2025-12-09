import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        List(selection: $appViewModel.selectedSessionID) {
            if !pinnedFolders.isEmpty || !pinnedSessions.isEmpty {
                Section(header: Text("PINNED").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)) {
                    ForEach(pinnedFolders) { folder in
                        folderRow(folder)
                    }
                    ForEach(pinnedSessions) { session in
                        sessionRow(session)
                    }
                }
            }

            Section("Folders") {
                ForEach(sortedFolders()) { folder in
                    DisclosureGroup {
                        ForEach(sessions(in: folder)) { session in
                            sessionRow(session)
                                .padding(.leading, 8)
                        }
                        Button(action: { appViewModel.createNewSession(in: folder) }) {
                            Label("New Session", systemImage: "plus")
                        }
                        .font(.system(size: 12, weight: .medium))
                    } label: {
                        folderRow(folder)
                    }
                }
            }
            Button(action: { appViewModel.createNewFolder(named: "Folder \(appViewModel.store.folders.count + 1)") }) {
                Label("Add Folder", systemImage: "folder.badge.plus")
            }
            .font(.system(size: 12, weight: .semibold))
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
    }

    private func folderRow(_ folder: Folder) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(folder.name)
                        .font(.system(size: 13, weight: .medium))
                    if folder.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Folder")
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }
        }
        .tag(folder.id as Folder.ID?)
        .contextMenu {
            Button(folder.isPinned ? "Unpin" : "Pin") {
                appViewModel.store.togglePin(folder: folder)
            }
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .foregroundStyle(appViewModel.selectedSessionID == session.id ? .accent : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(session.name)
                        .font(.system(size: 12, weight: .regular))
                        .lineLimit(1)
                    if session.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(session.updatedAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .tag(session.id as Session.ID?)
        .contextMenu {
            Button(session.isPinned ? "Unpin" : "Pin") {
                appViewModel.store.togglePin(session: session)
            }
        }
    }

    private var pinnedFolders: [Folder] {
        appViewModel.store.folders.filter { $0.isPinned }.sorted { $0.name < $1.name }
    }

    private var pinnedSessions: [Session] {
        appViewModel.store.sessions.filter { $0.isPinned }.sorted { $0.name < $1.name }
    }

    private func sortedFolders() -> [Folder] {
        appViewModel.store.folders.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            return lhs.name < rhs.name
        }
    }

    private func sessions(in folder: Folder) -> [Session] {
        appViewModel.store.sessions.filter { $0.folderID == folder.id }
    }
}

#Preview {
    SidebarView()
        .environmentObject(AppViewModel())
}
