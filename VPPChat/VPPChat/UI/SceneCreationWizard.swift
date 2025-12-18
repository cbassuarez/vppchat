import SwiftUI

public enum SceneCreationWizardStartStep: Int, CaseIterable {
    case environment = 0
    case project = 1
    case track = 2
}

 struct SceneCreationWizard: View {
     init(
        api: SceneWizardAPI,
        initialGoal: SceneWizardGoal,
        startStep: SceneCreationWizardStartStep = .environment,
        existingEnvironmentID: UUID? = nil,
        existingProjectID: UUID? = nil,
            prefillEnvironmentName: String? = nil,
            prefillProjectName: String? = nil,
            prefillTrackName: String? = nil,
            skipPlacement: Bool = false,

        onDismiss: @escaping () -> Void
    ) {
        self.api = api
        self.goal = initialGoal
        self.startStep = startStep
        self.existingEnvironmentID = existingEnvironmentID
        self.existingProjectID = existingProjectID

                self.prefillEnvironmentName = prefillEnvironmentName
                self.prefillProjectName = prefillProjectName
                self.prefillTrackName = prefillTrackName
                self.skipPlacement = skipPlacement
        self.onDismiss = onDismiss
    }

    private let api: SceneWizardAPI
    private let goal: SceneWizardGoal
    private let startStep: SceneCreationWizardStartStep
     private let existingEnvironmentID: UUID?
     private let existingProjectID: UUID?
        private let prefillEnvironmentName: String?
        private let prefillProjectName: String?
        private let prefillTrackName: String?
        private let skipPlacement: Bool
    private let onDismiss: () -> Void
    
    private var formStartStep: EnvironmentProjectTrackWizardForm.Step {
            switch startStep {
            case .environment: return .environment
            case .project:     return .project
            case .track:       return .track
            }
        }


     var body: some View {
        EnvironmentProjectTrackWizardForm(
            headerTitle: "Create your first structure",
            headerSubtitle: "Environment ▸ Project ▸ Topic ▸ Chat ▸ Messages",
            skipTitle: "Skip",
            onSkip: { onDismiss() },
            initialStep: formStartStep,
                        prefillEnvironmentName: prefillEnvironmentName,
                        prefillProjectName: prefillProjectName,
                        prefillTrackName: prefillTrackName,
                        skipPlacement: skipPlacement,

            onFinish: { env, project, track in
                let envID: UUID
                 if let existingEnvironmentID {
                   envID = existingEnvironmentID
                 } else {
                   envID = try await api.createEnvironment(name: env)
                 }
               
                 let projectID: UUID
                 if let existingProjectID {
                   projectID = existingProjectID
                 } else {
                   projectID = try await api.createProject(envID: envID, name: project)
                 }
                let trackID = try await api.createTrack(projectID: projectID, name: track)

                let placeholderTitle = "Untitled"
                let sceneID = try await api.createScene(trackID: trackID, name: placeholderTitle)

                await api.selectScene(sceneID)

                switch goal {
                case .newScene:
                    await api.goToStudio()
                case .newChat:
                    await api.goToConsole()
                }

                onDismiss()
            }
        )
    }
}
