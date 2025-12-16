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

final class FakeLlmClient: LlmClient, LLMClient {
    private let runtime: VppRuntime

    init(runtime: VppRuntime) {
        self.runtime = runtime
    }
    func send(_ request: LLMRequest) async throws -> LLMResponse {
        let body = request.messages.last(where: { $0.role == .user })?.content ?? ""
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FakeLlmError.empty
        }

        // mimic your existing fake reply format (incl. footer) so VPP ingestion keeps working
        let response = "<o> (fake reply)\n\(body)\n\(runtime.makeFooter(sources: .none))"
        try await Task.sleep(nanoseconds: 400_000_000)
        return LLMResponse(text: response)
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
