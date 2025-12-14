import SwiftUI

struct MainShellView: View {
    @Binding var mode: ShellMode

    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var workspaceVM: WorkspaceViewModel
    @EnvironmentObject private var theme: ThemeManager

    @Namespace private var modeUnderline

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                MainToolbar(mode: $mode)
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                ZStack {
                    switch mode {
                    case .console:
                        ConsoleShellView()
                            .transition(.opacity.combined(with: .scale(scale: 0.99)))
                    case .studio:
                        StudioView()
                            .transition(.opacity.combined(with: .scale(scale: 0.99)))
                    case .atlas:
                        AtlasView(
                            onOpenInStudio: { block in
                                workspaceVM.select(block: block)
                                withAnimation(.spring(response: AppTheme.Motion.medium,
                                                      dampingFraction: 0.85)) {
                                    mode = .studio
                                }
                            },
                            onSendToConsole: { block in
                                sendToConsole(block)
                            }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.99)))
                    }
                }
                .padding(18)
            }
        }
        .background(Color.clear)
    }

    private func sendToConsole(_ block: Block) {
        guard let scene = workspaceVM.store.scene(id: block.sceneID),
              let track = workspaceVM.store.track(id: scene.trackID),
              let project = workspaceVM.store.project(for: track.id) else {
            return
        }

        let session = workspaceVM.openConsole(
            for: block,
            project: project,
            track: track,
            scene: scene
        )
        workspaceVM.touchConsoleSession(session.id)

        withAnimation(.spring(response: AppTheme.Motion.medium, dampingFraction: 0.85)) {
            mode = .console
        }
    }
}
