import SwiftUI

struct CommandSpaceView: View {
    @EnvironmentObject private var vm: WorkspaceViewModel

    @State private var query: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Command Space")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(StudioTheme.Colors.textPrimary)
                Spacer()
                Button(action: { withAnimation { vm.isCommandSpaceVisible = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(StudioTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }

            TextField("Jump to block, scene, or command", text: $query)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.Colors.surface0)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(StudioTheme.Colors.borderSoft.opacity(0.7), lineWidth: 0.5)
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .foregroundStyle(StudioTheme.Colors.textPrimary)


            Text("Suggestions coming soon")
                .font(.system(size: 11))
                .foregroundStyle(StudioTheme.Colors.textSecondary)
        }
        .padding(16)
        .background(
            // Blur at 0.5 opacity, clipped to the rounded rect
            .thinMaterial.opacity(0.35),
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
        .shadow(color: .black.opacity(0.09), radius: 6, x: 6, y: 6)
        .padding()
    }
}
