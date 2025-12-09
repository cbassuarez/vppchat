import SwiftUI

// SessionView displays a transcript and composer for the selected session.
struct SessionView: View {
    @ObservedObject private var appViewModel: AppViewModel
    @StateObject private var viewModel: SessionViewModel

    private let session: Session

    init(session: Session, appViewModel: AppViewModel) {
        self.session = session
        self._appViewModel = ObservedObject(initialValue: appViewModel)
        _viewModel = StateObject(wrappedValue: SessionViewModel(
            sessionID: session.id,
            store: appViewModel.store,
            runtime: appViewModel.runtime,
            llmClient: appViewModel.llmClient
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            MessageListView(messages: messages)

            ComposerView(
                draft: $viewModel.draftText,
                modifiers: $viewModel.currentModifiers,
                sources: $viewModel.currentSources,
                runtime: appViewModel.runtime,
                sendAction: viewModel.send,
                tagSelection: viewModel.setTag,
                stepCycle: viewModel.stepCycle,
                resetCycle: viewModel.resetCycle
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .navigationTitle(session.name)
        .background(NoiseBackground())
    }

    private var messages: [Message] {
        appViewModel.store.session(id: session.id)?.messages ?? []
    }
}

#Preview {
    let appVM = AppViewModel()
    if let session = appVM.store.sessions.first {
        SessionView(session: session, appViewModel: appVM)
    }
}
