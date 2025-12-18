import SwiftUI

struct MainToolbar: View {
    @Binding var mode: ShellMode

    @EnvironmentObject private var themeManager: ThemeManager
    @Namespace private var indicatorNS

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Text("VPP")
                    .font(AppTheme.Typography.wordmark)
                    .kerning(1.2)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text(currentModeLabel)
                    .font(AppTheme.Typography.wordmarkSub)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Spacer()

            HStack(spacing: 8) {
                modeChip(icon: "bubble.left.and.bubble.right.fill", label: "Console", mode: .console)
                modeChip(icon: "slider.horizontal.3", label: "Studio", mode: .studio)
                modeChip(icon: "compass.drawing", label: "Atlas", mode: .atlas)
            }

            Spacer()


        }
    }

    private func modeChip(icon: String, label: String, mode target: ShellMode) -> some View {
        let isActive = mode == target

        return Button {
            withAnimation(.spring(response: AppTheme.Motion.medium,
                                  dampingFraction: 0.85,
                                  blendDuration: 0.2)) {
                mode = target
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(AppTheme.Typography.chip)
                Text(label)
                    .font(AppTheme.Typography.chip)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: 72)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radii.card, style: .continuous)
                    .fill(isActive ? AppTheme.Colors.structuralAccent.opacity(0.22)
                                   : AppTheme.Colors.surface2.opacity(0.6))
            )
            .overlay(alignment: .bottom) {
                if isActive {
                    Capsule()
                        .fill(AppTheme.Colors.structuralAccent)
                        .frame(height: 2)
                        .matchedGeometryEffect(id: "modeIndicator", in: indicatorNS)
                        .padding(.horizontal, 10)
                        .offset(y: 3)
                }
            }
            .foregroundStyle(isActive ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var currentModeLabel: String {
        switch mode {
        case .console: return "Console · VPP Chat"
        case .studio:  return "Studio · Projects & blocks"
        case .atlas:   return "Atlas · Recent work"
        }
    }
}
