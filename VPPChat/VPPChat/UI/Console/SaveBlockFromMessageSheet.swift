import SwiftUI

struct SaveBlockFromMessageSheet: View {
    let message: ConsoleMessage
    let projects: [Project]

    /// Called with the final selection when user taps "Save".
    let onSave: (WorkspaceViewModel.SaveBlockSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var workspace: WorkspaceViewModel
    @State private var selectedProject: Project?
    @State private var selectedTrack: Track?
    @State private var selectedScene: Scene?
    @State private var title: String
    @State private var isCanonical: Bool = false

    private var resolvedProject: Project? { selectedProject ?? projects.first }
    private var resolvedTrack: Track? { selectedTrack ?? defaultTrack(for: resolvedProject) }
    private var resolvedScene: Scene? { selectedScene ?? (resolvedTrack.flatMap { defaultScene(for: $0) }) }

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
        resolvedProject != nil &&
        resolvedTrack != nil &&
        resolvedScene != nil &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Save as block in Studio")
                .font(.system(size: 16, weight: .semibold))

            TextField("Block title", text: $title)
                .textFieldStyle(.roundedBorder)

            Picker("Project", selection: Binding(
                get: { (selectedProject ?? projects.first)?.id },
                set: { newID in
                    selectedProject = projects.first(where: { $0.id == newID })
                    selectedTrack = nil
                    selectedScene = nil
                }
            )) {
                ForEach(projects) { project in
                    Text(project.name).tag(project.id)
                }
            }

            if let project = resolvedProject {
                Picker("Track", selection: Binding(
                    get: { (selectedTrack ?? project.tracks.compactMap { id in
                        workspace.store.track(id: id)
                    }.first)?.id },
                    set: { newID in
                        selectedTrack = project.tracks.compactMap { id in
                            workspace.store.track(id: id)
                        }.first(where: { $0.id == newID })
                        selectedScene = nil
                    }
                )) {
                    ForEach(project.tracks.compactMap { id in workspace.store.track(id: id) }) { track in
                        Text(track.name).tag(track.id)
                    }
                }
            }

            if let track = resolvedTrack {
                Picker("Scene", selection: Binding(
                    get: { (selectedScene ?? track.scenes.compactMap { id in workspace.store.scene(id: id) }.first)?.id },
                    set: { newID in
                        selectedScene = track.scenes.compactMap { id in workspace.store.scene(id: id) }.first(where: { $0.id == newID })
                    }
                )) {
                    ForEach(track.scenes.compactMap { id in workspace.store.scene(id: id) }) { scene in
                        Text(scene.title).tag(scene.id)
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
                    guard
                        let project = resolvedProject,
                        let track = resolvedTrack,
                        let scene = resolvedScene
                    else { return }

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
            if selectedProject == nil {
                selectedProject = projects.first
            }

            if selectedTrack == nil, let project = resolvedProject {
                selectedTrack = defaultTrack(for: project)
            }

            if selectedScene == nil, let track = resolvedTrack {
                selectedScene = defaultScene(for: track)
            }
        }
    }

    private func defaultTrack(for project: Project?) -> Track? {
        guard let project else { return nil }
        return project.tracks.compactMap { workspace.store.track(id: $0) }.first
    }

    private func defaultScene(for track: Track) -> Scene? {
        track.scenes.compactMap { workspace.store.scene(id: $0) }.first
    }
}
