import SwiftUI

// RootView lays out the overall shell with sidebar, main transcript, and inspector.
struct RootView: View {
    @StateObject private var appViewModel = AppViewModel()
    @StateObject private var workspaceViewModel = WorkspaceViewModel()

    var body: some View {
        ZStack {
            NoiseBackground()

            NavigationSplitView {
                SidebarView()
                    .environmentObject(appViewModel)
                    .environmentObject(workspaceViewModel)
            } detail: {
                if let session = appViewModel.selectedSession {
                    SessionView(session: session, appViewModel: appViewModel)
                        .environmentObject(workspaceViewModel)
                } else {
                    Text("Select or create a session")
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppViewModel())
        .environmentObject(WorkspaceViewModel())
}
