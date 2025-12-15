//
//  VppSourceRef.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import Foundation

enum VppSourceKind: String, Codable, Hashable, CaseIterable {
    case file      // local file name/path (or logical file id)
    case web       // domain/page/url or wildcard pattern like *.openai.com/*
    case repo      // git remote (https or ssh), owner/repo, etc.
    case ssh       // non-git ssh endpoints (or explicit ssh remote)
}

/// A compact, per-message addressable source reference (for footer tokenization).
/// Example IDs: "s1", "s2" (stable *within* a message).
struct VppSourceRef: Identifiable, Codable, Hashable {
    var id: String          // "s1"
    var kind: VppSourceKind // file/web/repo/ssh
    var ref: String         // user-entered locator/pattern

    init(id: String, kind: VppSourceKind, ref: String) {
        self.id = id
        self.kind = kind
        self.ref = ref
    }
}

extension Array where Element == VppSourceRef {
    /// Stable display ordering by numeric suffix of "sN" when possible.
    func sortedByToken() -> [VppSourceRef] {
        self.sorted { a, b in
            func n(_ s: String) -> Int? {
                guard s.hasPrefix("s") else { return nil }
                return Int(s.dropFirst())
            }
            let na = n(a.id)
            let nb = n(b.id)
            if let na, let nb, na != nb { return na < nb }
            return a.id < b.id
        }
    }

    func asVppSourcesTableMarkdown() -> String {
        let rows = self.sortedByToken()
        guard !rows.isEmpty else { return "" }
        var out: [String] = []
        out.append("Sources:")
        out.append("| id | kind | ref |")
        out.append("| --- | --- | --- |")
        for r in rows {
            // keep it simple + parseable (no escaping complexity)
            out.append("| \(r.id) | \(r.kind.rawValue) | \(r.ref) |")
        }
        return out.joined(separator: "\n")
    }
}
