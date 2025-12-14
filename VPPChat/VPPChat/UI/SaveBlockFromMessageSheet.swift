import SwiftUI

struct SaveBlockFromMessageSheet: View {
    let message: ConsoleMessage
    let projects: [Project]

    /// Called with the final selection when user taps "Save".
    let onSave: (WorkspaceViewModel.SaveBlockSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workspace: WorkspaceViewModel

    @State private var selectedProjectID: Project.ID?
    @State private var selectedTrackID: Track.ID?
    @State private var selectedSceneID: Scene.ID?
    @State private var title: String
    @State private var isCanonical: Bool = false

    init(
        message: ConsoleMessage,
        projects: [Project],
        onSave: @escaping (WorkspaceViewModel.SaveBlockSelection) -> Void
    ) {
        self.message = message
        self.projects = projects
        self.onSave = onSave
        _title = State(initialValue: String(message.text.prefix(64)))
    }

    private var canSave: Bool {
        selectedProject != nil &&
        selectedTrack != nil &&
        selectedScene != nil &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedProject: Project? {
        let id = selectedProjectID ?? projects.first?.id
        return workspace.store.project(id: id)
    }

    private var selectedTrack: Track? {
        let id = selectedTrackID ?? selectedProject?.tracks.first
        return workspace.store.track(id: id)
    }

    private var selectedScene: Scene? {
        let id = selectedSceneID ?? selectedTrack?.scenes.first
        return workspace.store.scene(id: id)
    }

    private var tracks: [Track] {
        guard let project = selectedProject else { return [] }
        return project.tracks.compactMap { workspace.store.track(id: $0) }
    }

    private var scenes: [Scene] {
        guard let track = selectedTrack else { return [] }
        return track.scenes.compactMap { workspace.store.scene(id: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save as block in Studio")
                .font(.system(size: 16, weight: .semibold))

            TextField("Block title", text: $title)
                .textFieldStyle(.roundedBorder)

            Picker("Project", selection: Binding(
                get: { selectedProject?.id ?? projects.first?.id },
                set: { newID in
                    selectedProjectID = newID
                    selectedTrackID = nil
                    selectedSceneID = nil
                }
            )) {
                ForEach(projects) { project in
                    Text(project.name).tag(project.id as Project.ID?)
                }
            }

            if let project = selectedProject {
                Picker("Track", selection: Binding(
                    get: { selectedTrack?.id ?? project.tracks.first },
                    set: { newID in
                        selectedTrackID = newID
                        selectedSceneID = nil
                    }
                )) {
                    ForEach(tracks) { track in
                        Text(track.name).tag(track.id as Track.ID?)
                    }
                }
            }

            if let track = selectedTrack {
                Picker("Scene", selection: Binding(
                    get: { selectedScene?.id ?? track.scenes.first },
                    set: { newID in
                        selectedSceneID = newID
                    }
                )) {
                    ForEach(scenes) { scene in
                        Text(scene.title).tag(scene.id as Scene.ID?)
                    }
                }
            }

            Toggle("Mark as canonical", isOn: $isCanonical)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    guard let project = selectedProject,
                          let track = selectedTrack,
                          let scene = selectedScene else { return }

                    let selection = WorkspaceViewModel.SaveBlockSelection(
                        project: project,
                        track: track,
                        scene: scene,
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        isCanonical: isCanonical
                    )
                    onSave(selection)
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(minWidth: 420)
        .onAppear {
            if selectedProjectID == nil {
                selectedProjectID = projects.first?.id
            }
        }
    }
}
