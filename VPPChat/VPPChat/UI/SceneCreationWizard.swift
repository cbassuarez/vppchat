import SwiftUI

public struct SceneCreationWizard: View {
    public init(
        api: SceneWizardAPI,
        initialGoal: SceneWizardGoal,
        onDismiss: @escaping () -> Void
    ) {
        self.api = api
        self.goal = initialGoal
        self.onDismiss = onDismiss
    }

    private let api: SceneWizardAPI
    private let goal: SceneWizardGoal
    private let onDismiss: () -> Void

    public var body: some View {
        EnvironmentProjectTrackWizardForm(
            headerTitle: "Create your first structure",
            headerSubtitle: "Environment ▸ Project ▸ Topic ▸ Chat ▸ Messages",
            skipTitle: "Skip",
            onSkip: { onDismiss() },
            onFinish: { env, project, track in
                let envID = try await api.createEnvironment(name: env)
                let projectID = try await api.createProject(envID: envID, name: project)
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
