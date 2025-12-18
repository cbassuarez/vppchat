//
//  RootWindowView.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import SwiftUI

struct RootWindowView: View {
  @Binding var shellMode: ShellMode

  @EnvironmentObject private var workspaceVM: WorkspaceViewModel
  @EnvironmentObject private var themeManager: ThemeManager

  var body: some View {
    ZStack(alignment: .top) {
      NoiseBackground()

      MainShellView(mode: $shellMode)
        .environment(\.shellModeBinding, $shellMode)

      if workspaceVM.isCommandSpaceVisible {
        Color.black
          .opacity(AppTheme.Motion.commandSpaceDimOpacity)
          .ignoresSafeArea()
          .transition(.opacity)
          .allowsHitTesting(false)

        CommandSpaceView()
          .padding(.top, 18)
          .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .onChange(of: workspaceVM.isCommandSpaceVisible) { visible in
      themeManager.signal(visible ? .commandSpaceOpen : .commandSpaceClose)
    }
    .animation(.easeInOut(duration: AppTheme.Motion.medium),
               value: workspaceVM.isCommandSpaceVisible)
    .sheet(isPresented: $workspaceVM.isSceneCreationWizardPresented) {
        SceneCreationWizard(
            api: WorkspaceSceneWizardAdapter(vm: workspaceVM),
            initialGoal: workspaceVM.sceneCreationWizardInitialGoal,
            startStep: workspaceVM.sceneCreationWizardStartStep,
            existingEnvironmentID: workspaceVM.sceneCreationWizardExistingEnvironmentID,
            existingProjectID: workspaceVM.sceneCreationWizardExistingProjectID,
            prefillEnvironmentName: workspaceVM.sceneCreationWizardPrefillEnvironmentName,
            prefillProjectName: workspaceVM.sceneCreationWizardPrefillProjectName,
            skipPlacement: workspaceVM.sceneCreationWizardSkipPlacement,
            onDismiss: { workspaceVM.isSceneCreationWizardPresented = false }
        )
    }
  }
}
