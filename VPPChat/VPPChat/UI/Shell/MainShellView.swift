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
        // Decide which folder to put the new session in
        guard let folder = appVM.selectedFolder ?? appVM.store.folders.first else {
            return
        }

        // Create a new session; AppViewModel is responsible for updating selectedSessionID
        appVM.createNewSession(in: folder)

        // Grab the ID of the newly selected session
        guard let sessionID = appVM.selectedSessionID else {
            return
        }

        // Build snippet from the block
        let snippet: String
        if let text = block.documentText, !text.isEmpty {
            snippet = text
        } else if let lastMessage = block.messages.last {
            snippet = lastMessage.body
        } else {
            snippet = block.title
        }

        let body = "[ATLAS] \(block.title)\n\n\(snippet)"

        let message = Message(
            id: UUID(),
            isUser: true,
            timestamp: .now,
            body: body,
            tag: .g,
            cycleIndex: 1,
            assumptions: 0,
            sources: .none,
            locus: "Atlas",
            isValidVpp: true,
            validationIssues: []
        )

        appVM.store.appendMessage(message, to: sessionID)

        withAnimation(.spring(response: AppTheme.Motion.medium, dampingFraction: 0.85)) {
            mode = .console
        }
    }
}
