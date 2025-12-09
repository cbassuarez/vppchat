import SwiftUI

/// Root view for the console experience; not an app entry point.
struct VPPConsoleRoot: View {
    @StateObject private var appViewModel = AppViewModel()

    var body: some View {
        RootView()
            .environmentObject(appViewModel)
    }
}
