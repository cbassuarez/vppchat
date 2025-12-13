import SwiftUI

struct MainToolbar: View {
    @Binding var mode: ShellMode

    @EnvironmentObject private var themeManager: ThemeManager
    @Namespace private var indicatorNS

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Text("VPP")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .kerning(1.2)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text(currentModeLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Spacer()

            HStack(spacing: 8) {
                modeChip(icon: "bubble.left.and.bubble.right.fill", label: "Console", mode: .console)
                modeChip(icon: "slider.horizontal.3", label: "Studio", mode: .studio)
                modeChip(icon: "square.grid.2x2", label: "Atlas", mode: .atlas)
            }

            Spacer()

            HStack(spacing: 8) {
                if mode == .studio || mode == .atlas {
                    paletteMenu
                }

                Button {
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.Radii.card, style: .continuous)
                                .fill(AppTheme.Colors.surface1.opacity(0.9))
                        )
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
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
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: 72)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radii.card, style: .continuous)
                    .fill(isActive ? AppTheme.Colors.structuralAccent.opacity(0.22)
                                   : AppTheme.Colors.surface1.opacity(0.6))
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

    private var paletteMenu: some View {
        Menu {
            ForEach(AccentPalette.allCases, id: \.self) { palette in
                Button {
                    themeManager.palette = palette
                } label: {
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(palette.structural)
                                .frame(width: 8, height: 8)
                            Circle()
                                .fill(palette.exception)
                                .frame(width: 8, height: 8)
                            Circle()
                                .fill(AppTheme.Colors.surface2)
                                .frame(width: 8, height: 8)
                        }
                        Text(palette.rawValue.capitalized)
                        if palette == themeManager.palette {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "paintpalette")
                Text("Theme")
                    .font(.system(size: 11, weight: .semibold))
            }
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radii.card, style: .continuous)
                    .fill(AppTheme.Colors.surface1.opacity(0.9))
            )
            .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    private var currentModeLabel: String {
        switch mode {
        case .console: return "Console · VPP Chat"
        case .studio:  return "Studio · Projects & blocks"
        case .atlas:   return "Atlas · Recent work"
        }
    }
}
