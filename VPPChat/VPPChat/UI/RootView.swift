import SwiftUI

// RootView lays out the overall shell with sidebar, main transcript, and inspector.
struct RootView: View {
    @StateObject private var appViewModel = AppViewModel()

    var body: some View {
        ZStack {
            NoiseBackground()

            NavigationSplitView {
                SidebarView()
                    .environmentObject(appViewModel)
            } detail: {
                if let session = appViewModel.selectedSession {
                    SessionView(session: session, appViewModel: appViewModel)
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
}
