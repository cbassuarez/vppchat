import SwiftUI

struct BlockCardView: View {
    let block: Block
    var isSelected: Bool = false

    @EnvironmentObject private var workspace: WorkspaceViewModel
    @Environment(\.shellModeBinding) private var shellModeBinding
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering: Bool = false

    var body: some View {
        let hoverScale: CGFloat = isHovering ? 1.02 : 1.0

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(block.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(StudioTheme.Colors.textPrimary)

                Spacer()

                Text(block.createdAt, style: .time)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(StudioTheme.Colors.textSecondary)
            }

            if let subtitle = block.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(StudioTheme.Colors.textSecondary)
            }

            switch block.kind {
            case .conversation:
                ForEach(Array(block.messages.suffix(2)), id: \.id) { message in
                    Text(message.body)
                        .font(.system(size: 12))
                        .foregroundStyle(StudioTheme.Colors.textPrimary)
                        .lineLimit(3)
                }

            case .document:
                if let text = block.documentText {
                    Text(text)
                        .font(.system(size: 12))
                        .foregroundStyle(StudioTheme.Colors.textPrimary)
                        .lineLimit(4)
                }

            case .reference:
                if let text = block.documentText {
                    Text(text)
                        .font(.system(size: 12))
                        .foregroundStyle(StudioTheme.Colors.textPrimary)
                        .lineLimit(3)
                }
            }

            HStack(spacing: 6) {
                if block.isCanonical {
                    chip("CANONICAL")
                }

                chip(block.kind.rawValue.uppercased())
                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.Radii.card, style: .continuous)
                .fill(AppTheme.Colors.surface2)
                .overlay(
                    RoundedRectangle(cornerRadius: StudioTheme.Radii.card, style: .continuous)
                        .stroke(borderColor, lineWidth: isHovering || isSelected ? 1.4 : 1)

                )

        )
        .shadow(
            color: Color.black.opacity(isHovering || isSelected ? 0.18 : 0.10),
            radius: isHovering || isSelected ? 10 : 6,
            x: 0,
            y: isHovering || isSelected ? 8 : 6
        )
        .scaleEffect(hoverScale)
        .animation(
            reduceMotion ? .none : .spring(response: 0.22, dampingFraction: 0.85),
            value: isHovering
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Open in Console") {
                openInConsole()
            }
        }

    }


    private func chip(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(StudioTheme.Colors.panel)
            )
            .foregroundStyle(StudioTheme.Colors.textSecondary)

    }

    private var borderColor: Color {
        if isSelected {
            return StudioTheme.Colors.accent.opacity(0.75)
        }
        return isHovering ? StudioTheme.Colors.accent.opacity(0.7) : StudioTheme.Colors.borderSoft
    }

    private func openInConsole() {
        guard
            let scene = workspace.store.scene(id: block.sceneID),
            let track = workspace.store.track(id: scene.trackID),
            let project = workspace.store.project(id: track.projectID)
        else { return }

        let session = workspace.openConsole(for: block, project: project, track: track, scene: scene)
        workspace.touchConsoleSession(session.id)
        shellModeBinding?.wrappedValue = .console
    }
}
