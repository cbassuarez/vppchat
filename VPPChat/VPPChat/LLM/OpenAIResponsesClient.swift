import Foundation

final class OpenAIResponsesClient: LLMClient {
    private let apiKeyProvider: @Sendable () -> String
    private let urlSession: URLSession

    init(
        apiKeyProvider: @escaping @Sendable () -> String,
        urlSession: URLSession = .shared
    ) {
        self.apiKeyProvider = apiKeyProvider
        self.urlSession = urlSession
    }

    func send(_ request: LLMRequest) async throws -> LLMResponse {
        let apiKey = apiKeyProvider()
        print("OPENAI key len =", apiKey.count)
        if apiKey.isEmpty {
            throw NSError(domain: "OpenAIResponsesClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing OPENAI_API_KEY"])
        }
        

        let url = URL(string: "https://api.openai.com/v1/responses")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let inputMessages: [[String: Any]] = request.messages.map { m in
            let roleStr: String = {
                switch m.role {
                case .system: return "system"
                case .user: return "user"
                case .assistant: return "assistant"
                }
            }()

            let contentType = (roleStr == "assistant") ? "output_text" : "input_text"

            return [
                "role": roleStr,
                "content": [
                    ["type": contentType, "text": m.content]
                ]
            ]
        }

        let resolved = resolveModel(request.modelID)
        print("OPENAI model =", resolved.model, "alias =", request.modelID, "reasoning_effort =", resolved.reasoningEffort ?? "nil")
        var body: [String: Any] = [
          "model": resolved.model,
          "input": inputMessages
        ]

        // reasoning.effort (nested)
        if let effort = resolved.reasoningEffort {
          body["reasoning"] = ["effort": effort]  // per docs  [oai_citation:1‡OpenAI Platform](https://platform.openai.com/docs/guides/gpt-5)
        }

        // temperature only if supported
        if resolved.supportsTemperature {
          body["temperature"] = request.temperature
        }

        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw NSError(domain: "OpenAIResponsesClient", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])
        }
        print("HTTP status =", http.statusCode)
        print("HTTP bytes  =", data.count)
        
        guard (200..<300).contains(http.statusCode) else {
            let msg = Self.extractErrorMessage(from: data) ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "OpenAIResponsesClient", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let text = try Self.extractOutputText(from: data)
        return LLMResponse(text: text)
    }

    private static func extractOutputText(from data: Data) throws -> String {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "OpenAIResponsesClient", code: 3, userInfo: [NSLocalizedDescriptionKey: "Bad JSON"])
        }

        // Prefer direct field if present
        if let outputText = obj["output_text"] as? String, !outputText.isEmpty {
            return outputText
        }

        // Otherwise parse output[].content[] where type == "output_text"
        guard let output = obj["output"] as? [[String: Any]] else { return "" }

        var parts: [String] = []
        for item in output {
            guard let content = item["content"] as? [[String: Any]] else { continue }
            for c in content {
                if (c["type"] as? String) == "output_text",
                   let t = c["text"] as? String {
                    parts.append(t)
                }
            }
        }
        return parts.joined()
    }

    private static func extractErrorMessage(from data: Data) -> String? {
        guard
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let err = obj["error"] as? [String: Any],
            let msg = err["message"] as? String
        else { return nil }
        return msg
    }

    private struct ResolvedModel {
      let model: String
      let reasoningEffort: String?
      let supportsTemperature: Bool
    }

    private func resolveModel(_ requested: String) -> ResolvedModel {
      if requested.hasSuffix("-thinking") {
        let base = String(requested.dropLast("-thinking".count))
        // treat as “high reasoning”
        let supportsTemp = !base.hasPrefix("gpt-5")
        return .init(model: base, reasoningEffort: "high", supportsTemperature: supportsTemp)
      }

      let supportsTemp = !requested.hasPrefix("gpt-5")
      return .init(model: requested, reasoningEffort: nil, supportsTemperature: supportsTemp)
    }

}
