//
//  EnvironmentProjectTrackWizardForm.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/17/25.
//


import SwiftUI

/// Canonical, shared 3-step form:
/// Environment -> Project -> Topic
///
/// Both FirstRunOnboardingWizard and SceneCreationWizard should use this,
/// so parity is guaranteed (same steps, copy, suggested chips, layout).
struct EnvironmentProjectTrackWizardForm: View {
    let headerTitle: String
    let headerSubtitle: String
    let skipTitle: String
    let onSkip: () -> Void
   
    let onFinish: (_ environmentName: String, _ projectName: String, _ trackName: String) async throws -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Step: Int, CaseIterable { case environment = 0, project = 1, track = 2 }
        private let initialStep: Step
        private let prefillEnvironmentName: String?
        private let prefillProjectName: String?
        private let prefillTrackName: String?
        private let skipPlacement: Bool
        @State private var step: Step
        @State private var envName: String
        @State private var projectName: String
        @State private var trackName: String

    @State private var didSeedFromPrefill: Bool = false
    @State private var isWorking: Bool = false
    @State private var errorText: String?
    init(
            headerTitle: String,
            headerSubtitle: String,
            skipTitle: String,
            onSkip: @escaping () -> Void,
            initialStep: Step = .environment,
            prefillEnvironmentName: String? = nil,
            prefillProjectName: String? = nil,
            prefillTrackName: String? = nil,
            skipPlacement: Bool = false,
            onFinish: @escaping (_ environmentName: String, _ projectName: String, _ trackName: String) async throws -> Void
        ) {
            // If placement is already known (i.e., caller is routing from an existing parent),
                       // automatically jump past earlier steps implied by the prefills.
                       let resolvedInitialStep: Step = {
                           guard skipPlacement else { return initialStep }
                           if prefillProjectName != nil || prefillTrackName != nil { return .track }
                           if prefillEnvironmentName != nil { return .project }
                           return initialStep
                       }()
            self.headerTitle = headerTitle
            self.headerSubtitle = headerSubtitle
            self.skipTitle = skipTitle
            self.onSkip = onSkip
            self.onFinish = onFinish
            self.initialStep = resolvedInitialStep
            self.prefillEnvironmentName = prefillEnvironmentName
            self.prefillProjectName = prefillProjectName
            self.prefillTrackName = prefillTrackName
            self.skipPlacement = skipPlacement
    
            _step = State(initialValue: resolvedInitialStep)
            _envName = State(initialValue: prefillEnvironmentName ?? "Personal")
            _projectName = State(initialValue: prefillProjectName ?? "Getting Started")
            _trackName = State(initialValue: prefillTrackName ?? "Read Me First")
        }
    
    private var popAnimation: Animation {
        reduceMotion
        ? .easeOut(duration: 0.01)
        : .spring(response: 0.28, dampingFraction: 0.86, blendDuration: 0.12)
    }

    private var fieldTransition: AnyTransition {
        let base = AnyTransition.opacity.combined(with: .scale(scale: 0.985, anchor: .topLeading))
        if reduceMotion { return base }
        return base.combined(with: .move(edge: .top))
    }

    private var currentBinding: Binding<String> {
        switch step {
        case .environment: return $envName
        case .project: return $projectName
        case .track: return $trackName
        }
    }

    private var suggestions: [String] {
        switch step {
        case .environment:
            return ["Personal", "Work", "School", "Studio", "Client", "Research"]
        case .project:
            return ["Getting Started", "Inbox", "Thesis", "Sample Library", "Commission", "Archive"]
        case .track:
            return ["Read Me First", "Build", "Writing", "Research", "Rehearsal", "Sessions"]
        }
    }

    private func choose(_ value: String) {
        withAnimation(popAnimation) { currentBinding.wrappedValue = value }
    }

    private var title: String {
        switch step {
        case .environment: return "Step 1 — Environment"
        case .project:     return "Step 2 — Project"
        case .track:       return "Step 3 — Topic"
        }
    }

    private var copy: String {
        switch step {
        case .environment: return "Environments are top-level spaces (e.g. Work, School, Client) which do not share context between each other."
        case .project:     return "Projects group related work inside an environment which may share context with each other."
        case .track:       return "Topics are lanes for parallel workstreams (e.g. Writing, Research, Build)."
        }
    }

    private var currentText: String {
        switch step {
        case .environment: return envName
        case .project:     return projectName
        case .track:       return trackName
        }
    }

    @ViewBuilder private var suggestedChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested")
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Colors.textSubtle)

            // wrap naturally (no custom layout structs)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(suggestions, id: \.self) { option in
                    OnboardingChip(
                        title: option,
                        isSelected: currentBinding.wrappedValue == option
                    ) { choose(option) }
                }
            }
        }
    }

    @ViewBuilder private var customNameField: some View {
        OnboardingSoftField(
            title: "Custom",
            placeholder: "Type a name (you can rename later)",
            text: currentBinding
        )
    }

    var body: some View {
        VStack(spacing: 14) {
            header

            Divider().overlay(StudioTheme.Colors.borderSoft.opacity(0.7))

            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(copy)
                    .font(.system(size: 12))
                    .foregroundStyle(StudioTheme.Colors.textSecondary)

                suggestedChips
                    .disabled(isWorking)
                    .transition(fieldTransition)

                customNameField
                    .disabled(isWorking)
                    .transition(fieldTransition)

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                        .padding(.top, 6)
                }
            }
            .id(step)
            .animation(popAnimation, value: step)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().overlay(StudioTheme.Colors.borderSoft.opacity(0.7))

            footer
                .padding(16)
        }
        .frame(width: 520)
        .background(AppTheme.Colors.surface0)
        .onAppear {
                    guard !didSeedFromPrefill else { return }
                    didSeedFromPrefill = true
                    if let s = prefillEnvironmentName { envName = s }
                    if let s = prefillProjectName { projectName = s }
                    if let s = prefillTrackName { trackName = s }
                    if skipPlacement { step = initialStep }
                }

    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle)
                    .font(.system(size: 14, weight: .semibold))
                Text(headerSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(StudioTheme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(16)
    }

    private var footer: some View {
        HStack {
            Button(skipTitle) { onSkip() }
                .buttonStyle(.plain)
                .foregroundStyle(StudioTheme.Colors.textSecondary)

            Spacer()

            Button("Back") { step = Step(rawValue: max(0, step.rawValue - 1))! }
                .disabled(isWorking || step == .environment || (skipPlacement && step == initialStep))

            Button(step == .track ? "Finish" : "Continue") {
                if step == .track { finish() }
                else { step = Step(rawValue: step.rawValue + 1)! }
            }
            .disabled(isWorking || currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func finish() {
        let env = envName.trimmingCharacters(in: .whitespacesAndNewlines)
        let proj = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let track = trackName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !env.isEmpty, !proj.isEmpty, !track.isEmpty else { return }

        isWorking = true
        errorText = nil

        Task {
            do {
                try await onFinish(env, proj, track)
                await MainActor.run { isWorking = false }
            } catch {
                await MainActor.run {
                    errorText = error.localizedDescription
                    isWorking = false
                }
            }
        }
    }
}
