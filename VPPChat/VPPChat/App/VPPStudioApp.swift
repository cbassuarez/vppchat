import SwiftUI

/// Optional: a dedicated Studio root view if needed elsewhere.
/// This is NOT an App entry point.
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
