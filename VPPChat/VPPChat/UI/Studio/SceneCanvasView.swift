import SwiftUI

struct SceneCanvasView: View {
    @EnvironmentObject private var vm: WorkspaceViewModel
    let scene: Scene

    var body: some View {
        VStack(spacing: 8) {
            vppRail

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.store.blocks(in: scene)) { block in
                        BlockCardView(block: block)
                    }
                }
                .padding(.top, 8)
            }

            StudioComposerView(scene: scene)
                .environmentObject(vm)
                .padding(.top, 8)
        }
        .padding(12)
        .background(
            AppTheme.Colors.surface1,
            in: RoundedRectangle(cornerRadius: StudioTheme.Radii.panel, style: .continuous)
        )
    }

    private var vppRail: some View {
        HStack(spacing: 4) {
            Text("VPP Rail")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(StudioTheme.Colors.textSubtle)
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

struct StudioComposerView: View {
    @EnvironmentObject private var vm: WorkspaceViewModel
    let scene: Scene

    @State private var draft: String = ""
    @State private var modifiers = VppModifiers()
    @State private var sources: VppSources = .none

    var body: some View {
        ComposerView(
            draft: $draft,
            modifiers: $modifiers,
            sources: $sources,
            runtime: vm.vppRuntime,
            sendAction: sendDraft,
            tagSelection: { tag in vm.vppRuntime.setTag(tag) },
            stepCycle: stepCycle,
            resetCycle: resetCycle
        )
    }

    // MARK: - VPP helpers

    private func stepCycle() {
        // Simple 1→2→3→1 loop for now
        let current = vm.vppRuntime.state.cycleIndex
        vm.vppRuntime.state.cycleIndex = current >= 3 ? 1 : current + 1
    }

    private func resetCycle() {
        vm.vppRuntime.state.cycleIndex = 1
    }

    // MARK: - Send

    private func sendDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let state = vm.vppRuntime.state

        let message = Message(
            id: UUID(),
            isUser: true,
            timestamp: .now,
            body: trimmed,
            tag: state.currentTag,
            cycleIndex: state.cycleIndex,
            assumptions: state.assumptions,
            sources: sources,
            locus: state.locus,
            isValidVpp: true,
            validationIssues: []
        )

        let subtitle = "<\(message.tag.rawValue)_\(message.cycleIndex)> · \(message.assumptions) assumptions"

        let newBlock = Block(
            sceneID: scene.id,
            kind: .conversation,
            title: "Interaction \(state.cycleIndex)",
            subtitle: subtitle,
            messages: [message],
            documentText: nil,
            isCanonical: false,
            createdAt: .now,
            updatedAt: .now
        )

        vm.store.add(block: newBlock)
        draft = ""
    }
}

