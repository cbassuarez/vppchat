import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        List(selection: $appViewModel.selectedSessionID) {
            Section("Folders") {
                ForEach(sortedFolders()) { folder in
                    DisclosureGroup {
                        ForEach(sessions(in: folder)) { session in
                            Text(session.name)
                                .tag(session.id as Session.ID?)
                                .contextMenu {
                                    Button(session.isPinned ? "Unpin" : "Pin") {
                                        appViewModel.store.togglePin(session: session)
                                    }
                                }
                        }
                        Button(action: { appViewModel.createNewSession(in: folder) }) {
                            Label("New Session", systemImage: "plus")
                        }
                    } label: {
                        HStack {
                            Text(folder.name)
                            if folder.isPinned { Image(systemName: "pin.fill").foregroundStyle(.secondary) }
                        }
                        .tag(folder.id as Folder.ID?)
                        .contextMenu {
                            Button(folder.isPinned ? "Unpin" : "Pin") {
                                appViewModel.store.togglePin(folder: folder)
                            }
                        }
                    }
                }
            }
            Button(action: { appViewModel.createNewFolder(named: "Folder \(appViewModel.store.folders.count + 1)") }) {
                Label("Add Folder", systemImage: "folder.badge.plus")
            }
        }
        .listStyle(.sidebar)
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
