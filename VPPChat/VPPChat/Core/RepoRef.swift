//
//  RepoRef.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/20/25.
//


import Foundation

struct RepoRef: Codable, Hashable {
  enum Provider: String, Codable, Hashable { case github }

  var provider: Provider = .github
  var owner: String
  var name: String
  var branch: String?   // nil => Auto/default
  var path: String?     // optional scope ("/src", "README.md", etc.)
  var isPrivate: Bool?  // hint from API

  var canonicalOwnerRepo: String { "\(owner)/\(name)" }

  var canonicalLabel: String {
    let b = (branch?.isEmpty == false) ? branch! : "auto"
    let p = (path?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? ":" + normalizePath(path!) : ""
    return "\(owner)/\(name)@\(b)\(p)"
  }

  func normalizePath(_ raw: String) -> String {
    var p = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if p.isEmpty { return "" }
    if !p.hasPrefix("/") { p = "/" + p }
    // don’t force trailing slash; user may give README.md
    return p
  }

  static func parseLoose(_ input: String) -> RepoRef? {
    let s = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !s.isEmpty else { return nil }

    // owner/repo
    if s.range(of: #"^[A-Za-z0-9][A-Za-z0-9-]{0,38}\/[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil {
      let parts = s.split(separator: "/")
      return RepoRef(owner: String(parts[0]), name: String(parts[1]), branch: nil, path: nil, isPrivate: nil)
    }

    // https://github.com/owner/repo(/tree/branch(/path...))?
    if let url = URL(string: s), url.host?.contains("github.com") == true {
      let comps = url.path.split(separator: "/").map(String.init)
      guard comps.count >= 2 else { return nil }
      let owner = comps[0], repo = comps[1].replacingOccurrences(of: ".git", with: "")

      var branch: String? = nil
      var path: String? = nil
      if comps.count >= 4, comps[2] == "tree" {
        branch = comps[3]
        if comps.count > 4 {
          path = "/" + comps.dropFirst(4).joined(separator: "/")
        }
      }
      return RepoRef(owner: owner, name: repo, branch: branch, path: path, isPrivate: nil)
    }

    // git@github.com:owner/repo(.git)
    if s.hasPrefix("git@github.com:") {
      let tail = s.replacingOccurrences(of: "git@github.com:", with: "")
        let clean = tail.hasSuffix(".git") ? String(tail.dropLast(4)) : tail
      let parts = clean.split(separator: "/")
      guard parts.count >= 2 else { return nil }
      return RepoRef(owner: String(parts[0]), name: String(parts[1]), branch: nil, path: nil, isPrivate: nil)
    }

    return nil
  }
}
