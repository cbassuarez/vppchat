import SwiftUI
#if os(macOS)
import AppKit

/// Transparent NSView that lets click+drag move the window (but only where you place it).
private struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView(frame: .zero) }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override var isOpaque: Bool { false }
    }
}

extension View {
    /// Marks this view’s hit-test region as a window-drag region.
    /// Put it on backgrounds/empty chrome so text selection still works elsewhere.
    func windowDraggableArea() -> some View {
        background(WindowDragArea())
    }
}
#endif

struct MainShellView: View {
    @Binding var mode: ShellMode

    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var workspaceVM: WorkspaceViewModel
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.shellModeBinding) private var shellModeBinding

    @Namespace private var modeUnderline
    
    @ViewBuilder
    private var toolbarRow: some View {
        MainToolbar(mode: $mode)
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .background(WindowDragArea())   // ✅ does NOT affect layout sizing
            )
    }


    var body: some View {
        ZStack {
    #if os(macOS)
            WindowMarginDragRegions(inset: 18)   // ✅ BEHIND everything
    #endif

            VStack(spacing: 0) {
                toolbarRow

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
        .onAppear {
            print("MainShellView workspace instance: \(workspaceVM.instanceID)")
        }
    }


    private func sendToConsole(_ block: Block) {
        guard
            let scene = workspaceVM.store.scene(id: block.sceneID),
            let track = workspaceVM.store.track(id: scene.trackID),
            let project = workspaceVM.store.project(id: track.projectID)
        else { return }

        let session = workspaceVM.openConsole(for: block, project: project, track: track, scene: scene)
        workspaceVM.touchConsoleSession(session.id)

        withAnimation(.spring(response: AppTheme.Motion.medium, dampingFraction: 0.85)) {
            shellModeBinding?.wrappedValue = .console
        }
    }
}
#if os(macOS)
private struct WindowMarginDragRegions: View {
    let inset: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // left
                WindowDragArea()
                    .frame(width: inset, height: h)
                    .position(x: inset / 2, y: h / 2)

                // right
                WindowDragArea()
                    .frame(width: inset, height: h)
                    .position(x: w - inset / 2, y: h / 2)

                // bottom
                WindowDragArea()
                    .frame(width: w, height: inset)
                    .position(x: w / 2, y: h - inset / 2)
            }
        }
        .ignoresSafeArea()
        // IMPORTANT: this MUST be behind content (we did that in the ZStack),
        // so it only receives clicks in empty margins.
    }
}
#endif
