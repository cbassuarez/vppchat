import SwiftUI

struct StudioView: View {
    @EnvironmentObject private var vm: WorkspaceViewModel
    @EnvironmentObject private var theme: ThemeManager
    @State private var isAccentDrawerPresented = false

    @State private var isThemeDrawerOpen = false
    

    var body: some View {
        
        VStack(spacing: 14) {
            header
            
            HStack(alignment: .top, spacing: 14) {
                TracksRailView()
                    .environmentObject(vm)
                    .frame(width: 240)
                
                if let scene = vm.selectedScene {
                    SceneCanvasView(scene: scene)
                        .environmentObject(vm)
                } else {
                    placeholder
                }
                
                InspectorView()
                    .frame(width: 260)
            }
            .padding(12)
            .background(
                            ZStack {
                                
                                // Light tint so it reads as glass, not metal
                                RoundedRectangle(cornerRadius: StudioTheme.Radii.panel, style: .continuous)
                                    .fill(AppTheme.Colors.surface0)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: StudioTheme.Radii.panel, style: .continuous)
                                            .stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
                                    )
                            }
                        )
        }
        .padding(18)
    }
    
    
    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("VPP Studio")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(StudioTheme.Colors.textPrimary)

                if let project = vm.selectedProject {
                    Text("·")
                        .foregroundStyle(StudioTheme.Colors.textSecondary)
                    Text(project.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(StudioTheme.Colors.textSecondary)
                }

                Spacer()

                // THEME DRAWER TOGGLE
                themeControl

                Button(action: { withAnimation { vm.isCommandSpaceVisible.toggle() } }) {
                    Label("Command", systemImage: "macwindow.on.rectangle")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(StudioTheme.Colors.panel)
                        )
                        .overlay(
                            Capsule()
                                .stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
                        )
                        .foregroundStyle(StudioTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }

            if isThemeDrawerOpen {
                paletteRow
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 6)
    }

    
    
    private var themeControl: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                isThemeDrawerOpen.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 13, weight: .semibold))
                Text("Theme")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(StudioTheme.Colors.surface1)
            .clipShape(Capsule())
            .foregroundStyle(StudioTheme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }
    @ViewBuilder
    private var paletteRow: some View {
        HStack(spacing: 8) {
            ForEach(AccentPalette.allCases, id: \.self) { palette in
                paletteChip(palette)
            }
            Spacer(minLength: 0)
        }
    }

    private func paletteChip(_ palette: AccentPalette) -> some View {
        let isSelected = (palette == theme.palette)

        return Button {
            // Single source of truth: ThemeManager
            theme.palette = palette
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(palette.structural)
                    .frame(width: 10, height: 10)
                Circle()
                    .fill(palette.exception)
                    .frame(width: 10, height: 10)
                Text(palette.rawValue.capitalized)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(
                        isSelected
                        ? StudioTheme.Colors.accentSoft
                        : StudioTheme.Colors.surface1
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected
                        ? StudioTheme.Colors.accent
                        : StudioTheme.Colors.borderSoft,
                        lineWidth: isSelected ? 1.2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var placeholder: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("Select a scene to begin")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(StudioTheme.Colors.textPrimary)
            Text("Use the tracks rail to choose a scene.")
                .font(.system(size: 12))
                .foregroundStyle(StudioTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(
            ZStack {
                            
                            RoundedRectangle(cornerRadius: StudioTheme.Radii.panel, style: .continuous)
                                .fill(AppTheme.Colors.surface0)
                        }        )
    }

}
