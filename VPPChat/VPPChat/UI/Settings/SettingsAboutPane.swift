//
//  SettingsAboutPane.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//


import SwiftUI
#if os(macOS)
import AppKit
#endif

enum VPPProtocol {
    static let version: String = "1.4"
}

struct SettingsAboutPane: View {
    @State private var showNotices = false
    @State private var didCopy = false
    @State private var copyTask: Task<Void, Never>?
    @State private var noticesPresentationID = UUID()

    private let vppSiteURL = URL(string: "https://cbassuarez.github.io/viable-prompt-protocol/")!
    private let vppRepoURL = URL(string: "https://github.com/cbassuarez/viable-prompt-protocol")!
    private let vppchatRepoURL = URL(string: "https://github.com/cbassuarez/vppchat")!
    private let kofiURL = URL(string: "https://ko-fi.com/yourname")! // ← replace when ready

    private var bugReportURL: URL {
        var c = URLComponents(string: "https://github.com/cbassuarez/vppchat/issues/new")!
        let body = """
        **Describe the issue**
        (What happened, what you expected.)

        **Steps to reproduce**
        1.
        2.
        3.

        **Environment**
        - VPPChat: \(appVersionLine)
        - VPP Protocol: v\(VPPProtocol.version)
        - macOS:
        """
        c.queryItems = [
            .init(name: "title", value: "Bug: "),
            .init(name: "body", value: body)
        ]
        return c.url!
    }

    private var featureRequestURL: URL {
        var c = URLComponents(string: "https://github.com/cbassuarez/vppchat/issues/new")!
        let body = """
        **What should it do?**
        (Describe the behavior.)

        **Why?**
        (What workflow does this unlock?)

        **Notes / references**
        (Optional)
        """
        c.queryItems = [
            .init(name: "title", value: "Feature: "),
            .init(name: "body", value: body)
        ]
        return c.url!
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            identityCard

            linksCard

            supportCard

            HStack(spacing: 10) {
                Button {
                    showNotices = true
                    noticesPresentationID = UUID()
                } label: {
                    Text("Third-party notices")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(AppTheme.Colors.surface1)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                if didCopy {
                    savedPill("Copied")
                }
            }
        }
        .sheet(isPresented: $showNotices) {
            ThirdPartyNoticesSheet(
                vppRepoURL: vppRepoURL,
                vppchatRepoURL: vppchatRepoURL
            )
            .id(noticesPresentationID) // 👈 resets scroll/layout every open
            .frame(minWidth: 520, idealWidth: 560, maxWidth: 640,
                   minHeight: 420, idealHeight: 480, maxHeight: 560)
        }
    }

    // MARK: - Cards

    private var identityCard: some View {
        SettingsCard {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(StudioTheme.Colors.accentSoft)
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(StudioTheme.Colors.accent)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("VPPChat")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    Text("A local-first workspace and console shell for Viable Prompt Protocol loops — draft, critique, and finalize with tight structure and reproducible context.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()
                        .overlay(AppTheme.Colors.borderSoft.opacity(0.7))

                    VStack(alignment: .leading, spacing: 6) {
                        metaRow(label: "Version", value: appVersionLine)
                        metaRow(label: "VPP Protocol", value: "v\(VPPProtocol.version)")
                    }

                    HStack(spacing: 8) {
                        Button {
                            copyVersionInfo()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Copy version info")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(StudioTheme.Colors.accentSoft)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(StudioTheme.Colors.accent, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.top, 2)
                }

                Spacer()
            }
        }
    }

    private var linksCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                cardHeader(icon: "link", title: "Links")

                LinkRow(
                    title: "VPP Protocol",
                    subtitle: "Browse the site + docs",
                    url: vppSiteURL
                )
                
                LinkRow(
                    title: "VPP Repo",
                    subtitle: "Spec + tools + reference implementation",
                    url: vppRepoURL
                )

                LinkRow(
                    title: "VPPChat",
                    subtitle: "Shell app repo (issues, releases, roadmap)",
                    url: vppchatRepoURL
                )

                LinkRow(
                    title: "Report a bug",
                    subtitle: "Opens a pre-filled GitHub issue",
                    url: bugReportURL
                )

                LinkRow(
                    title: "Request a feature",
                    subtitle: "Opens a pre-filled GitHub issue",
                    url: featureRequestURL
                )
            }
        }
    }

    private var supportCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                cardHeader(icon: "heart.fill", title: "Support")

                Text("If this saves you time (or makes your loops sharper), support development.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                LinkRow(
                    title: "Ko-fi",
                    subtitle: "One-time or recurring support",
                    url: kofiURL
                )
            }
        }
    }

    // MARK: - UI helpers

    private func cardHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Spacer()
        }
        .padding(.bottom, 2)
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textSubtle)
                .frame(width: 92, alignment: .leading)

            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Colors.textSecondary)

            Spacer()
        }
    }

    private func savedPill(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(StudioTheme.Colors.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.Colors.surface1)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppTheme.Colors.borderSoft, lineWidth: 1))
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    private var appVersionLine: String {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String) ?? "0.0"
        let build = (info?["CFBundleVersion"] as? String) ?? "0"
        return "\(version) (\(build))"
    }

    private func copyVersionInfo() {
        let payload = """
        VPPChat \(appVersionLine)
        VPP Protocol v\(VPPProtocol.version)
        Repo: \(vppchatRepoURL.absoluteString)
        """

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payload, forType: .string)

        flashCopied()
    }

    private func flashCopied() {
        withAnimation(.easeOut(duration: 0.15)) {
            didCopy = true
        }
        copyTask?.cancel()
        copyTask = Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.15)) {
                    didCopy = false
                }
            }
        }
    }
}

// MARK: - Third-party notices

private struct ThirdPartyNoticesSheet: View {
    let vppRepoURL: URL
    let vppchatRepoURL: URL
    @Environment(\.dismiss) private var dismiss

    private let topID = "third_party_top"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ✅ Pinned header (doesn't scroll)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Third-party notices")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text("Licenses and terms for code, connectors, and dependencies.")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                }

                Divider()
                    .overlay(AppTheme.Colors.borderSoft.opacity(0.7))
            }
            .padding(16)
            .background(AppTheme.Colors.surface0)

            // ✅ Scrollable content (starts at top)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Color.clear
                            .frame(height: 0)
                            .id(topID)

                        SettingsCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Project licenses")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.Colors.textPrimary)

                                LinkRow(
                                    title: "VPP Protocol — LICENSE",
                                    subtitle: "See the repository license and notices",
                                    url: vppRepoURL.appendingPathComponent("blob/main/LICENSE")
                                )

                                LinkRow(
                                    title: "VPPChat — LICENSE",
                                    subtitle: "See the repository license and notices",
                                    url: vppchatRepoURL.appendingPathComponent("blob/main/LICENSE")
                                )
                            }
                        }

                        SettingsCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Connectors")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.Colors.textPrimary)

                                Text("If you enable provider connectors (e.g. OpenAI, Anthropic), you are responsible for complying with each provider’s terms, policies, and usage requirements. VPPChat is not affiliated with these providers.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                NoticeRow(title: "OpenAI connector", subtitle: "Terms/policies apply when enabled")
                                NoticeRow(title: "Anthropic connector", subtitle: "Terms/policies apply when enabled")
                            }
                        }

                        SettingsCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Platform dependencies")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.Colors.textPrimary)

                                Text("SwiftUI / Combine / AppKit are Apple frameworks; Apple’s platform licenses apply.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(16)
                }
                .background(AppTheme.Colors.surface0)
                .onAppear {
                    // 👇 ensures we start at the top *every time*
                    DispatchQueue.main.async {
                        proxy.scrollTo(topID, anchor: .top)
                    }
                }
            }
        }
        .background(AppTheme.Colors.surface0)
    }
}


// MARK: - Reusable chrome

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                .fill(AppTheme.Colors.surface0)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                        .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                )
        )
    }
}

private struct LinkRow: View {
    let title: String
    let subtitle: String
    let url: URL
    @State private var hovering = false

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textSubtle)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(hovering ? AppTheme.Colors.surface1 : AppTheme.Colors.surface0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.Colors.borderSoft.opacity(0.9), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            withAnimation(.easeOut(duration: 0.12)) {
                hovering = isHovering
            }
        }
    }
}

private struct NoticeRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.Colors.surface0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.Colors.borderSoft.opacity(0.9), lineWidth: 1)
        )
    }
}


private struct AboutRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
        )
    }
}

