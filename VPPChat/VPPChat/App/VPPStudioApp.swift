import SwiftUI

/// Optional: not an App, just a View.
struct VPPStudioRoot: View {
    @EnvironmentObject private var workspaceVM: WorkspaceViewModel

    var body: some View {
        ZStack {
            StudioBackgroundView()
            StudioView()
        }
    }
}
