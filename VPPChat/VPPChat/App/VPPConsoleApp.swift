import SwiftUI

@main
struct VPPConsoleApp: App {
    @StateObject private var workspaceVM = WorkspaceViewModel()
    @StateObject private var theme = ThemeManager()          //

    var body: some SwiftUI.Scene {
        WindowGroup {
            ZStack {
                StudioBackgroundView()
                StudioView()
                    .environmentObject(workspaceVM)
                    .environmentObject(theme) 
            }
        }
    }
}
