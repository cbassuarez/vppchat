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
            .thinMaterial,
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Compose")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(StudioTheme.Colors.textPrimary)

            TextEditor(text: $draft)
                .font(.system(size: 13))
                .foregroundStyle(StudioTheme.Colors.textPrimary)
                .padding(10)
                .frame(minHeight: 90)
                .background(
                    RoundedRectangle(cornerRadius: StudioTheme.Radii.card, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: StudioTheme.Radii.card, style: .continuous)
                                .stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
                        )
                )

            HStack {
                Spacer()
                Button(action: sendDraft) {
                    Label("Send", systemImage: "paperplane.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(StudioTheme.Colors.accent)
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.Radii.card, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: StudioTheme.Radii.card, style: .continuous)
                        .stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
                )
        )
    }

    private func sendDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let message = Message(
            id: UUID(),
            isUser: true,
            timestamp: .now,
            body: trimmed,
            tag: vm.vppRuntime.state.currentTag,
            cycleIndex: vm.vppRuntime.state.cycleIndex,
            assumptions: vm.vppRuntime.state.assumptions,
            sources: .none,
            locus: vm.vppRuntime.state.locus,
            isValidVpp: true,
            validationIssues: []
        )

        let newBlock = Block(
            sceneID: scene.id,
            kind: .conversation,
            title: "New Interaction",
            subtitle: "<\(message.tag.rawValue)_\(message.cycleIndex)>",
            messages: [message],
            createdAt: .now,
            updatedAt: .now
        )

        vm.store.add(block: newBlock)
        draft = ""
    }
}
