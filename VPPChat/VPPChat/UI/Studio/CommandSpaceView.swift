import SwiftUI

import SwiftUI

struct CommandSpaceView: View {
    @EnvironmentObject private var vm: WorkspaceViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var query: String = ""
    @State private var isHovering: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Command Space")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(StudioTheme.Colors.textPrimary)

                Spacer()

                if isHovering {
                    Text("⌘K")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(StudioTheme.Colors.textSecondary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Button(action: {
                    withAnimation(reduceMotion ? .default : AppTheme.Motion.commandSpace) {
                        vm.isCommandSpaceVisible = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(StudioTheme.Colors.textSecondary)
                        .symbolRenderingMode(.hierarchical)
#if os(macOS)
                        .symbolEffect(.bounce, value: vm.isCommandSpaceVisible)
#endif
                }
                .buttonStyle(.plain)
            }

            TextField("Jump to block, scene, or command", text: $query)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    // Blur + tint, both clipped to the same rounded rect
                    .ultraThinMaterial.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.Colors.surface0)
                )
                .foregroundStyle(StudioTheme.Colors.textPrimary)

            Text("Suggestions coming soon")
                .font(.system(size: 11))
                .foregroundStyle(StudioTheme.Colors.textSecondary)
        }
        .padding(16)
        .background(
            // Outer glass card
            .ultraThinMaterial.opacity(0.5),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.Colors.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 6, y: 12)
        .padding()
        .onHover { hovering in
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.18)) {
                isHovering = hovering
            }
        }
    }
}

