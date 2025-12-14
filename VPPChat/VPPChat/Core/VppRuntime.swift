import Foundation
import Combine

// VppRuntime encapsulates the current VPP state machine and helpers for synthesizing headers/footers.
final class VppRuntime: ObservableObject {
    @Published var state: VppState
    /// Tags that the runtime is allowed to use as echo targets with !<e> --<tag>.
    private let vppEchoableTags: Set<VppTag> = [.g, .q, .o, .c]

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

        var echo = modifiers.echoTarget

        // If we're in E and echo is nil or invalid, default it conservatively.
        if tag == .e {
            if let candidate = echo, vppEchoableTags.contains(candidate) {
                // ok
            } else {
                echo = .g
            }
        }

        if let echo, echo != .e, echo != .e_o {
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

extension VppRuntime {
    /// Ingests a footer line like:
    /// [Version=v1.4 | Tag=<c_3> | Sources=<web> | Assumptions=2 | Cycle=3/3 | Locus=SomeThread]
    /// and updates state.currentTag, state.cycleIndex, state.locus accordingly.
    func ingestFooterLine(_ footerLine: String) {
        var line = footerLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.hasPrefix("[") { line.removeFirst() }
        if line.hasSuffix("]") { line.removeLast() }

        let parts = line
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        for part in parts {
            // TAG=<c_3> → tag + cycle
            if part.hasPrefix("Tag=") {
                let raw = part.dropFirst("Tag=".count)
                    .trimmingCharacters(in: .whitespaces)

                // Expect something like "<c_3>"
                let trimmed = raw.trimmingCharacters(
                    in: CharacterSet(charactersIn: "<>")
                )

                // "c_3" → ["c", "3"]
                let components = trimmed.split(separator: "_", maxSplits: 1)
                if let tagToken = components.first,
                   let tag = VppTag(rawValue: String(tagToken)) {
                    state.currentTag = tag
                }

                if components.count == 2,
                   let idx = Int(components[1]) {
                    state.cycleIndex = max(1, idx)
                }
            }

            // Cycle=3/3 → cycleIndex
            else if part.hasPrefix("Cycle=") {
                let raw = part.dropFirst("Cycle=".count)
                    .trimmingCharacters(in: .whitespaces)
                // "3/3" → "3"
                if let firstComponent = raw.split(separator: "/").first,
                   let idx = Int(firstComponent) {
                    state.cycleIndex = max(1, idx)
                }
            }

            // Locus=FooBar → locus
            else if part.hasPrefix("Locus=") {
                let raw = part.dropFirst("Locus=".count)
                    .trimmingCharacters(in: .whitespaces)
                if raw.isEmpty || raw.lowercased() == "nil" {
                    setLocus(nil)
                } else {
                    setLocus(raw)
                }
            }
        }
    }
}

