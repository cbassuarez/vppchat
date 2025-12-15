import Foundation
import Combine

@MainActor
final class SessionViewModel: ObservableObject {
    @Published var draftText: String = ""
    @Published var currentModifiers: VppModifiers = VppModifiers()
    @Published var currentSources: VppSources = .none

    private let runtime: VppRuntime

    init(runtime: VppRuntime) {
        self.runtime = runtime
    }

    func setTag(_ tag: VppTag) {
        runtime.setTag(tag)
    }

    func stepCycle() {
        runtime.nextInCycle()
    }

    func resetCycle() {
        runtime.newCycle()
    }
}
