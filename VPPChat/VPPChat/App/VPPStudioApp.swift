import SwiftUI

/// Optional: not an App, just a View.
struct VPPStudioRoot: View {
    @StateObject private var workspaceVM = WorkspaceViewModel()

    var body: some View {
        ZStack {
            StudioBackgroundView()
            StudioView()
                .environmentObject(workspaceVM)
        }
    }
}
