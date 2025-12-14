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

struct SettingsRoot: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var pane: Pane = .general

  enum Pane: String, CaseIterable, Identifiable {
    case general = "General"
    case motion = "Motion"
    case advanced = "Advanced"
    var id: String { rawValue }
  }

  var body: some View {
    VStack(spacing: 0) {
      Picker("Pane", selection: $pane) {
        ForEach(Pane.allCases) { p in
          Text(p.rawValue).tag(p)
        }
      }
      .pickerStyle(.segmented)
      .padding(12)

      Divider()

      Group {
        switch pane {
        case .general:
               SettingsGeneralPane()
        case .motion:
          paneCard(title: "Motion", lines: 12)
        case .advanced:
          paneCard(title: "Advanced", lines: 18)
        }
      }
      .padding(12)
    }
    .frame(minWidth: 520)
  }

  private func paneCard(title: String, lines: Int) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.system(size: 16.5, weight: .semibold))

      ForEach(0..<lines, id: \.self) { _ in
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(.primary.opacity(0.06))
          .frame(height: 12)
      }
    }
    .padding(12)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(.primary.opacity(0.07), lineWidth: 1)
    }
  }
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
                    .environment(\.shellModeBinding, $shellMode)

                // 🔴 Single global dim + Command Space overlay
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
            // 🔊 Tell the shader when Command Space opens/closes
            .onChange(of: workspaceViewModel.isCommandSpaceVisible) { visible in
                themeManager.signal(visible ? .commandSpaceOpen : .commandSpaceClose)
            }
            .background(Color.clear)
            .background(
                WindowConfigurator { window in
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
            .animation(
                .easeInOut(duration: AppTheme.Motion.medium),
                value: workspaceViewModel.isCommandSpaceVisible
            )
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
