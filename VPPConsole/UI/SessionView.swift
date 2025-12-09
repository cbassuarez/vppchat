import SwiftUI

// SessionView displays a transcript and composer for the selected session.
struct SessionView: View {
    @ObservedObject private var appViewModel: AppViewModel
    @StateObject private var viewModel: SessionViewModel

    private let session: Session

    init(session: Session, appViewModel: AppViewModel) {
        self.session = session
        self._appViewModel = ObservedObject(initialValue: appViewModel)
        _viewModel = StateObject(wrappedValue: SessionViewModel(sessionID: session.id, store: appViewModel.store, runtime: appViewModel.runtime, llmClient: appViewModel.llmClient))
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.12, opacity: 0.6), Color.clear], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                MessageListView(messages: messages)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

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
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.thinMaterial)
            }
        }
        .navigationTitle(session.name)
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
