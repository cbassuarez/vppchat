import SwiftUI

struct ConsoleShellView: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel

    var body: some View {
        HStack(spacing: 16) {
            ConsoleSessionSidebar()
                .environmentObject(workspace)
                .frame(width: 260)

            if let selected = workspace.selectedConsoleSession {
                HStack(spacing: 0) {
                    ConsoleSessionView(session: selected)
                        .environmentObject(workspace)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    ConsoleSessionInspectorView(
                        modelID: sessionBinding(keyPath: \ConsoleSession.modelID, default: SessionDefaults.defaultModelID),
                        temperature: sessionBinding(keyPath: \ConsoleSession.temperature, default: SessionDefaults.defaultTemperature),
                        contextStrategy: sessionBinding(keyPath: \ConsoleSession.contextStrategy, default: SessionDefaults.defaultContextStrategy)
                    )
                    .frame(width: 260)
                    .padding(.leading, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                            .fill(AppTheme.Colors.surface1)
                        RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                            .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                    }
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                )
            } else {
                consolePlaceholder
            }
        }
        .onAppear {
            workspace.ensureDefaultConsoleSession()
        }
    }

    private func sessionBinding<T>(keyPath: WritableKeyPath<ConsoleSession, T>, default defaultValue: T) -> Binding<T> {
        Binding(
            get: { workspace.selectedConsoleSession?[keyPath: keyPath] ?? defaultValue },
            set: { newValue in
                guard var session = workspace.selectedConsoleSession else { return }
                session[keyPath: keyPath] = newValue
                workspace.selectedConsoleSession = session
            }
        )
    }

    private var consolePlaceholder: some View {
        VStack(spacing: 8) {
            Text("No session selected")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("Create or select a session in the sidebar to begin.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {

                RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                    .fill(AppTheme.Colors.surface1)
            }
            .clipShape(
                RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
            )
        )
    }

}

// MARK: - Sidebar

private struct ConsoleSessionSidebar: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Sessions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
                Button {
                    workspace.newConsoleSession()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.plain)
            }

            List(selection: $workspace.selectedSessionID) {
                ForEach(workspace.consoleSessions) { session in
                    Text(session.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .tag(session.id as ConsoleSession.ID?)
                        .onTapGesture {
                            workspace.selectedSessionID = session.id
                            workspace.touchConsoleSession(session.id)
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.surface2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                .fill(AppTheme.Colors.surface2)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                        .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.10), radius: 6, x: 6, y: 6)
        )
    }
}

// MARK: - Main session view

private struct ConsoleSessionView: View {
    @EnvironmentObject private var workspace: WorkspaceViewModel
    @State private var draftText: String = ""
    @State private var modifiers: VppModifiers = VppModifiers()
    @State private var sources: VppSources = .none

    let session: ConsoleSession

    private var currentMessages: [ConsoleMessage] {
        workspace.selectedConsoleSession?.messages ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            MessageListView(
                sessionID: session.id,
                messages: currentMessages,
                onRetry: nil
            )

            ComposerView(
                draft: $draftText,
                modifiers: $modifiers,
                sources: $sources,
                runtime: workspace.vppRuntime,
                requestStatus: workspace.selectedConsoleSession?.requestStatus ?? .idle,
                sendAction: handleSend,
                tagSelection: { workspace.vppRuntime.setTag($0) },
                stepCycle: { workspace.vppRuntime.nextInCycle() },
                resetCycle: { workspace.vppRuntime.newCycle() }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .navigationTitle(session.title)
        .background(NoiseBackground())
    }

    private func handleSend() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var active = workspace.selectedConsoleSession else { return }

        let header = workspace.vppRuntime.makeHeader(
            tag: workspace.vppRuntime.state.currentTag,
            modifiers: modifiers
        )
        let composedText = "\(header)\n\(trimmed)"

        let msg = ConsoleMessage(
            role: .user,
            text: composedText,
            state: .normal
        )

        active.messages.append(msg)
        active.lastUsedAt = Date()
        workspace.selectedConsoleSession = active
        draftText = ""
    }
}
