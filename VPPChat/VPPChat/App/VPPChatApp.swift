import SwiftUI

@main
struct VPPChatApp: App {
    @StateObject private var appViewModel = AppViewModel()
    @StateObject private var workspaceViewModel = WorkspaceViewModel()
    @StateObject private var themeManager = ThemeManager()
    @State private var shellMode: ShellMode = .atlas

    private let shellModeKey = "vppchat.shell.lastMode"

    init() {
        if let raw = UserDefaults.standard.string(forKey: shellModeKey),
           let mode = ShellMode(rawValue: raw) {
            _shellMode = State(initialValue: mode)
        } else {
            _shellMode = State(initialValue: .atlas)
        }
    }

    var body: some Scene {
        WindowGroup {
            MainShellView(
                mode: $shellMode
            )
            .environmentObject(appViewModel)
            .environmentObject(workspaceViewModel)
            .environmentObject(themeManager)
            .onChange(of: shellMode) { newValue in
                UserDefaults.standard.set(newValue.rawValue, forKey: shellModeKey)
            }
        }
        .commands {
            ShellModeCommands(mode: $shellMode)
        }
    }
}
