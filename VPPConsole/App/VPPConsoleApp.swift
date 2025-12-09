import SwiftUI

@main
struct VPPConsoleApp: App {
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appViewModel)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Session", action: { appViewModel.createNewSession(in: appViewModel.store.folders.first) })
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
