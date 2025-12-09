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
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.thinMaterial)
                )
                .foregroundStyle(StudioTheme.Colors.textPrimary)

            Text("Suggestions coming soon")
                .font(.system(size: 11))
                .foregroundStyle(StudioTheme.Colors.textSecondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
                )
        )
        .padding()
    }
}
