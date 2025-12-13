import SwiftUI

struct ConsoleShellView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        HStack(spacing: 16) {
            SidebarView()
                .environmentObject(appViewModel)
                .frame(width: 260)

            if let selected = appViewModel.selectedSession {
                SessionView(session: selected, appViewModel: appViewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                            .fill(AppTheme.Colors.surface0.opacity(0.9))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                                    .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                            )
                    )
            } else {
                consolePlaceholder
            }
        }
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
            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                .fill(AppTheme.Colors.surface0.opacity(0.9))
        )
    }
}
