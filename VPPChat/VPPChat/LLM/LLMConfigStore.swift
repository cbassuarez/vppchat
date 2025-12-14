import Foundation
import SwiftUI

enum LLMKeyStatus: Equatable {
    case notConfigured
    case configured
    case error(String?)
}

enum LLMClientMode: String, CaseIterable, Identifiable, Codable {
    case stub
    case live

    var id: String { rawValue }

    var label: String {
        switch self {
        case .stub: return "Local stub"
        case .live: return "Real model"
        }
    }

    var hint: String {
        switch self {
        case .stub:
            return "Use a local fake model for testing UI states."
        case .live:
            return "Use the real OpenAI client when configured (Sprint 7+)."
        }
    }
}

@MainActor
final class LLMConfigStore: ObservableObject {
    static let shared = LLMConfigStore()

    @Published var apiKey: String {
        didSet {
            persist()
            updateStatus()
        }
    }

    @Published var defaultModelID: String {
        didSet {
            persist()
        }
    }

    @Published var defaultTemperature: Double {
        didSet {
            persist()
        }
    }

    @Published var defaultContextStrategy: LLMContextStrategy {
        didSet {
            persist()
        }
    }

    @Published private(set) var keyStatus: LLMKeyStatus = .notConfigured

    @Published var clientMode: LLMClientMode {
        didSet {
            persist()
        }
    }

    private struct Storage: Codable {
        var apiKey: String
        var defaultModelID: String
        var defaultTemperature: Double
        var defaultContextStrategy: String
        var clientMode: LLMClientMode
    }

    private let storageKey = "LLMConfigStore.Storage.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(Storage.self, from: data),
           LLMModelCatalog.presets.contains(where: { $0.id == decoded.defaultModelID }),
           let strategy = LLMContextStrategy(rawValue: decoded.defaultContextStrategy) {
            apiKey = decoded.apiKey
            defaultModelID = decoded.defaultModelID
            defaultTemperature = decoded.defaultTemperature
            defaultContextStrategy = strategy
            clientMode = decoded.clientMode
        } else {
            apiKey = ""
            defaultModelID = LLMModelCatalog.presets.first?.id ?? "gpt-4.1"
            defaultTemperature = 0.5
            defaultContextStrategy = .compact
            clientMode = .stub
        }

        persist()
        updateStatus()
    }

    func markKeyError(_ message: String?) {
        keyStatus = .error(message)
    }

    // MARK: - Private helpers

    private func updateStatus() {
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            keyStatus = .notConfigured
        } else {
            keyStatus = .configured
        }
    }

    private func persist() {
        let storage = Storage(
            apiKey: apiKey,
            defaultModelID: defaultModelID,
            defaultTemperature: defaultTemperature,
            defaultContextStrategy: defaultContextStrategy.rawValue,
            clientMode: clientMode
        )

        SessionDefaults.defaultModelID = defaultModelID
        SessionDefaults.defaultTemperature = defaultTemperature
        SessionDefaults.defaultContextStrategy = defaultContextStrategy

        if let data = try? JSONEncoder().encode(storage) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
