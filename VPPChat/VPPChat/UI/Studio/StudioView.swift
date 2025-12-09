import SwiftUI

struct StudioView: View {
    @EnvironmentObject private var vm: WorkspaceViewModel

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
                RoundedRectangle(cornerRadius: StudioTheme.Radii.panel, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: StudioTheme.Radii.panel, style: .continuous)
                            .stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
                    )
            )
        }
        .padding(18)
        .overlay(alignment: .top) {
            if vm.isCommandSpaceVisible {
                CommandSpaceView()
                    .environmentObject(vm)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var header: some View {
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
        .padding(.horizontal, 6)
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
            RoundedRectangle(cornerRadius: StudioTheme.Radii.panel, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}
