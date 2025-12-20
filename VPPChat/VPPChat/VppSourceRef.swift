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
  var id: String
  var kind: VppSourceKind
  var ref: String

  // ✅ new
  var displayName: String? = nil
  var securityBookmark: Data? = nil
    // ✅ structured repo ref (only when kind == .repo)
      var repo: RepoRef? = nil

  init(
    id: String,
    kind: VppSourceKind,
    ref: String,
    displayName: String? = nil,
    securityBookmark: Data? = nil,
    repo: RepoRef? = nil
    ) {
    self.id = id
    self.kind = kind
    self.ref = ref
    self.displayName = displayName
    self.securityBookmark = securityBookmark
        self.repo = repo
  }
}

extension VppSourceRef {
  /// Deterministic label for the LLM + UI.
  var canonicalLabel: String {
    switch kind {
    case .repo:
      if let repo { return repo.canonicalLabel }
      // fallback for legacy rows (still better than raw github.com noise)
        return displayName.nilIfEmpty ?? ref
    default:
        return displayName.nilIfEmpty ?? ref
    }
  }

  /// Best-effort migration: if this is a legacy `.repo` row, infer RepoRef once.
  mutating func normalizeLegacyRepoIfNeeded() {
    guard kind == .repo, repo == nil else { return }
    if let parsed = RepoRef.parseLoose(ref) {
      repo = parsed
      // keep ref canonical for backwards tooling
      ref = parsed.canonicalOwnerRepo
    }
  }
}

// MARK: - Repo helpers (local, MAS-safe)



private extension Optional where Wrapped == String {
  var nilIfEmpty: String? {
    guard let s = self?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
    return s
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
                // Display-only: keep raw `ref` hidden.
                out.append("| id | kind | label |")
                out.append("| --- | --- | --- |")
        for var r in rows {
                            r.normalizeLegacyRepoIfNeeded()
                            out.append("| \(r.id) | \(r.kind.rawValue) | \(r.canonicalLabel) |")
                        }
                return out.joined(separator: "\n")
    }
}
