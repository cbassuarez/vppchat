//
//  SceneCreationWizard.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/16/25.
//


import SwiftUI
import Combine

public struct SceneCreationWizard: View {
    public init(
        api: SceneWizardAPI,
        initialGoal: SceneWizardGoal,
        onDismiss: @escaping () -> Void
    ) {
        self.api = api
        self._model = StateObject(wrappedValue: Model(api: api, initialGoal: initialGoal))
        self.onDismiss = onDismiss
    }


    private let api: SceneWizardAPI
    @StateObject private var model: Model
    private let onDismiss: () -> Void


    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    stepHeader
                    stepBody
                    if let err = model.state.errorText {
                        Text(err)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.red)
                            .padding(.top, 6)
                    }
                }
                .padding(16)
            }
            Divider()
            footerButtons
        }
        .frame(minWidth: 560, minHeight: 520)
        .task {
            await model.refreshOptions()
        }
    }


    // MARK: - Header
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 16, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text(model.state.goal == .newChat ? "New Chat" : "New Scene")
                    .font(.system(size: 15, weight: .semibold))
                Text("Environment ▸ Project ▸ Track ▸ Scene")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(model.state.stepTitle.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }


    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.state.stepTitle)
                .font(.system(size: 12, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(model.state.stepHelp)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }


    // MARK: - Body
    @ViewBuilder
    private var stepBody: some View {
        switch model.state.step {
        case .goal:
            goalStep
        case .targetTrack:
            targetTrackStep


        case .createEnvironment:
            createNameStep(label: "Environment name", text: $model.state.envName, placeholder: "e.g. Default")


        case .populateEnvironment:
            populateStep(
                title: "Move projects into this environment",
                options: model.options.projects,
                selected: model.state.selectedProjectIDsToMove,
                onToggle: { id in model.send(.toggleMoveProject(id)) },
                createToggleTitle: "Create new project",
                createToggleValue: model.state.choseCreateNewProject,
                onCreateToggle: { model.send(.setChoseCreateNewProject($0)) },
                secondaryTitle: "Add directory (stub)",
                onSecondary: { model.addDirectoryStubCreatesProject() }
            )


        case .createProject:
            createNameStep(label: "Project name", text: $model.state.projectName, placeholder: "e.g. Constructions")


        case .populateProject:
            populateStep(
                title: "Move tracks into this project",
                options: model.options.tracks,
                selected: model.state.selectedTrackIDsToMove,
                onToggle: { id in model.send(.toggleMoveTrack(id)) },
                createToggleTitle: "Create new track",
                createToggleValue: model.state.choseCreateNewTrack,
                onCreateToggle: { model.send(.setChoseCreateNewTrack($0)) },
                secondaryTitle: nil,
                onSecondary: nil
            )


        case .createTrack:
            createNameStep(label: "Track name", text: $model.state.trackName, placeholder: "e.g. Research")


        case .populateTrack:
            populateStep(
                title: "Move scenes into this track (optional)",
                options: model.options.scenes,
                selected: model.state.selectedSceneIDsToMove,
                onToggle: { id in model.send(.toggleMoveScene(id)) },
                createToggleTitle: "Create new scene",
                createToggleValue: model.state.choseCreateNewScene,
                onCreateToggle: { model.send(.setChoseCreateNewScene($0)) },
                secondaryTitle: nil,
                onSecondary: nil
            )


        case .createScene:
            VStack(alignment: .leading, spacing: 10) {
                            Text("No naming here.")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Scenes are auto-named after your first message. You can rename later if you want.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

        }
    }


    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Goal", selection: Binding(
                get: { model.state.goal },
                set: { model.send(.setGoal($0)) }
            )) {
                Text("New Scene").tag(SceneWizardGoal.newScene)
                Text("New Chat").tag(SceneWizardGoal.newChat)
            }
            .pickerStyle(.segmented)


            Text("Both flows end by creating a brand-new Scene and navigating to it.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }


    private var targetTrackStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a destination track (or create upstream).")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)


            Picker("Track", selection: Binding(
                get: { model.state.trackID },
                set: { model.send(.setTrack($0)) }
            )) {
                Text("Select…").tag(Optional<UUID>(nil))
                ForEach(model.options.tracks) { t in
                    Text(t.title).tag(Optional(t.id))
                }
            }
            .pickerStyle(.menu)


            HStack(spacing: 10) {
                Button("Create new Environment") { model.jump(to: .createEnvironment) }
                Button("Create new Project") { model.jump(to: .createProject) }
                Button("Create new Track") { model.jump(to: .createTrack) }
            }
            .buttonStyle(.bordered)
        }
    }


    private func createNameStep(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }


    private func populateStep(
        title: String,
        options: [SceneWizardOption],
        selected: Set<UUID>,
        onToggle: @escaping (UUID) -> Void,
        createToggleTitle: String,
        createToggleValue: Bool,
        onCreateToggle: @escaping (Bool) -> Void,
        secondaryTitle: String?,
        onSecondary: (() -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))


            if options.isEmpty {
                Text("No items available to move.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(options) { opt in
                        Button {
                            onToggle(opt.id)
                        } label: {
                            HStack {
                                Image(systemName: selected.contains(opt.id) ? "checkmark.circle.fill" : "circle")
                                Text(opt.title)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }


            Toggle(createToggleTitle, isOn: Binding(
                get: { createToggleValue },
                set: { onCreateToggle($0) }
            ))


            if let secondaryTitle, let onSecondary {
                Button(secondaryTitle) { onSecondary() }
                    .buttonStyle(.bordered)
            }
        }
    }


    // MARK: - Footer buttons
    private var footerButtons: some View {
        HStack(spacing: 10) {
            Button("Cancel", role: .cancel) { onDismiss() }
                .disabled(model.state.isBusy)


            Spacer()


            Button("Back") { model.send(.back) }
                .disabled(model.state.isBusy || model.isAtFirstStep)


            Button(model.primaryCTATitle) {
                Task { await model.primaryPressed() }
            }
            .disabled(!model.canContinue)
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }
}


// MARK: - Model (reducer + effects)
extension SceneCreationWizard {
    @MainActor
    final class Model: ObservableObject {
        @Published var state: SceneWizardState
        @Published var options: SceneWizardOptionsSnapshot = .init()


        private let api: SceneWizardAPI
        private var reducer = SceneWizardReducer()


        init(api: SceneWizardAPI, initialGoal: SceneWizardGoal) {
            self.api = api
            var s = SceneWizardState()
            s.goal = initialGoal
            s.step = .targetTrack
            self.state = s
        }


        var canContinue: Bool { reducer.canContinue(state) }


        var isAtFirstStep: Bool {
            state.step == .goal || state.step == .targetTrack
        }


        var primaryCTATitle: String {
            switch state.step {
            case .createScene:
                return state.goal == .newChat ? "Create Chat" : "Create Scene"
            default:
                return "Continue"
            }
        }


        func send(_ action: SceneWizardAction) {
            reducer.reduce(&state, action)
        }


        func jump(to step: SceneWizardStep) {
            state.errorText = nil
            state.step = step
        }


        func refreshOptions() async {
            do {
                let envs = try await api.listEnvironments()
                let projects = try await api.listProjects()
                let tracks = try await api.listTracks()
                let scenes = try await api.listScenes()
                options.environments = envs
                options.projects = projects
                options.tracks = tracks
                options.scenes = scenes


                // seed best-effort defaults
                if state.envID == nil { state.envID = envs.first?.id }
                if state.projectID == nil { state.projectID = projects.first?.id }
                if state.trackID == nil { state.trackID = tracks.first?.id }
            } catch {
                state.errorText = "Failed to load options: \(error.localizedDescription)"
            }
        }


        func addDirectoryStubCreatesProject() {
            // This is UI-only stub; actual directory pick wiring belongs in your adapter.
            state.choseCreateNewProject = true
            if state.projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                state.projectName = "New Project"
            }
        }


        func primaryPressed() async {
            state.errorText = nil
            send(.setBusy(true))
            defer { send(.setBusy(false)) }


            do {
                switch state.step {
                case .goal:
                    send(.next)


                case .targetTrack:
                    // With an existing track selected, enforce populateTrack (hard-guard shape) then createScene.
                    jump(to: .populateTrack)


                case .createEnvironment:
                    let name = state.envName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { state.errorText = "Environment name can’t be empty."; return }
                    let id = try await api.createEnvironment(name: name)
                    state.envID = id
                    jump(to: .populateEnvironment)
                    await refreshOptions()


                case .populateEnvironment:
                    guard let envID = state.envID else { state.errorText = "Missing environment."; return }
                    if !state.selectedProjectIDsToMove.isEmpty {
                        try await api.moveProjects(projectIDs: Array(state.selectedProjectIDsToMove), to: envID)
                        await refreshOptions()
                    }
                    if state.choseCreateNewProject {
                        jump(to: .createProject)
                    } else {
                        // After moving projects, require a project to exist/choose; simplest is go createTrack (project selection can be refined later).
                        if state.projectID == nil { state.projectID = options.projects.first?.id }
                        jump(to: .populateProject)
                    }


                case .createProject:
                    guard let envID = state.envID else { state.errorText = "Pick or create an environment first."; return }
                    let name = state.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { state.errorText = "Project name can’t be empty."; return }
                    let id = try await api.createProject(envID: envID, name: name)
                    state.projectID = id
                    jump(to: .populateProject)
                    await refreshOptions()


                case .populateProject:
                    guard let projectID = state.projectID else { state.errorText = "Missing project."; return }
                    if !state.selectedTrackIDsToMove.isEmpty {
                        try await api.moveTracks(trackIDs: Array(state.selectedTrackIDsToMove), to: projectID)
                        await refreshOptions()
                        if state.trackID == nil { state.trackID = options.tracks.first?.id }
                        jump(to: .populateTrack)
                        return
                    }
                    if state.choseCreateNewTrack {
                        jump(to: .createTrack)
                    } else {
                        // If user didn’t move tracks and didn’t choose create new, we’re blocked by reducer guard anyway.
                        state.errorText = "Select tracks to move or choose Create new track."
                    }


                case .createTrack:
                    guard let projectID = state.projectID else { state.errorText = "Pick or create a project first."; return }
                    let name = state.trackName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { state.errorText = "Track name can’t be empty."; return }
                    let id = try await api.createTrack(projectID: projectID, name: name)
                    state.trackID = id
                    jump(to: .populateTrack)
                    await refreshOptions()


                case .populateTrack:
                    guard let trackID = state.trackID else { state.errorText = "Missing track."; return }
                    if !state.selectedSceneIDsToMove.isEmpty {
                        try await api.moveScenes(sceneIDs: Array(state.selectedSceneIDsToMove), to: trackID)
                        await refreshOptions()
                    }
                    // Always proceed to CreateScene
                    jump(to: .createScene)


                case .createScene:
                    guard let trackID = state.trackID else { state.errorText = "Missing track."; return }
                    state.sceneName = ""
                                        let placeholderTitle = "Untitled"
                                        let sceneID = try await api.createScene(trackID: trackID, name: placeholderTitle)


                    // completion invariant
                    await api.selectScene(sceneID)
                    switch state.goal {
                    case .newScene:
                        await api.goToStudio()
                    case .newChat:
                        await api.goToConsole()
                    }
                }
            } catch {
                state.errorText = error.localizedDescription
            }
        }
    }
}


// MARK: - Step titles/help
private extension SceneWizardState {
    var stepTitle: String {
        switch step {
        case .goal: return "Goal"
        case .targetTrack: return "Target"
        case .createEnvironment: return "Create Environment"
        case .populateEnvironment: return "Populate Environment"
        case .createProject: return "Create Project"
        case .populateProject: return "Populate Project"
        case .createTrack: return "Create Track"
        case .populateTrack: return "Populate Track"
        case .createScene: return "Create Scene"
        }
    }


    var stepHelp: String {
        switch step {
        case .goal:
            return "Choose whether you’re creating a Scene or starting a new Chat."
        case .targetTrack:
            return "Pick an existing Track, or create upstream containers."
        case .createEnvironment:
            return "Create a top-level environment."
        case .populateEnvironment:
            return "Environment must end with at least one project (move or create)."
        case .createProject:
            return "Create a project inside the selected environment."
        case .populateProject:
            return "Project must end with at least one track (move or create)."
        case .createTrack:
            return "Create a track inside the selected project."
        case .populateTrack:
            return "Track must end with at least one scene (move or create). Wizard still ends by creating a new Scene."
        case .createScene:
            return "This is always the final step. Completion creates a brand-new Scene, auto-named after first message."
        }
    }
}
