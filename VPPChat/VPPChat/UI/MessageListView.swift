import SwiftUI
import AppKit

struct MessageListView: View {
    var sessionID: ConsoleSession.ID?
    var messages: [ConsoleMessage]
    var onRetry: (() -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: AppTheme.Spacing.base * 1.5
            ) {
                ForEach(messages) { message in
                    ConsoleMessageRow(
                        message: message,
                        sessionID: sessionID,
                        onRetry: onRetry
                    )
                    // 👇 extra breathing room around each bubble so shadows
                    // and any subtle scaling don’t get clipped by the container
                    .padding(.horizontal, AppTheme.Spacing.outerHorizontal + 12)
                    .padding(.vertical, 4)
                    .transition(
                        .asymmetric(
                            insertion: AnyTransition.opacity
                                .combined(with: .move(edge: .bottom))
                                .combined(
                                    with: .modifier(
                                        active: BlurModifier(radius: 10),
                                        identity: BlurModifier(radius: 0)
                                    )
                                ),
                            removal: .opacity
                        )
                    )
                    .animation(
                        .easeOut(duration: AppTheme.Motion.fast),
                        value: messages.count
                    )
                }
            }
            // 👇 small inset so the outermost shadows don’t kiss the panel radius
            .padding(.vertical, AppTheme.Spacing.base)
            .padding(.horizontal, 12)
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
    let sessionID: ConsoleSession.ID?
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
                projects: workspace.store.allProjects
            ) { selection in
                guard let sessionID else { return }
                workspace.saveBlock(from: message, in: sessionID, selection: selection)
            }
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
            PendingAssistantBubble(sessionID: sessionID)

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
    @State private var didCopyMessage = false

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

            MarkdownMessageBody(text: message.text, role: message.role)

            HStack(spacing: 8) {
                Spacer()

                if message.role == .assistant {
                    Button {
                        let s = MarkdownCopyText.renderedText(from: message.text)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(s, forType: .string)

                        didCopyMessage = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                            didCopyMessage = false
                        }
                    } label: {
                        Image(systemName: didCopyMessage ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.structuralAccent)
                            .padding(6)
                            .background(AppTheme.Colors.surface1)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppTheme.Colors.borderSoft, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Copy message")
                }

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
    let sessionID: ConsoleSession.ID?
    @EnvironmentObject private var workspace: WorkspaceViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded: Bool = false

    private var session: ConsoleSession? {
        guard let sessionID else { return nil }
        return workspace.consoleSessions.first(where: { $0.id == sessionID })
    }

    private var statusText: String {
        guard let s = session else { return "Receiving…" }
        switch s.requestStatus {
        case .inFlight(let stage, _):
            return (stage == .sending) ? "Sending…" : "Receiving…"
        default:
            return "Receiving…"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .symbolEffect(.pulse, isActive: !reduceMotion)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Text(statusText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: AppTheme.Motion.fast)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textSubtle)
                        .padding(6)
                        .background(AppTheme.Colors.surface0)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.Colors.borderSoft, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Hide details" : "Show details")
            }

            if isExpanded, let s = session {
                InFlightDetails(session: s)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surface1.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
        )
    }
}

private struct InFlightDetails: View {
    let session: ConsoleSession

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundStyle(AppTheme.Colors.textSubtle)
            Spacer()
            Text(v).foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .font(.system(size: 11, weight: .medium))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Model", session.modelID)
            row("Temperature", String(format: "%.2f", session.temperature))
            row("Context", "\(session.contextStrategy)")
            if case let .inFlight(_, startedAt) = session.requestStatus {
                row("Elapsed", elapsedString(since: startedAt))
            }
        }
        .padding(10)
        .background(AppTheme.Colors.surface0)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
        )
    }

    private func elapsedString(since d: Date) -> String {
        let t = Date().timeIntervalSince(d)
        if t < 60 { return "\(Int(t))s" }
        let m = Int(t / 60)
        let s = Int(t) % 60
        return "\(m)m \(s)s"
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
        MessageListView(sessionID: seeded.id, messages: seeded.messages, onRetry: nil)
                   .background(NoiseBackground())
                   .environmentObject(appVM.workspace)
    }
}
