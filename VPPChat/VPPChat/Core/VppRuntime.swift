import Foundation
import Combine

// VppRuntime encapsulates the current VPP state machine and helpers for synthesizing headers/footers.
final class VppRuntime: ObservableObject {
    @Published var state: VppState

    private let allowedNextTags: [VppTag: [VppTag]] = [
        .g: [.q, .o],
        .q: [.o, .c],
        .o: [.c, .o_f],
        .c: [.o_f, .g],
        .o_f: [.g, .q],
        .e: [.g],
        .e_o: [.g]
    ]

    init(state: VppState = .default) {
        self.state = state
    }

    func setTag(_ tag: VppTag) {
        if let allowed = allowedNextTags[state.currentTag], allowed.contains(tag) {
            state.currentTag = tag
        } else {
            state.currentTag = tag
        }
    }

    func nextInCycle() {
        state.cycleIndex = max(1, state.cycleIndex + 1)
    }

    func newCycle() {
        state.cycleIndex = 1
        state.currentTag = .g
    }

    func setAssumptions(_ assumptions: Int) {
        state.assumptions = max(0, assumptions)
    }

    func setLocus(_ locus: String?) {
        state.locus = locus
    }

    func makeHeader(tag: VppTag, modifiers: VppModifiers) -> String {
        var parts: [String] = ["!<\(tag.rawValue)>"]

        switch modifiers.correctness {
        case .correct:
            parts.append("--correct")
        case .incorrect:
            parts.append("--incorrect")
        case .neutral:
            break
        }

        switch modifiers.severity {
        case .minor:
            parts.append("--minor")
        case .major:
            parts.append("--major")
        case .none:
            break
        }

        if let echo = modifiers.echoTarget {
            parts.append("--<\(echo.rawValue)>")
        }

        return parts.joined(separator: " ")
    }

    func makeFooter(sources: VppSources) -> String {
        let tagComponent = "<\(state.currentTag.rawValue)_\(state.cycleIndex)>"
        var parts: [String] = [
            "Version=v1.4",
            "Tag=\(tagComponent)",
            "Sources=<\(sources.rawValue)>",
            "Assumptions=\(state.assumptions)",
            "Cycle=\(state.cycleIndex)/3"
        ]

        if let locus = state.locus, !locus.isEmpty {
            parts.append("Locus=\(locus)")
        }

        return "[" + parts.joined(separator: " | ") + "]"
    }

    struct VppValidationResult {
        var isValid: Bool
        var issues: [String]
    }

    func validateAssistantReply(_ text: String) -> VppValidationResult {
        var issues: [String] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

        if let first = lines.first {
            let firstString = String(first)
            if !(firstString.hasPrefix("<") || firstString.hasPrefix("!<")) {
                issues.append("Missing leading tag line")
            }
        } else {
            issues.append("Reply empty")
        }

        if let last = lines.last {
            let lastString = String(last)
            if !(lastString.hasPrefix("[") && lastString.contains("Version=") && lastString.contains("Tag=<")) {
                issues.append("Missing footer metadata")
            }
        } else {
            issues.append("No footer present")
        }

        return VppValidationResult(isValid: issues.isEmpty, issues: issues)
    }
}
