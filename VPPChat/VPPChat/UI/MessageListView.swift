import SwiftUI

struct MessageListView: View {
    var messages: [ConsoleMessage]
    var sessionID: ConsoleSession.ID
    var onRetry: (() -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.base * 1.5) {
                ForEach(messages) { message in
                    ConsoleMessageRow(message: message, sessionID: sessionID, onRetry: onRetry)
                        .padding(.horizontal, AppTheme.Spacing.outerHorizontal)
                        .transition(.asymmetric(
                            insertion: AnyTransition.opacity
                                .combined(with: .move(edge: .bottom))
                                .combined(with: .modifier(
                                    active: BlurModifier(radius: 10),
                                    identity: BlurModifier(radius: 0)
                                )),
                            removal: .opacity
                        ))
                        .animation(.easeOut(duration: AppTheme.Motion.fast), value: messages.count)
                }
            }
            .padding(.vertical, AppTheme.Spacing.base)
        }
    }
}

// A simple blur modifier to use in transitions.
struct BlurModifier: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

struct ConsoleMessageRow: View {
    let message: ConsoleMessage
    let sessionID: ConsoleSession.ID
    let onRetry: (() -> Void)?

    @EnvironmentObject private var workspace: WorkspaceViewModel
    @Environment(\.shellModeBinding) private var shellModeBinding

    @State private var showVppDetails = false
    @State private var isSaveSheetPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                vppIndicator
                bubble
            }

            if let link = message.linkedBlock {
                Button {
                    workspace.navigateToBlock(with: link)
                    shellModeBinding?.wrappedValue = .studio
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Filed in: \(link.displayPath)")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .contextMenu {
            Button("Save as block in Studio…") {
                isSaveSheetPresented = true
            }
        }
        .sheet(isPresented: $isSaveSheetPresented) {
            SaveBlockFromMessageSheet(
                message: message,
                projects: workspace.store.allProjects,
                onSave: { selection in
                    workspace.saveBlock(from: message, in: sessionID, selection: selection)
                }
            )
            .environmentObject(workspace)
        }
    }

    @ViewBuilder
    private var vppIndicator: some View {
        if let validation = message.vppValidation, !validation.isValid {
            Button {
                showVppDetails.toggle()
            } label: {
                Text("VPP ⚠︎")
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppTheme.Colors.surface1)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showVppDetails) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("VPP validation issues")
                        .font(.system(size: 12, weight: .semibold))
                    if validation.issues.isEmpty {
                        Text("No details available.")
                            .font(.system(size: 11))
                    } else {
                        ForEach(validation.issues, id: \.self) { issue in
                            Text("• " + issue)
                                .font(.system(size: 11))
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: 260)
            }
        } else {
            Rectangle()
                .fill(.clear)
                .frame(width: 30)
        }
    }

    @ViewBuilder
    private var bubble: some View {
        switch message.state {
        case .normal:
            ExistingBubbleView(message: message)

        case .pending:
            PendingAssistantBubble()

        case .error(let errorMessage):
            ErrorAssistantBubble(
                errorText: errorMessage ?? "Network error",
                onRetry: onRetry
            )
        }
    }
}

struct ExistingBubbleView: View {
    let message: ConsoleMessage

    private var authorLabel: String {
        switch message.role {
        case .user: return "YOU"
        case .assistant: return "ASSISTANT"
        case .system: return "SYSTEM"
        }
    }

    private var validation: VppRuntime.VppValidationResult? { message.vppValidation }
    private var isValid: Bool { validation?.isValid ?? true }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var theme: ThemeManager

    @State private var showInvalidPulse: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(authorLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.Colors.textSubtle)
                Spacer()
                Text(message.createdAt, style: .time)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            StreamingMessageBody(message: message)

            HStack {
                Spacer()
                validityDot
            }
        }
        .padding(AppTheme.Spacing.cardInner)
        .background(
            AppTheme.Colors.surface2
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.card, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radii.card, style: .continuous)
                .stroke(borderColor, lineWidth: showInvalidPulse ? 2.0 : 1.0)
                .shadow(color: glowColor, radius: showInvalidPulse ? 10 : 0)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 6, x: 6, y: 6)
        .onAppear {
            triggerInvalidPulseIfNeeded()
        }
        .onChange(of: isValid) { _ in
            triggerInvalidPulseIfNeeded()
        }
    }

    private var borderColor: Color {
        isValid ? AppTheme.Colors.borderSoft : AppTheme.Colors.statusMajor
    }

    private var glowColor: Color {
        isValid ? Color.clear : AppTheme.Colors.statusMajor.opacity(0.55)
    }

    private func triggerInvalidPulseIfNeeded() {
        guard !isValid, !reduceMotion else { return }

        showInvalidPulse = false
        theme.signal(.errorHighlight)

        withAnimation(AppTheme.Motion.invalidPulse) {
            showInvalidPulse = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(AppTheme.Motion.invalidPulse) {
                showInvalidPulse = false
            }
        }
    }

    private var validityDot: some View {
        Group {
            if isValid {
                Circle()
                    .fill(AppTheme.Colors.statusCorrect)
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .fill(AppTheme.Colors.statusMajor)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

struct StreamingMessageBody: View {
    let message: ConsoleMessage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var visibleLines: Int = 0

    private var lines: [String] {
        message.text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
    }

    private var shouldAnimate: Bool {
        message.role == .assistant
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(visibleLines > index ? 1 : 0)
                    .animation(
                        reduceMotion || !shouldAnimate
                        ? .none
                        : .easeOut(duration: 0.22)
                            .delay(Double(index) * 0.06),
                        value: visibleLines
                    )
            }
        }
        .onAppear {
            if reduceMotion || !shouldAnimate {
                visibleLines = lines.count
            } else {
                visibleLines = 0
                DispatchQueue.main.async {
                    visibleLines = lines.count
                }
            }
        }
    }
}

struct PendingAssistantBubble: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(AppTheme.Colors.surface1.opacity(0.7))
                .frame(width: 80, height: 10)
                .redacted(reason: .placeholder)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(AppTheme.Colors.surface1.opacity(0.6))
                .frame(width: 120, height: 10)
                .redacted(reason: .placeholder)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surface1)
        )
    }
}

struct ErrorAssistantBubble: View {
    let errorText: String
    let onRetry: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(errorText)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Colors.textSecondary)

            if let onRetry {
                Button(action: onRetry) {
                    Text("Retry")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.Colors.surface0)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surface1.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.Colors.exceptionAccent.opacity(0.7), lineWidth: 1)
        )
    }
}

#Preview {
    let appVM = AppViewModel()
    if let session = appVM.store.sessions.first {
        let seeded = ConsoleSession(
            id: session.id,
            title: session.name,
            createdAt: session.createdAt,
            messages: SessionView.makeConsoleMessages(from: session)
        )
        MessageListView(messages: seeded.messages, sessionID: seeded.id, onRetry: nil)
            .background(NoiseBackground())
            .environmentObject(WorkspaceViewModel())
    }
}
