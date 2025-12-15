//
//  AssumptionsConfig.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//


import Foundation

/// Per-message assumptions configuration (composer-only).
enum AssumptionsConfig: Equatable, Codable {
    case none
    case zero
    case custom(items: [String])

    var headerFlag: String? {
        switch self {
        case .none:
            return nil
        case .zero:
            return "--assumptions=0"
        case .custom(let items):
            let n = items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .count
            return "--assumptions=\(max(1, n))"
        }
    }

    var customCount: Int {
        switch self {
        case .custom(let items):
            let n = items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .count
            return max(1, n)
        default:
            return 0
        }
    }

    var chipLabelOnePlus: String {
        switch self {
        case .custom:
            return "1+ · \(customCount)"
        default:
            return "1+"
        }
    }

    var customItems: [String] {
        switch self {
        case .custom(let items):
            return items
        default:
            return []
        }
    }

    /// Optional: a structured block you can attach to your *system scaffolding*
    /// (recommended) or to the user message body (if you prefer visible).
    var assumptionsAttachmentText: String? {
        switch self {
        case .custom(let items):
            let cleaned = items
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !cleaned.isEmpty else { return nil }

            var lines: [String] = []
            lines.append("Assumptions (user-provided):")
            for (i, a) in cleaned.enumerated() {
                lines.append("\(i + 1). \(a)")
            }
            return lines.joined(separator: "\n")

        default:
            return nil
        }
    }
}
