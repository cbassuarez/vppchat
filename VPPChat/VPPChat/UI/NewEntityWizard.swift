//
//  NewEntityWizard.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import SwiftUI

enum NewEntityKind: String, CaseIterable, Identifiable, Hashable {
    case environment
    case project
    case track
    case scene

    var id: String { rawValue }

    var title: String {
        switch self {
        case .environment: return "Environment"
        case .project: return "Project"
        case .track: return "Topic"
        case .scene: return "Chat"
        }
    }

    var blurb: String {
        switch self {
        case .environment:
            return "Top-level. Context is not shared across environments."
        case .project:
            return "A workspace for a single body of work. Holds topics."
        case .track:
            return "A lane for related chats."
        case .scene:
            return "A single session. Holds messages, code blocks, and files (conversations/documents)."
        }
    }

    var icon: String {
        switch self {
        case .environment: return "globe"
        case .project: return "folder.fill"
        case .track: return "rectangle.3.offgrid.bubble.left.fill"
        case .scene: return "square.stack.3d.down.right.fill"
        }
    }
}

private enum NewEntityWizardStep: Int, CaseIterable {
    case kind = 0
    case placement = 1
    case name = 2
    case confirm = 3

    var title: String {
        switch self {
        case .kind: return "What are you creating?"
        case .placement: return "Where does it live?"
        case .name: return "Name"
        case .confirm: return "Review"
        }
    }
}

struct NewEntityWizard: View {
    @Namespace private var stepChipNS

    @State private var lastStepRaw: Int = 0
    @State private var stepIsForward: Bool = true

    @State private var hasAppeared: Bool = false

    
    @EnvironmentObject private var vm: WorkspaceViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: NewEntityWizardStep = .kind
    @State private var kind: NewEntityKind = .project

    @State private var envID: UUID?
    @State private var projectID: UUID?
    @State private var trackID: UUID?

    @State private var name: String = ""
    @State private var errorText: String?

    
    private var popAnimation: Animation {
        reduceMotion
        ? .easeOut(duration: 0.01)
        : .spring(response: 0.28, dampingFraction: 0.86, blendDuration: 0.12)
    }
    
    private struct LiquidPrimaryButtonStyle: ButtonStyle {
        var reduceMotion: Bool
        var fill: Color
        var stroke: Color
        var text: Color

        func makeBody(configuration: Configuration) -> some View {
            let pressed = configuration.isPressed

            return configuration.label
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(text)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                        .fill(fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                )
                .scaleEffect(pressed ? 0.972 : 1.0)
                .blur(radius: reduceMotion ? 0 : (pressed ? 0.7 : 0))
                .opacity(pressed ? 0.96 : 1.0)
                .animation(
                    reduceMotion
                    ? .easeOut(duration: 0.01)
                    : .spring(response: 0.36, dampingFraction: 0.86, blendDuration: 0.14),
                    value: pressed
                )
        }
    }

    private struct LuxStepModifier: ViewModifier {
        var x: CGFloat
        var blur: CGFloat
        var scale: CGFloat
        var opacity: CGFloat

        func body(content: Content) -> some View {
            content
                .opacity(opacity)
                .scaleEffect(scale)
                .offset(x: x)
                .blur(radius: blur)
        }
    }

    private func stepTransition(forward: Bool) -> AnyTransition {
        if reduceMotion { return .opacity }

        let x: CGFloat = forward ? 22 : -22
        return .asymmetric(
            insertion: .modifier(
                active: LuxStepModifier(x: x, blur: 12, scale: 0.985, opacity: 0),
                identity: LuxStepModifier(x: 0, blur: 0, scale: 1, opacity: 1)
            ),
            removal: .modifier(
                active: LuxStepModifier(x: -x, blur: 12, scale: 0.985, opacity: 0),
                identity: LuxStepModifier(x: 0, blur: 0, scale: 1, opacity: 1)
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AppTheme.Colors.borderSoft.opacity(0.7))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    stepHeader

                    ZStack(alignment: .topLeading) {
                        Group { stepBody }
                            .id(step.rawValue) // <- required so transitions actually fire
                            .transition(stepTransition(forward: stepIsForward))
                    }
                    .animation(popAnimation, value: step)

                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.red.opacity(0.9))
                            .padding(.top, 4)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(popAnimation, value: errorText != nil)

                    }

                }
                .padding(16)
            }

            Divider().overlay(AppTheme.Colors.borderSoft.opacity(0.7))
            buttons
        }
        .frame(minWidth: 560, minHeight: 460)
        .background(AppTheme.Colors.surface0)
        .onAppear {
            seedDefaultsFromViewModel()
            lastStepRaw = step.rawValue

            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.22)) {
                    hasAppeared = true
                }
            } else {
                hasAppeared = true
            }
        }
        .onChange(of: step) { newStep in
            stepIsForward = newStep.rawValue >= lastStepRaw
            lastStepRaw = newStep.rawValue
        }
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.985)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.square.on.square")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(StudioTheme.Colors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("New…")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("Environment ▸ Project ▸ Topic ▸ Chat")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Spacer()

            // Step chips
            HStack(spacing: 6) {
                ForEach(NewEntityWizardStep.allCases, id: \.rawValue) { s in
                    stepChip(s)
                }
            }
        }
        .padding(16)
    }

    private func stepChip(_ s: NewEntityWizardStep) -> some View {
        let isSelected = (s == step)

        return Text("\(s.rawValue + 1)")
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(StudioTheme.Colors.accentSoft)
                            .matchedGeometryEffect(id: "stepChipFill", in: stepChipNS)
                    } else {
                        Capsule().fill(AppTheme.Colors.surface1)
                    }
                }
            }
            .overlay(
                Capsule().stroke(
                    isSelected ? StudioTheme.Colors.accent : AppTheme.Colors.borderSoft,
                    lineWidth: isSelected ? 1.4 : 1
                )
            )
            .foregroundStyle(isSelected ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
            .animation(popAnimation, value: step)
    }


    // MARK: - Step content

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(step.title)
                .font(.system(size: 12, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Colors.textSubtle)

            Text(stepHelpText)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    private var stepHelpText: String {
        switch step {
        case .kind:
            return "Choose the hierarchical stratum you want to create."
        case .placement:
            return "Select the parent container. This defines where the new item appears in the library."
        case .name:
            return "Give it a human name. You can always rename later."
        case .confirm:
            return "Nothing is created until you press Create."
        }
    }

    @ViewBuilder
    private var stepBody: some View {
        switch step {
        case .kind:
            kindStep
        case .placement:
            placementStep
        case .name:
            nameStep
        case .confirm:
            confirmStep
        }
    }

    private var kindStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(NewEntityKind.allCases) { k in
                Button {
                    withAnimation(popAnimation) {
                        kind = k
                        // When kind changes, re-seed placement defaults so the next step isn’t invalid.
                        seedPlacementDefaults()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: k.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(k == kind ? StudioTheme.Colors.accent : AppTheme.Colors.textSecondary)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(k.title)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Text(k.blurb)
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }

                        Spacer()

                        Text(k.title.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(StudioTheme.Colors.surface1.opacity(0.8))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(StudioTheme.Colors.borderSoft.opacity(0.7), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(k == kind ? StudioTheme.Colors.accentSoft.opacity(0.8) : AppTheme.Colors.surface1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(k == kind ? StudioTheme.Colors.accent.opacity(0.5) : AppTheme.Colors.borderSoft,
                                    lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSubtle)
                Text("Chats contain messages or documents. Console “turns” are conversation blocks, stored inside chats or accessible from the Atlas tab.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var placementStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            if kind == .environment {
                placementCard(title: "Environment has no parent.", subtitle: "Press Next to continue.")
            }

            if kind == .project {
                placementPicker(
                    label: "Environment",
                    selection: $envID,
                    options: environmentOptions
                )
            }

            if kind == .track {
                placementPicker(
                    label: "Project",
                    selection: $projectID,
                    options: projectOptions
                )
            }

            if kind == .scene {
                placementPicker(
                    label: "Topic",
                    selection: $trackID,
                    options: trackOptions
                )
            }
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(kind.title) name")
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Colors.textSubtle)

            TextField(defaultNamePlaceholder, text: $name)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.Colors.surface1)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                        .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                )

            Text("Tip: short, semantic names auto-age better than numbered placeholders.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.top, 2)
        }
    }

    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            placementCard(
                title: "You are creating:",
                subtitle: "\(kind.title) · “\(nameToCreate)”"
            )

            placementCard(
                title: "Location:",
                subtitle: resolvedLocationString
            )

            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSubtle)
                Text("This action writes to the workspace database.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .padding(.top, 4)
        }
    }

    private func placementCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(12)
        .background(AppTheme.Colors.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
        )
    }

    private func placementPicker(
        label: String,
        selection: Binding<UUID?>,
        options: [(UUID, String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Colors.textSubtle)

            Picker(label, selection: selection) {
                ForEach(options, id: \.0) { (id, title) in
                    Text(title).tag(Optional(id))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.Colors.surface1)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                    .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
            )
        }
        
    }

    // MARK: - Buttons

    private var buttons: some View {
        HStack(spacing: 10) {
            Button("Cancel", role: .cancel) { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            Spacer()

            Button("Back") {
                withAnimation(popAnimation) { step = prev(step) }
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .disabled(step == .kind)

            Button(step == .confirm ? "Create" : "Next") {
                handlePrimary()
            }
            .buttonStyle(
                LiquidPrimaryButtonStyle(
                    reduceMotion: reduceMotion,
                    fill: StudioTheme.Colors.accentSoft,
                    stroke: StudioTheme.Colors.accent,
                    text: StudioTheme.Colors.textPrimary
                )
            )
            .disabled(!canProceedPrimary)
        }
        .padding(16)
        .background(AppTheme.Colors.surface0)
    }


    private func handlePrimary() {
        errorText = nil

        switch step {
        case .kind:
            withAnimation(popAnimation) { step = .placement }
        case .placement:
            withAnimation(popAnimation) { step = .name }
        case .name:
            withAnimation(popAnimation) { step = .confirm }
        case .confirm:
            createNow()
        }
    }

    private func createNow() {
        let trimmed = nameToCreate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorText = "Name can’t be empty."
            return
        }

        Task { @MainActor in
            do {
                let createdID = try vm.uiCreateViaWizard(
                    kind: kind,
                    envID: envID,
                    projectID: projectID,
                    trackID: trackID,
                    name: trimmed
                )
                // optional: keep selection in sync (vm does this), close
                _ = createdID
                dismiss()
            } catch {
                errorText = "Create failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Defaults + validation

    private func seedDefaultsFromViewModel() {
        kind = vm.newEntityWizardInitialKind ?? .project
        seedPlacementDefaults()
        seedNameDefault()
    }

    private func seedPlacementDefaults() {
        // Best-effort defaults from current selection, else first available.
        if envID == nil { envID = environmentOptions.first?.0 }
        if projectID == nil {
            projectID = vm.selectedProjectID ?? projectOptions.first?.0
        }
        if trackID == nil {
            trackID = vm.selectedTrackID ?? trackOptions.first?.0
        }

        // Ensure the required parent isn’t nil for the chosen kind.
        switch kind {
        case .environment:
            break
        case .project:
            if envID == nil { envID = environmentOptions.first?.0 }
        case .track:
            if projectID == nil { projectID = projectOptions.first?.0 }
        case .scene:
            if trackID == nil { trackID = trackOptions.first?.0 }
        }
    }

    private func seedNameDefault() {
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        name = kind.title
    }

    private var defaultNamePlaceholder: String {
        switch kind {
        case .environment: return "e.g. Environments"
        case .project: return "e.g. Constructions"
        case .track: return "e.g. Research"
        case .scene: return "e.g. Welcome"
        }
    }

    private var nameToCreate: String {
        let s = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? kind.title : s
    }

    private var canProceedPrimary: Bool {
        switch step {
        case .kind:
            return true
        case .placement:
            switch kind {
            case .environment: return true
            case .project: return envID != nil
            case .track: return projectID != nil
            case .scene: return trackID != nil
            }
        case .name:
            return !nameToCreate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .confirm:
            return true
        }
    }

    private func prev(_ s: NewEntityWizardStep) -> NewEntityWizardStep {
        NewEntityWizardStep(rawValue: max(0, s.rawValue - 1)) ?? .kind
    }

    private var resolvedLocationString: String {
        switch kind {
        case .environment:
            return "Top level (no parent)"
        case .project:
            return envID.flatMap { id in environmentOptions.first(where: { $0.0 == id })?.1 } ?? "(missing environment)"
        case .track:
            return projectID.flatMap { id in projectOptions.first(where: { $0.0 == id })?.1 } ?? "(missing project)"
        case .scene:
            return trackID.flatMap { id in trackOptions.first(where: { $0.0 == id })?.1 } ?? "(missing track)"
        }
    }

    // MARK: - Options

    private var environmentOptions: [(UUID, String)] {
        vm.libraryTree.map { ($0.id, $0.name) }
    }

    private var projectOptions: [(UUID, String)] {
        vm.libraryTree.flatMap { env in
            env.projects.map { p in
                (p.id, "\(env.name) ▸ \(p.name)")
            }
        }
    }

    private var trackOptions: [(UUID, String)] {
        vm.libraryTree.flatMap { env in
            env.projects.flatMap { p in
                p.tracks.map { t in
                    (t.id, "\(env.name) ▸ \(p.name) ▸ \(t.name)")
                }
            }
        }
    }
}
