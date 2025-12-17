//
//  FirstRunOnboardingWizard.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/17/25.
//


import SwiftUI

struct FirstRunOnboardingWizard: View {
  @EnvironmentObject private var workspaceVM: WorkspaceViewModel
  @Environment(\.dismiss) private var dismiss

  private enum Step: Int, CaseIterable { case environment = 0, project = 1, track = 2 }

  @State private var step: Step = .environment
  @State private var envName: String = "Personal"
  @State private var projectName: String = "Getting Started"
  @State private var trackName: String = "Read Me First"
  @State private var isWorking: Bool = false

  var body: some View {
    VStack(spacing: 14) {
      header
      Divider().overlay(StudioTheme.Colors.borderSoft.opacity(0.7))

      VStack(alignment: .leading, spacing: 10) {
        Text(title).font(.system(size: 15, weight: .semibold))
        Text(copy)
          .font(.system(size: 12))
          .foregroundStyle(StudioTheme.Colors.textSecondary)

        field
          .textFieldStyle(.roundedBorder)
          .disabled(isWorking)
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)

      Divider().overlay(StudioTheme.Colors.borderSoft.opacity(0.7))

      HStack {
        Button("Skip") {
          workspaceVM.isFirstRunOnboardingPresented = false
          dismiss()
        }
        .buttonStyle(.plain)
        .foregroundStyle(StudioTheme.Colors.textSecondary)

        Spacer()

        Button("Back") { step = Step(rawValue: max(0, step.rawValue - 1))! }
          .disabled(step == .environment || isWorking)

        Button(step == .track ? "Finish" : "Continue") {
          if step == .track { finish() }
          else { step = Step(rawValue: step.rawValue + 1)! }
        }
        .disabled(isWorking || currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
      .padding(16)
    }
    .frame(width: 520)
    .background(StudioTheme.Colors.surface1)
  }

  private var header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text("Create your first structure")
          .font(.system(size: 14, weight: .semibold))
        Text("Environment ▸ Project ▸ Track ▸ Scene ▸ Blocks")
          .font(.system(size: 11))
          .foregroundStyle(StudioTheme.Colors.textSecondary)
      }
      Spacer()
    }
    .padding(16)
  }

  private var title: String {
    switch step {
    case .environment: return "Step 1 — Environment"
    case .project:     return "Step 2 — Project"
    case .track:       return "Step 3 — Track"
    }
  }

  private var copy: String {
    switch step {
    case .environment: return "Environments are top-level spaces (e.g. Work, School, Client)."
    case .project:     return "Projects group related work inside an environment."
    case .track:       return "Tracks are lanes for parallel workstreams (e.g. Writing, Research, Build)."
    }
  }

  private var currentText: String {
    switch step {
    case .environment: return envName
    case .project:     return projectName
    case .track:       return trackName
    }
  }

  @ViewBuilder private var field: some View {
    switch step {
    case .environment:
      TextField("Environment name", text: $envName)
    case .project:
      TextField("Project name", text: $projectName)
    case .track:
      TextField("Track name", text: $trackName)
    }
  }

  private func finish() {
    isWorking = true
    Task { @MainActor in
      await workspaceVM.completeFirstRunOnboarding(
        environmentName: envName,
        projectName: projectName,
        trackName: trackName
      )
      isWorking = false
      dismiss()
    }
  }
}
