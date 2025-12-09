import SwiftUI

// RootView lays out the overall shell with sidebar, main transcript, and inspector.
struct RootView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark ? [Color.black, Color(white: 0.08)] : [Color(white: 0.95), Color(white: 0.86)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            NavigationSplitView {
                SidebarView()
                    .background(.ultraThinMaterial)
            } detail: {
                if let session = appViewModel.store.session(id: appViewModel.selectedSessionID) {
                    SessionView(session: session, appViewModel: appViewModel)
                } else {
                    Text("Select or create a session")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.thinMaterial)
                }
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppViewModel())
}
