import SwiftUI

struct FirstRunOnboardingWizard: View {
    @EnvironmentObject private var workspaceVM: WorkspaceViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        EnvironmentProjectTrackWizardForm(
            headerTitle: "Create your first structure",
            headerSubtitle: "Environment ▸ Project ▸ Topic ▸ Chat ▸ Messages",
            skipTitle: "Skip",
            onSkip: {
                workspaceVM.skipFirstRunOnboarding()
                dismiss()
            },
            onFinish: { env, project, track in
                await workspaceVM.completeFirstRunOnboarding(
                    environmentName: env,
                    projectName: project,
                    trackName: track
                )
                dismiss()
            }
        )
        .onAppear {
            print("ONBOARDING wizard workspaceVM.instanceID =", workspaceVM.instanceID)
        }
    }
}
