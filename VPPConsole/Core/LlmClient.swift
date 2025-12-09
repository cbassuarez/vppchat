import Foundation

protocol LlmClient {
    func sendMessage(
        header: String,
        body: String,
        completion: @escaping (Result<String, Error>) -> Void
    )
}

enum FakeLlmError: Error {
    case empty
}

final class FakeLlmClient: LlmClient {
    private let runtime: VppRuntime

    init(runtime: VppRuntime) {
        self.runtime = runtime
    }

    func sendMessage(header: String, body: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(.failure(FakeLlmError.empty))
            return
        }

        let response = "<o> (fake reply)\n\(body)\n\(runtime.makeFooter(sources: .none))"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            completion(.success(response))
        }
    }
}
