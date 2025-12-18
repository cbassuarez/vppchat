import SwiftUI

struct StudioView: View {
    @EnvironmentObject private var vm: WorkspaceViewModel
    @EnvironmentObject private var theme: ThemeManager
    @State private var isAccentDrawerPresented = false
    @State private var isThemeDrawerOpen = false
    @State private var activePopover: StudioPopover? = nil
    @State private var isNewHovered = false
    @Environment(\.shellModeBinding) private var shellModeBinding
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 14) {
                header

                HStack(alignment: .top, spacing: 16) {
                    TracksRailView()
                        .environmentObject(vm)
                        .frame(width: 240)

                    if let scene = vm.selectedScene {
                        SceneCanvasView(scene: scene)
                            .environmentObject(vm)
                            .padding(.horizontal, 2)
                    } else {
                        placeholder
                    }

                    InspectorView()
                        .frame(width: 260)
                        .padding(.leading, 4)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .panelBackground()
            }
        }
        .padding(18)
        .onAppear { print("studioView workspace instance: \(vm.instanceID)") }
        .overlayPreferenceValue(StudioPopoverAnchorKey.self) { anchors in
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    if let active = activePopover, let anchor = anchors[active] {
                        let rect = proxy[anchor]
                        popover(for: active)
                            .fixedSize(horizontal: true, vertical: true)
                            .frame(maxWidth: 320, alignment: .leading)
                            .offset(x: rect.minX, y: rect.maxY + 8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
    
    private enum StudioPopover: Hashable { case new }

    private struct StudioPopoverAnchorKey: PreferenceKey {
        static var defaultValue: [StudioPopover: Anchor<CGRect>] = [:]
        static func reduce(value: inout [StudioPopover: Anchor<CGRect>],
                           nextValue: () -> [StudioPopover: Anchor<CGRect>]) {
            value.merge(nextValue(), uniquingKeysWith: { $1 })
        }
    }

    
    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("VPP Studio")
                    .font(AppTheme.Typography.wordmark)
                    .foregroundStyle(StudioTheme.Colors.textPrimary)

                if let project = vm.selectedProject {
                    Text("·")
                        .foregroundStyle(StudioTheme.Colors.textSecondary)
                    Text(project.name)
                        .font(AppTheme.Typography.mono(11))
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
                
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        activePopover = (activePopover == .new ? nil : .new)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13, weight: .semibold))

                        Text("New")
                            .font(.system(size: 12, weight: .semibold))

                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8) // <= same height class as Command
                    .background(
                        Capsule().fill(StudioTheme.Colors.accent) // <= not translucent
                    )
                    .overlay(
                        Capsule().stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
                    )
                    .shadow(
                        color: StudioTheme.Colors.accent.opacity(isNewHovered ? 0.34 : 0.0),
                        radius: isNewHovered ? 14 : 0, x: 0, y: 0
                    )
                    .shadow(
                        color: StudioTheme.Colors.accent.opacity(isNewHovered ? 0.16 : 0.0),
                        radius: isNewHovered ? 26 : 0, x: 0, y: 0
                    )
                    .foregroundStyle(Color.white) // ✅ text + chevron + glyph = white
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.26)) { // ✅ glow takes a bit longer
                        isNewHovered = hovering
                    }
                }
                .anchorPreference(key: StudioPopoverAnchorKey.self, value: .bounds) { anchor in
                    [.new: anchor]
                }


            }

            if isThemeDrawerOpen {
                paletteRow
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 6)
    }

    struct PrimaryPillButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(StudioTheme.Colors.accentSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
        }
    }

    struct MenuRowButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.Colors.surface2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                )
                .opacity(configuration.isPressed ? 0.9 : 1.0)
        }
    }

    @ViewBuilder
    private func popover(for popover: StudioPopover) -> some View {
        switch popover {
        case .new:
            NewStudioPopover(
                onNewChat: {
                    let openInConsole = (shellModeBinding?.wrappedValue == .console)
                    vm.quickNewChat(openInConsole: openInConsole)

                    activePopover = nil
                },
                onNewWizard: {
                    vm.presentNewChatEnvironmentFlow()
                    activePopover = nil

                            }

            )
        }
    }

    private struct NewStudioPopover: View {
        let onNewChat: () -> Void
        let onNewWizard: () -> Void

        var body: some View {
            PopoverChrome {
                Button(action: onNewChat) {
                    HStack {
                        Image(systemName: "message.fill")
                        Text("New Chat")
                        Spacer()
                    }
                    .font(.system(size: 12, weight: .regular))
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)

                Divider()

                Button(action: onNewWizard) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("New…")
                        Spacer()
                    }
                    .font(.system(size: 12, weight: .regular))
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
        }
    }

    // EXACT Atlas chrome
    private struct PopoverChrome<Content: View>: View {
        @ViewBuilder var content: Content
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(12)
            .background(
                .ultraThinMaterial.opacity(0.5),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.Colors.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.10), radius: 16, x: 6, y: 12)
            .transition(
                reduceMotion
                ? .opacity
                : .scale(scale: 0.96, anchor: .topLeading).combined(with: .opacity)
            )
        }
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
            Text("Select a chat to begin")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(StudioTheme.Colors.textPrimary)
            Text("Use the topics bar to choose a chat.")
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
