import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Search / header could go here later
            List(selection: $appViewModel.selectedSessionID) {
                // Pinned section
                Section("Pinned") {
                    ForEach(pinnedFolders()) { folder in
                        folderRow(folder: folder)
                    }
                    ForEach(pinnedSessions()) { session in
                        sessionRow(session: session, isOrphanPinned: true)
                    }
                }

                Section("Folders") {
                    ForEach(sortedFolders()) { folder in
                        folderRow(folder: folder)
                    }

                    Button(action: { appViewModel.createNewFolder(named: "Folder \(appViewModel.store.folders.count + 1)") }) {
                        Label("Add Folder", systemImage: "folder.badge.plus")
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .background(
            AppTheme.Colors.surface0
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }

    private func folderRow(folder: Folder) -> some View {
        DisclosureGroup {
            ForEach(sessions(in: folder)) { session in
                sessionRow(session: session)
            }
            Button(action: { appViewModel.createNewSession(in: folder) }) {
                Label("New Session", systemImage: "plus")
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "folder")
                Text(folder.name)
                    .font(.system(size: 13, weight: .medium))
                if folder.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            .contextMenu {
                Button(folder.isPinned ? "Unpin" : "Pin") {
                    appViewModel.store.togglePin(folder: folder)
                }
            }
        }
    }

    private func sessionRow(session: Session, isOrphanPinned: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.system(size: 12, weight: .regular))
                Text(session.updatedAt, style: .time)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            if session.isPinned || isOrphanPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(.leading, 12) // visual indentation
        .tag(session.id as Session.ID?)
        .contextMenu {
            Button(session.isPinned ? "Unpin" : "Pin") {
                appViewModel.store.togglePin(session: session)
            }
        }
    }

    private func sortedFolders() -> [Folder] {
        appViewModel.store.folders.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            return lhs.name < rhs.name
        }
    }

    private func pinnedFolders() -> [Folder] {
        appViewModel.store.folders.filter { $0.isPinned }
    }

    private func pinnedSessions() -> [Session] {
        appViewModel.store.sessions.filter { $0.isPinned && appViewModel.store.folder(for: $0.id) == nil }
    }

    private func sessions(in folder: Folder) -> [Session] {
        appViewModel.store.sessions.filter { $0.folderID == folder.id }
    }
}

#Preview {
    SidebarView()
        .environmentObject(AppViewModel())
}
