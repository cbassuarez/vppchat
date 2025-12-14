import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Small header
            HStack {
                Text("Sessions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
            }

            // Glassy list
            List(selection: $appViewModel.selectedSessionID) {
                Section("Folders") {
                    ForEach(sortedFolders()) { folder in
                        DisclosureGroup {
                            ForEach(sessions(in: folder)) { session in
                                Text(session.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                    .tag(session.id as Session.ID?)
                                    .contextMenu {
                                        Button(session.isPinned ? "Unpin" : "Pin") {
                                            appViewModel.store.togglePin(session: session)
                                        }
                                    }
                            }

                            Button(action: { appViewModel.createNewSession(in: folder) }) {
                                Label("New Session", systemImage: "plus")
                                    .font(.system(size: 11, weight: .regular))
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(folder.name)
                                    .font(.system(size: 12, weight: .semibold))
                                if folder.isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundStyle(AppTheme.Colors.textSubtle)
                                }
                            }
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .tag(folder.id as Folder.ID?)
                            .contextMenu {
                                Button(folder.isPinned ? "Unpin" : "Pin") {
                                    appViewModel.store.togglePin(folder: folder)
                                }
                            }
                        }
                    }
                }

                Button(action: {
                    appViewModel.createNewFolder(
                        named: "Folder \(appViewModel.store.folders.count + 1)"
                    )
                }) {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.surface2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                .fill(AppTheme.Colors.surface2)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                        .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.10), radius: 6, x: 6, y: 6)
        )
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
