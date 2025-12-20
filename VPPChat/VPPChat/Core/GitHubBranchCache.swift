//
//  GitHubBranchCache.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/20/25.
//


import Foundation

actor GitHubBranchCache {
  static let shared = GitHubBranchCache()

  struct Entry {
    var fetchedAt: Date
    var ttl: TimeInterval
    var defaultBranch: String
    var branches: [String]
    var isPrivate: Bool?
    var description: String?
  }

  private var store: [String: Entry] = [:] // key = "owner/name"

  func get(owner: String, repo: String) -> Entry? {
    let key = "\(owner.lowercased())/\(repo.lowercased())"
    guard let e = store[key] else { return nil }
    guard Date().timeIntervalSince(e.fetchedAt) <= e.ttl else {
      store[key] = nil
      return nil
    }
    return e
  }

  func set(owner: String, repo: String, entry: Entry) {
    let key = "\(owner.lowercased())/\(repo.lowercased())"
    store[key] = entry
  }
}
