import SwiftUI

@main
struct VPPConsoleApp: App {
    @StateObject private var workspaceVM = WorkspaceViewModel()

    var body: some Scene {
        WindowGroup {
            ZStack {
                StudioBackgroundView()
                StudioView()
                    .environmentObject(workspaceVM)
            }
        }
    }
}
