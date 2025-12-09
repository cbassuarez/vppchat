import SwiftUI

// RootView lays out the overall shell with sidebar, main transcript, and inspector.
struct RootView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            if let session = appViewModel.store.session(id: appViewModel.selectedSessionID) {
                SessionView(session: session, appViewModel: appViewModel)
            } else {
                Text("Select or create a session")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppViewModel())
}
