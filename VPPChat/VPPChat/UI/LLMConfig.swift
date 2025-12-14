//
//  LLMConfig.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//


// LLMConfig.swift
// VPPChat

import Foundation
import SwiftUI

/// How much prior context to *intend* to send with each request.
/// (No truncation logic yet – this is config + UI only.)
enum LLMContextStrategy: String, Codable, CaseIterable, Identifiable {
    case compact
    case full

    var id: String { rawValue }

    var label: String {
        switch self {
        case .compact: return "Compact"
        case .full: return "Full"
        }
    }

    var hint: String {
        switch self {
        case .compact:
            return "Using last 8 turns (compact history)"
        case .full:
            return "Using full history"
        }
    }
}

/// Simple description of a model we expose in the UI.
struct LLMModelPreset: Identifiable, Hashable {
    let id: String          // e.g. "gpt-5.1-thinking"
    let label: String       // human-facing
    let detail: String      // short description / capability note
}

/// Central catalog of models + helpers to keep UI consistent.
enum LLMModelCatalog {
    static let presets: [LLMModelPreset] = [
        .init(
            id: "gpt-5.1-thinking",
            label: "GPT 5.1 Thinking",
            detail: "High-reasoning, slower, daily-driver for complex VPP loops."
        ),
        .init(
            id: "gpt-4.1-mini",
            label: "GPT 4.1 Mini",
            detail: "Lightweight, good for quick, low-stakes interactions."
        ),
        .init(
            id: "gpt-4o-mini",
            label: "GPT 4o Mini",
            detail: "Fast multimodal-ready baseline."
        )
    ]

    static let defaultModelID: String = presets.first?.id ?? "gpt-5.1-thinking"
    static let defaultTemperature: Double = 0.3

    static func preset(for id: String) -> LLMModelPreset {
        presets.first(where: { $0.id == id }) ?? presets[0]
    }
}

/// Keys + helpers for defaults. Used by Settings and by new-session creation.
enum SessionDefaults {
    private static let modelKey = "vppchat.defaultModelID"
    private static let temperatureKey = "vppchat.defaultTemperature"
    private static let contextKey = "vppchat.defaultContextStrategy"

    static var defaultModelID: String {
        get {
            UserDefaults.standard.string(forKey: modelKey)
            ?? LLMModelCatalog.defaultModelID
        }
        set {
            UserDefaults.standard.set(newValue, forKey: modelKey)
        }
    }

    static var defaultTemperature: Double {
        get {
            let stored = UserDefaults.standard.double(forKey: temperatureKey)
            // If never set, .double(forKey:) returns 0
            return stored == 0 ? LLMModelCatalog.defaultTemperature : stored
        }
        set {
            let clamped = min(1.0, max(0.0, newValue))
            UserDefaults.standard.set(clamped, forKey: temperatureKey)
        }
    }

    static var defaultContextStrategy: LLMContextStrategy {
        get {
            if let raw = UserDefaults.standard.string(forKey: contextKey),
               let strategy = LLMContextStrategy(rawValue: raw) {
                return strategy
            }
            return .compact
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: contextKey)
        }
    }
}
