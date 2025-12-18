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
                        BlockCardView(
                                block: block,
                                isSelected: vm.selectedBlockID == block.id
                            )
                                .onTapGesture {
                                    vm.select(block: block)
                                }
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
            Text("Studio")
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
    @State private var assumptions: AssumptionsConfig = .none
    @State private var sourcesTable: [VppSourceRef] = []
    var body: some View {
        ComposerView(
            draft: $draft,
            modifiers: $modifiers,
            sources: $sources,
            sourcesTable: $sourcesTable,
            assumptions: $assumptions,
            runtime: vm.vppRuntime,
            requestStatus: vm.consoleSessions.first(where: { $0.id == vm.selectedBlockID })?.requestStatus ?? .idle,
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

        // 1) Resolve active conversation block in this scene
            let blocks = vm.store.blocks(in: scene)
            let convoBlocks = blocks.filter { $0.kind == .conversation }
        
            let selected: Block? = {
                guard let id = vm.selectedBlockID,
                      let b = vm.store.block(id: id),
                      b.sceneID == scene.id,
                      b.kind == .conversation
                else { return nil }
                return b
            }()
        
            let targetBlock: Block = {
                if let selected { return selected }
                if let canonical = convoBlocks.first(where: { $0.isCanonical }) {
                    vm.selectedBlockID = canonical.id
                    return canonical
                }
                if let last = convoBlocks.max(by: { $0.updatedAt < $1.updatedAt }) {
                    vm.selectedBlockID = last.id
                    return last
                }
                // Create a new conversation block ONCE (not per message)
                let title = deriveConversationTitle(from: trimmed, fallback: scene.title)
                let newBlock = Block(
                    sceneID: scene.id,
                    kind: .conversation,
                    title: title,
                    subtitle: nil,
                    messages: [],
                    documentText: nil,
                    isCanonical: false,
                    createdAt: .now,
                    updatedAt: .now
                )
                vm.store.add(block: newBlock)
                vm.selectedBlockID = newBlock.id
                return newBlock
            }()
        
            // 2) Build outgoing text (VPP header + body)
            var header = vm.vppRuntime.makeHeader(tag: vm.vppRuntime.state.currentTag, modifiers: modifiers)
            if let flag = assumptions.headerFlag { header += " \(flag)" }
            let composedText = header + "\n" + trimmed
        
            // 3) Send through the unified pipeline (this is what makes stub replies appear)
            let cfg = WorkspaceViewModel.LLMRequestConfig(
                modelID: vm.consoleModelID,
                temperature: vm.consoleTemperature,
                contextStrategy: vm.consoleContextStrategy
            )
        vm.selectedSessionID = targetBlock.id
        vm.touchConsoleSession(targetBlock.id)

            Task { @MainActor in
                await vm.sendPrompt(composedText, in: targetBlock.id, config: cfg, assumptions: assumptions)
            }
        
            draft = ""
            assumptions = .none
            sourcesTable = []
            sources = .none
    }
    private func deriveConversationTitle(from text: String, fallback: String) -> String {
        let firstLine = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? ""
        let cleaned = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return "Conversation · \(fallback)" }
        return String(cleaned.prefix(44))
    }
}

