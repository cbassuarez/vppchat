import Foundation
import SwiftUI
import Combine

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
        return "Use the real OpenAI client when configured."
    }
}

}

@MainActor
final class LLMConfigStore: ObservableObject {
static let shared = LLMConfigStore()
let objectWillChange = ObservableObjectPublisher()

// MARK: - Public state

@Published var apiKey: String {
    didSet {
        // ✅ Step B: apiKey is stored in Keychain (not UserDefaults)
        writeKeyToKeychain(apiKey)
        persistNonSecret()
        updateStatus()
    }
}

@Published var defaultModelID: String {
    didSet { persistNonSecret() }
}

@Published var defaultTemperature: Double {
    didSet { persistNonSecret() }
}

@Published var defaultContextStrategy: LLMContextStrategy {
    didSet { persistNonSecret() }
}

@Published private(set) var keyStatus: LLMKeyStatus = .notConfigured

@Published var clientMode: LLMClientMode {
    didSet { persistNonSecret() }
}

// MARK: - Storage models

/// v1 (legacy): apiKey lived in UserDefaults. Keep for migration only.
private struct StorageV1: Codable {
    var apiKey: String
    var defaultModelID: String
    var defaultTemperature: Double
    var defaultContextStrategy: String
    var clientMode: LLMClientMode
}

/// v2 (current): apiKey moved to Keychain; UserDefaults stores only non-secret fields.
private struct StorageV2: Codable {
    var defaultModelID: String
    var defaultTemperature: Double
    var defaultContextStrategy: String
    var clientMode: LLMClientMode
}

// MARK: - Keys

private let legacyStorageKeyV1 = "LLMConfigStore.Storage.v1"
private let storageKeyV2 = "LLMConfigStore.Storage.v2"

private let keychainService: String
private let keychainAccount = "openai_api_key"

// MARK: - Init

private init() {
    // Stable service id for Keychain entries
    keychainService = Bundle.main.bundleIdentifier ?? "VPPChat"

    // 1) Load apiKey from Keychain first
    let keyFromKeychain = KeychainStore.readString(service: keychainService, account: keychainAccount) ?? ""

    // 2) If keychain empty, migrate from legacy v1 UserDefaults (one-way)
    var resolvedKey = keyFromKeychain
    if resolvedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
       let data = UserDefaults.standard.data(forKey: legacyStorageKeyV1),
       let old = try? JSONDecoder().decode(StorageV1.self, from: data)
    {
        let trimmed = old.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let ok = KeychainStore.upsertString(trimmed, service: keychainService, account: keychainAccount)
            if ok {
                resolvedKey = trimmed
            } else {
                // don't block launch; surface error state
                keyStatus = .error("Failed to migrate key to Keychain.")
            }
        }
    }

    // 3) Load non-secret config from v2 UserDefaults, else fallback, else migrate v1 non-secrets
    if let data = UserDefaults.standard.data(forKey: storageKeyV2),
       let decoded = try? JSONDecoder().decode(StorageV2.self, from: data),
       LLMModelCatalog.presets.contains(where: { $0.id == decoded.defaultModelID }),
       let strategy = LLMContextStrategy(rawValue: decoded.defaultContextStrategy)
    {
        apiKey = resolvedKey
        defaultModelID = decoded.defaultModelID
        defaultTemperature = decoded.defaultTemperature
        defaultContextStrategy = strategy
        clientMode = decoded.clientMode
    } else if let data = UserDefaults.standard.data(forKey: legacyStorageKeyV1),
              let old = try? JSONDecoder().decode(StorageV1.self, from: data),
              LLMModelCatalog.presets.contains(where: { $0.id == old.defaultModelID }),
              let strategy = LLMContextStrategy(rawValue: old.defaultContextStrategy)
    {
        // v1 -> v2 migration of non-secret fields
        apiKey = resolvedKey
        defaultModelID = old.defaultModelID
        defaultTemperature = old.defaultTemperature
        defaultContextStrategy = strategy
        clientMode = old.clientMode
    } else {
        apiKey = resolvedKey
        defaultModelID = LLMModelCatalog.presets.first?.id ?? "gpt-4.1"
        defaultTemperature = 0.5
        defaultContextStrategy = .compact
        clientMode = .stub
    }

    // Ensure v2 is written immediately (and session defaults are synced)
    persistNonSecret()
    updateStatus()
}

func markKeyError(_ message: String?) {
    keyStatus = .error(message)
}

// MARK: - Private helpers

private func updateStatus() {
    let trimmedCount = apiKey.trimmingCharacters(in: .whitespacesAndNewlines).count
    print("LLMConfigStore apiKey len =", trimmedCount, "mode=", clientMode.rawValue)

    if trimmedCount == 0 {
        keyStatus = .notConfigured
    } else {
        // if we previously set .error(...) during migration, don't overwrite it
        if case .error = keyStatus { return }
        keyStatus = .configured
    }
}

private func persistNonSecret() {
    let storage = StorageV2(
        defaultModelID: defaultModelID,
        defaultTemperature: defaultTemperature,
        defaultContextStrategy: defaultContextStrategy.rawValue,
        clientMode: clientMode
    )

    SessionDefaults.defaultModelID = defaultModelID
    SessionDefaults.defaultTemperature = defaultTemperature
    SessionDefaults.defaultContextStrategy = defaultContextStrategy

    if let data = try? JSONEncoder().encode(storage) {
        UserDefaults.standard.set(data, forKey: storageKeyV2)
    }
}

private func writeKeyToKeychain(_ key: String) {
    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        _ = KeychainStore.delete(service: keychainService, account: keychainAccount)
        return
    }
    let ok = KeychainStore.upsertString(trimmed, service: keychainService, account: keychainAccount)
    if !ok {
        markKeyError("Failed to save key to Keychain.")
    }
}

}

