//
//  AdaptiveLLMClient.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import Foundation

/// Routes requests to Stub vs Live depending on LLMConfigStore at *send time*.
final class AdaptiveLLMClient: LLMClient {
    private let config: LLMConfigStore
    private let stub: LLMClient
    private let live: OpenAIResponsesClient

    init(
        config: LLMConfigStore = .shared,
        urlSession: URLSession = .shared
    ) {
        self.config = config
        self.stub = StubLLMClient()
        self.live = OpenAIResponsesClient(
            apiKeyProvider: { [config] in config.apiKey },
            urlSession: urlSession
        )
    }

    func send(_ request: LLMRequest) async throws -> LLMResponse {
        switch config.clientMode {
        case .stub:
            return try await stub.send(request)
        case .live:
            return try await live.send(request)
        }
    }
}
