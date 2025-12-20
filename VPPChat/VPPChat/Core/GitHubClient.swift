//
//  GitHubRepoClient.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/20/25.
//


import Foundation

struct GitHubRepoInfo: Codable, Hashable {
  var defaultBranch: String
  var isPrivate: Bool?
  var description: String?

  enum CodingKeys: String, CodingKey {
    case defaultBranch = "default_branch"
    case isPrivate = "private"
    case description
  }
}

struct GitHubBranch: Codable, Hashable { var name: String }
struct GitHubCommit: Codable, Hashable {
  struct Inner: Codable, Hashable { var sha: String }
  var sha: String
}

final class GitHubClient {
  static let shared = GitHubClient()

  enum ClientError: Error { case badURL, badStatus(Int) }

  /// Public calls can omit token. Token required for private repos + higher rate limits.
  func fetchRepoInfo(owner: String, repo: String, token: String?) async throws -> GitHubRepoInfo {
    guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)") else { throw ClientError.badURL }
    var req = URLRequest(url: url)
    req.httpMethod = "GET"
    req.timeoutInterval = 12
    req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    if let token, !token.isEmpty {
      req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    let (data, resp) = try await URLSession.shared.data(for: req)
    guard let http = resp as? HTTPURLResponse else { throw ClientError.badStatus(-1) }
    guard (200..<300).contains(http.statusCode) else { throw ClientError.badStatus(http.statusCode) }
    return try JSONDecoder().decode(GitHubRepoInfo.self, from: data)
  }

  func fetchBranches(owner: String, repo: String, token: String?) async throws -> [String] {
    // NOTE: for now: single page (per_page=100). Add pagination later if you need it.
    guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/branches?per_page=100") else { throw ClientError.badURL }
    var req = URLRequest(url: url)
    req.httpMethod = "GET"
    req.timeoutInterval = 12
    req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    if let token, !token.isEmpty {
      req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    let (data, resp) = try await URLSession.shared.data(for: req)
    guard let http = resp as? HTTPURLResponse else { throw ClientError.badStatus(-1) }
    guard (200..<300).contains(http.statusCode) else { throw ClientError.badStatus(http.statusCode) }
    let decoded = try JSONDecoder().decode([GitHubBranch].self, from: data)
    return decoded.map(\.name)
  }

  func fetchLatestCommitSHA(owner: String, repo: String, branch: String, token: String?) async throws -> String {
    guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/commits/\(branch)") else { throw ClientError.badURL }
    var req = URLRequest(url: url)
    req.httpMethod = "GET"
    req.timeoutInterval = 12
    req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    if let token, !token.isEmpty {
      req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    let (data, resp) = try await URLSession.shared.data(for: req)
    guard let http = resp as? HTTPURLResponse else { throw ClientError.badStatus(-1) }
    guard (200..<300).contains(http.statusCode) else { throw ClientError.badStatus(http.statusCode) }
    let decoded = try JSONDecoder().decode(GitHubCommit.self, from: data)
    return decoded.sha
  }

  /// Convenience: use cache when possible.
  func getRepoMeta(owner: String, repo: String, token: String?, ttl: TimeInterval = 20 * 60) async throws -> GitHubBranchCache.Entry {
    if let hit = await GitHubBranchCache.shared.get(owner: owner, repo: repo) { return hit }

    let info = try await fetchRepoInfo(owner: owner, repo: repo, token: token)
    let branches = (try? await fetchBranches(owner: owner, repo: repo, token: token)) ?? []
    let entry = GitHubBranchCache.Entry(
      fetchedAt: Date(),
      ttl: ttl,
             defaultBranch: info.defaultBranch,
             branches: branches.sorted(),
             isPrivate: info.isPrivate,
             description: info.description
    )
    await GitHubBranchCache.shared.set(owner: owner, repo: repo, entry: entry)
    return entry
  }
}
