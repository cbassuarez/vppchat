//
//  RepoAttachSheet.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/20/25.
//


import SwiftUI

struct RepoAttachSheet: View {
  @Environment(\.dismiss) private var dismiss

  @Binding var source: VppSourceRef

  // optional token storage (minimal; upgrade to Keychain later)
  @AppStorage("VPPChatGitHubToken") private var githubToken: String = ""

  @State private var paste: String = ""
  @State private var owner: String = ""
  @State private var repo: String = ""
  @State private var selectedBranch: String? = nil   // nil = auto
  @State private var path: String = ""
  @State private var useToken: Bool = false

  @State private var isLoading: Bool = false
  @State private var branches: [String] = []
  @State private var defaultBranch: String = ""
  @State private var repoDescription: String = ""
  @State private var latestShortSHA: String = ""
  @State private var errorText: String = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Attach Repo").font(.title2).bold()

      // Paste-anything
      TextField("Paste GitHub URL, git@…, or owner/repo", text: $paste)
        .textFieldStyle(.roundedBorder)
        .onSubmit { applyPaste() }

      Form {
        Picker("Provider", selection: .constant("GitHub")) {
          Text("GitHub").tag("GitHub")
        }
        .disabled(true)

        TextField("Owner", text: $owner)
          .vppNoAutoCaps()
          .onChange(of: owner) { _ in Task { await refreshIfPossible() } }

        TextField("Repo", text: $repo)
          .vppNoAutoCaps()
          .onChange(of: repo) { _ in Task { await refreshIfPossible() } }

        Picker("Branch", selection: branchBinding) {
          Text("Auto (default branch)").tag("__AUTO__")
          if !branches.isEmpty {
            Divider()
          }
          ForEach(branches, id: \.self) { b in
            Text(b).tag(b)
          }
        }

        TextField("Path scope (optional)", text: $path)
          .vppNoAutoCaps()

        Toggle("Use GitHub token (optional)", isOn: $useToken)
        if useToken {
          SecureField("Token", text: $githubToken)
          Text("Scopes: none for public; repo for private repos.").font(.footnote).foregroundStyle(.secondary)
        }
      }

      if !errorText.isEmpty {
        Text(errorText).foregroundStyle(.red).font(.footnote)
      }

      HStack(spacing: 10) {
        Button("Validate & Preview") { Task { await validateAndPreview() } }
          .disabled(!isOwnerRepoValid || isLoading)

        Spacer()

        Button("Attach") {
          attachNow()
          dismiss()
        }
        .buttonStyle(.borderedProminent)
        .disabled(!isOwnerRepoValid)
      }

      Divider()

      VStack(alignment: .leading, spacing: 6) {
        Text("Preview").font(.headline)
        Text("Default branch: \(defaultBranch.isEmpty ? "—" : defaultBranch)")
        if !repoDescription.isEmpty { Text(repoDescription).foregroundStyle(.secondary) }
        if !latestShortSHA.isEmpty { Text("Latest commit: \(latestShortSHA)") }
        Text(fetchPlanText).font(.footnote).foregroundStyle(.secondary)
      }
    }
    .padding(16)
    .onAppear { seedFromExisting() }
    .frame(minWidth: 520, minHeight: 560)
  }

  private var branchBinding: Binding<String> {
    Binding<String>(
      get: {
        (selectedBranch?.isEmpty == false) ? selectedBranch! : "__AUTO__"
      },
      set: { newValue in
        selectedBranch = (newValue == "__AUTO__") ? nil : newValue
      }
    )
  }

  private var isOwnerRepoValid: Bool {
    owner.range(of: #"^[A-Za-z0-9][A-Za-z0-9-]{0,38}$"#, options: .regularExpression) != nil
    && repo.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil
  }

  private var fetchPlanText: String {
    let scope = path.trimmingCharacters(in: .whitespacesAndNewlines)
    let scopeLine = scope.isEmpty ? "Repo root + README" : "Scoped to: \(scope)"
    return """
Plan: resolve branch (explicit or default), fetch README, list contents (\(scopeLine)), then deep-excerpt a few signal files + up to 3 source files.
"""
  }

  private func seedFromExisting() {
    var s = source
    s.normalizeLegacyRepoIfNeeded()
    if let r = s.repo {
      owner = r.owner
      repo = r.name
      selectedBranch = r.branch
      path = r.path ?? ""
    } else if let r = RepoRef.parseLoose(source.ref) {
      owner = r.owner
      repo = r.name
      selectedBranch = r.branch
      path = r.path ?? ""
    }
    Task { await refreshIfPossible() }
  }

  private func applyPaste() {
    guard let r = RepoRef.parseLoose(paste) else { return }
    owner = r.owner
    repo = r.name
    selectedBranch = r.branch
    path = r.path ?? ""
    paste = ""
    Task { await refreshIfPossible() }
  }

  @MainActor
  private func refreshIfPossible() async {
    guard isOwnerRepoValid else { return }
    errorText = ""
    isLoading = true
    defer { isLoading = false }
    do {
      let entry = try await GitHubClient.shared.getRepoMeta(
        owner: owner,
        repo: repo,
        token: useToken ? githubToken : nil
      )
      defaultBranch = entry.defaultBranch
      branches = [entry.defaultBranch] + entry.branches.filter { $0 != entry.defaultBranch }
      repoDescription = entry.description ?? ""
    } catch {
      // offline/failure behavior: keep Auto and allow manual branch entry by typing into paste/url (later: add Advanced disclosure)
      errorText = "Couldn’t load branches (you can still attach with Auto)."
      branches = []
      defaultBranch = ""
    }
  }

  @MainActor
  private func validateAndPreview() async {
    guard isOwnerRepoValid else { return }
    await refreshIfPossible()

    // Best-effort latest commit
    let branchToUse = (selectedBranch?.isEmpty == false) ? selectedBranch! : (defaultBranch.isEmpty ? "main" : defaultBranch)
    do {
      let sha = try await GitHubClient.shared.fetchLatestCommitSHA(
        owner: owner,
        repo: repo,
        branch: branchToUse,
        token: useToken ? githubToken : nil
      )
      latestShortSHA = String(sha.prefix(7))
    } catch {
      latestShortSHA = ""
    }
  }

  private func attachNow() {
    let cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
    let r = RepoRef(
      owner: owner,
      name: repo,
      branch: (selectedBranch?.isEmpty == false) ? selectedBranch : nil,
      path: cleanPath.isEmpty ? nil : cleanPath,
      isPrivate: nil
    )
    source.kind = .repo
    source.repo = r
    source.ref = r.canonicalOwnerRepo     // legacy-safe
    source.displayName = nil              // keep deterministic label generation
  }
}
// MARK: - Cross-platform text helpers (macOS-safe)
private extension View {
  @ViewBuilder func vppNoAutoCaps() -> some View {
    #if os(iOS)
    self.textInputAutocapitalization(.never)
    #else
    self
    #endif
  }
}
