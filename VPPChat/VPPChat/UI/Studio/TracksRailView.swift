import SwiftUI

struct TracksRailView: View {
    @EnvironmentObject private var vm: WorkspaceViewModel
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tracks")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(StudioTheme.Colors.textPrimary)
                Spacer()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(vm.store.allProjects) { project in
                        projectSection(project)
                    }
                }
            }
        }
        .padding(12)
        .background(
            ZStack {
               

                RoundedRectangle(cornerRadius: StudioTheme.Radii.panel, style: .continuous)
                    .fill(AppTheme.Colors.surface1)

                RoundedRectangle(cornerRadius: StudioTheme.Radii.panel, style: .continuous)
                    .stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
            }
            .clipShape(
                RoundedRectangle(cornerRadius: StudioTheme.Radii.panel, style: .continuous)
            )
        )
    }

    private func projectSection(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(StudioTheme.Colors.textSecondary)

            ForEach(project.tracks, id: \.self) { trackID in
                if let track = vm.store.track(id: trackID) {
                    trackRow(track)
                }
            }
        }
        .padding(10)
        .background(
            ZStack {
               

                RoundedRectangle(cornerRadius: StudioTheme.Radii.card, style: .continuous)
                    .fill(AppTheme.Colors.surface1)
            }
            .clipShape(
                RoundedRectangle(cornerRadius: StudioTheme.Radii.card, style: .continuous)
            )
        )
    }

    private func trackRow(_ track: Track) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                vm.select(track: track)
            } label: {
                HStack {
                    Text(track.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(StudioTheme.Colors.textPrimary)
                    Spacer()
                    if vm.selectedTrackID == track.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(StudioTheme.Colors.accent)
                            .font(.system(size: 12, weight: .bold))
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(track.scenes, id: \.self) { sceneID in
                    if let scene = vm.store.scene(id: sceneID) {
                        Button {
                            vm.select(track: track)
                            vm.select(scene: scene)
                        } label: {
                            HStack {
                                Text(scene.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(vm.selectedSceneID == scene.id
                                                     ? theme.structuralAccent
                                                     : StudioTheme.Colors.textSecondary)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(vm.selectedSceneID == scene.id ? theme.structuralAccent.opacity(0.16) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
