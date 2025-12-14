import SwiftUI
import Combine
import AppKit

struct WindowConfigurator: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                configure(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

// VPPChatApp.swift
@main
struct VPPChatApp: App {
    @StateObject private var appViewModel = AppViewModel()
    @StateObject private var workspaceViewModel = WorkspaceViewModel()
    @StateObject private var themeManager = ThemeManager()
    
    @State private var shellMode: ShellMode
    private let shellModeKey = "vppchat.shell.lastMode"
    
    init() {
        let saved = UserDefaults.standard.string(forKey: shellModeKey)
        let initial = ShellMode(rawValue: saved ?? "") ?? .atlas
        _shellMode = State(initialValue: initial)
    }
    
    var body: some SwiftUI.Scene {
        WindowGroup {
            ZStack(alignment: .top) {
                // Shader background
                NoiseBackground()
                
                // Main shell (Console / Atlas / Studio)
                MainShellView(mode: $shellMode)
                
                // Global dim + Command Space overlay
                if workspaceViewModel.isCommandSpaceVisible {
                    Color.black
                        .opacity(0.22)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .allowsHitTesting(false)
                    
                    CommandSpaceView()
                        .padding(.top, 18)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .background(Color.clear)
            .background(
                WindowConfigurator { window in
                    window.isOpaque = false
                    window.titlebarAppearsTransparent = true
                    window.titleVisibility = .hidden
                    window.styleMask.insert(.fullSizeContentView)
                    window.isMovableByWindowBackground = true
                    window.backgroundColor = .clear
                }
            )
            .environmentObject(appViewModel)
            .environmentObject(workspaceViewModel)
            .environmentObject(themeManager)
            .animation(.easeInOut(duration: AppTheme.Motion.medium),
                       value: workspaceViewModel.isCommandSpaceVisible)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        
        Settings {
            SettingsRoot()
                .windowResizeAnchorCompat(.trailing)
                .environmentObject(appViewModel)
                .environmentObject(workspaceViewModel)
                .environmentObject(themeManager)
        }
    }
}
