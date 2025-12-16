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

import SwiftUI
import Combine
import AppKit

struct SettingsRoot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pane: Pane = .general

    enum Pane: String, CaseIterable, Identifiable {
        case general = "General"
        case llm = "LLM"
        case motion = "Motion"
        case advanced = "Advanced"
        case about = "About"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .llm: return "bolt.horizontal.circle.fill"
            case .motion: return "sparkles"
            case .advanced: return "slider.horizontal.3"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topTabs
                .padding(12)

            Divider()
                .overlay(AppTheme.Colors.borderSoft.opacity(0.7))

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    paneView
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
        .frame(minWidth: 620, minHeight: 520)
    }

    // MARK: - Top tabs (Logic-style)

    private var topTabs: some View {
        HStack(spacing: 8) {
            ForEach(Pane.allCases) { p in
                SettingsTabChip(
                    title: p.rawValue,
                    systemImage: p.icon,
                    isSelected: pane == p
                ) {
                    if reduceMotion {
                        pane = p
                    } else {
                        withAnimation(.easeOut(duration: 0.16)) {
                            pane = p
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(StudioTheme.Colors.surface1)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Pane switch

    @ViewBuilder
    private var paneView: some View {
        switch pane {
        case .general:
            SettingsGeneralPane()

        case .llm:
            SettingsLLMPane()

        case .motion:
            SettingsMotionPane()

        case .advanced:
            SettingsAdvancedPane()

        case .about:
            SettingsAboutPane()
        }
    }
}

// MARK: - Shared tab chip

private struct SettingsTabChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? StudioTheme.Colors.accentSoft : StudioTheme.Colors.surface1)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? StudioTheme.Colors.accent : StudioTheme.Colors.borderSoft, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? StudioTheme.Colors.textPrimary : StudioTheme.Colors.textSecondary)
            .scaleEffect(isHovering ? 1.02 : 1.0)
        }
        .buttonStyle(SettingsScalePressButtonStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

private struct SettingsScalePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// VPPChatApp.swift
@main
struct VPPChatApp: App {
    @StateObject private var appViewModel = AppViewModel()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var llmConfig = LLMConfigStore.shared
    private var workspaceVM: WorkspaceViewModel { appViewModel.workspace }
    
    @State private var shellMode: ShellMode
    private let shellModeKey = "vppchat.shell.lastMode"
    
    init() {
        let saved = UserDefaults.standard.string(forKey: shellModeKey)
        let initial = ShellMode(rawValue: saved ?? "") ?? .atlas
        _shellMode = State(initialValue: initial)
    }
    
    var body: some SwiftUI.Scene {
        WindowGroup {
            RootWindowView(shellMode: $shellMode)
              .background(Color.clear)
              .background(
                WindowConfigurator { window in
                  window.titlebarAppearsTransparent = true
                  window.titleVisibility = .hidden
                  window.styleMask.insert(.fullSizeContentView)
                  window.isMovableByWindowBackground = false
                  window.backgroundColor = .clear
                }
              )
              .environmentObject(appViewModel)
              .environmentObject(appViewModel.workspace)
              .environmentObject(themeManager)
              .environmentObject(llmConfig)
              .onAppear {
                workspaceVM.switchToShell = { mode in shellMode = mode }
                workspaceVM.currentShellMode = shellMode
                workspaceVM.ensureDefaultConsoleSession()
              }
              .onChange(of: shellMode) { newValue in
                workspaceVM.currentShellMode = newValue
              }

            // 🔊 Tell the shader when Command Space opens/closes
            .onChange(of: workspaceVM.isCommandSpaceVisible) { visible in
                themeManager.signal(visible ? .commandSpaceOpen : .commandSpaceClose)
            }
            .onAppear {
                print("APP  appViewModel.workspace.instanceID =", appViewModel.workspace.instanceID)

                workspaceVM.switchToShell = { mode in
                    shellMode = mode
                }
                workspaceVM.currentShellMode = shellMode
                workspaceVM.ensureDefaultConsoleSession()
            }
            .onChange(of: shellMode) { newValue in
                workspaceVM.currentShellMode = newValue
            }
            .background(Color.clear)
            .background(
                WindowConfigurator { window in
                    window.titlebarAppearsTransparent = true
                    window.titleVisibility = .hidden
                    window.styleMask.insert(.fullSizeContentView)
                    window.isMovableByWindowBackground = false
                    window.backgroundColor = .clear
                }
            )
            .environmentObject(appViewModel)
            .environmentObject(workspaceVM)
            .environmentObject(themeManager)
            .environmentObject(llmConfig)
            .animation(.easeInOut(duration: AppTheme.Motion.medium), value: workspaceVM.isCommandSpaceVisible)
        }

        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)

#if os(macOS)
        .commands {
            AppCommands(
                shellMode: $shellMode,
                workspaceViewModel: appViewModel.workspace,
                appViewModel: appViewModel
            )
        }
#endif

        Settings {
            SettingsRoot()
                .windowResizeAnchorCompat(.trailing)
                .environmentObject(appViewModel)
                .environmentObject(workspaceVM)
                .environmentObject(themeManager)
                .environmentObject(llmConfig)
        }
    }
}
