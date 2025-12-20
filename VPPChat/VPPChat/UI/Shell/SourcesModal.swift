//
//  SourcesModal.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Kind popover plumbing (Atlas-style)

private struct SourceKindAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>],
                       nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct SourcesModal: View {
    @AppStorage("WebRetrievalPolicy") private var webPolicyRaw: String = WebRetrievalPolicy.auto.rawValue
    private var policy: WebRetrievalPolicy { WebRetrievalPolicy(rawValue: webPolicyRaw) ?? .auto }
    @Binding var sources: VppSources
    @Binding var sourcesTable: [VppSourceRef]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var draftTable: [VppSourceRef] = []
    
    // repo editor
    @State private var editingRepoIndex: Int? = nil
    
    @State private var isPickingFile: Bool = false
    @State private var filePickTargetID: String? = nil

    // which row's kind dropdown is open
    @State private var activeKindPickerID: String? = nil

    // optional: focus the ref field for a specific source id
    @FocusState private var focusedSourceID: String?

    private var popAnimation: Animation {
        reduceMotion
        ? .easeOut(duration: 0.01)
        : .spring(response: 0.28, dampingFraction: 0.86, blendDuration: 0.12)
    }

    private var rowTransition: AnyTransition {
        let base = AnyTransition.opacity.combined(with: .scale(scale: 0.985, anchor: .topLeading))
        if reduceMotion { return base }
        return base.combined(with: .move(edge: .top))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().overlay(AppTheme.Colors.borderSoft.opacity(0.7))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("""
                    Web access (Off/On) controls whether the assistant is allowed to fetch NEW pages beyond your attachments for this send.
                    Attachments are explicit references you provide (files/URLs/repos/ssh). Attachments are included even when Web access is Off.
                    When Web access is On, behavior follows Settings → Web Retrieval Policy: \(policy == .always ? "Always" : "Auto").
                    “No sources” means: Web access Off + 0 attachments.
                    """)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.textSecondary)


                    sourcesSection
                    policyPicker
                    footerHint
                }
                .padding(16)
            }

            Divider().overlay(AppTheme.Colors.borderSoft.opacity(0.7))

            buttons
        }
        .frame(minWidth: 560, minHeight: 440)
        .background(AppTheme.Colors.surface0)
        .onAppear { seedFromBinding() }
        .fileImporter(
          isPresented: $isPickingFile,
          allowedContentTypes: [.item],
          allowsMultipleSelection: false
        ) { result in
          guard let id = filePickTargetID else { return }
          filePickTargetID = nil

          switch result {
          case .success(let urls):
            guard let url = urls.first else { return }
            if let i = draftTable.firstIndex(where: { $0.id == id }) {
                draftTable[i].kind = .file
                draftTable[i].displayName = url.lastPathComponent
                draftTable[i].ref = url.path // optional: keep as fallback / debug

                do {
                  let bm = try url.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                  )
                  draftTable[i].securityBookmark = bm
                } catch {
                  // If bookmark creation fails, keep ref as fallback
                  draftTable[i].securityBookmark = nil
                }
              focusedSourceID = id
            }
          case .failure:
            break
          }
        }


        // Atlas-style anchored kind dropdown
        .overlayPreferenceValue(SourceKindAnchorKey.self) { anchors in
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    if let id = activeKindPickerID,
                       let anchor = anchors[id] {
                        let rect = proxy[anchor]
                        kindPickerPopover(for: id)
                            .fixedSize(horizontal: true, vertical: true)
                            .frame(maxWidth: 280, alignment: .leading)
                            .offset(x: rect.minX, y: rect.maxY + 8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .sheet(isPresented: Binding(
                  get: { editingRepoIndex != nil },
                  set: { if !$0 { editingRepoIndex = nil } }
                )) {
                  if let idx = editingRepoIndex, draftTable.indices.contains(idx) {
                    RepoAttachSheet(source: $draftTable[idx])
                  } else {
                    EmptyView()
                  }
                }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(StudioTheme.Colors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Sources")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("Applied to this send only.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(16)
    }


    // MARK: - Sources section

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Attachments")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.Colors.textSubtle)

                Spacer()

                Text("\(draftTable.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            if draftTable.isEmpty {
                emptyState
                    .transition(rowTransition)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(draftTable, id: \.id) { ref in
                        sourceRow(refID: ref.id)
                            .transition(rowTransition)
                    }
                }
                .animation(popAnimation, value: draftTable.count)
            }

            addRow
        }
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textSubtle)

            VStack(alignment: .leading, spacing: 2) {
                Text("No sources attached.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("Add a file, URL, repo, or other reference to include with this send.")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.Colors.surface1)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
        )
    }

    private func sourceRow(refID: String) -> some View {
        let ref = binding(for: refID)

        return HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Source \(indexLabel(for: refID))")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.Colors.textSubtle)

                HStack(spacing: 8) {
                    kindChip(ref: ref)

                    if ref.wrappedValue.kind == .file {
                      HStack(spacing: 8) {
                        TextField("Choose a file…", text: Binding(
                          get: { ref.wrappedValue.ref },
                          set: { ref.wrappedValue.ref = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .font(AppTheme.Typography.mono(12))
                        .disableAutocorrection(true)
                        .padding(10)
                        .background(AppTheme.Colors.surface1)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous))
                        .overlay(
                          RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                            .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                        )
                        .focused($focusedSourceID, equals: refID)

                        Button("Browse…") {
                          beginPickFile(for: refID)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(AppTheme.Colors.surface1)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous))
                        .overlay(
                          RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                            .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                        )
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                      }
                    } else if ref.wrappedValue.kind == .repo {
                                          let idx = draftTable.firstIndex(where: { $0.id == refID }) ?? -1
                                          HStack(spacing: 10) {
                                            Text(ref.wrappedValue.canonicalLabel)
                                              .font(AppTheme.Typography.mono(12))
                                              .lineLimit(1)
                                              .truncationMode(.middle)
                                              .foregroundStyle(AppTheme.Colors.textPrimary)
                    
                                            Spacer(minLength: 8)
                    
                                            Button("Configure…") {
                                              guard idx >= 0 else { return }
                                              draftTable[idx].normalizeLegacyRepoIfNeeded()
                                              editingRepoIndex = idx
                                            }
                                            .buttonStyle(.plain)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .background(AppTheme.Colors.surface1)
                                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous))
                                            .overlay(
                                              RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                                                .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                                            )
                                            .foregroundStyle(AppTheme.Colors.textSecondary)
                                          }
                                        } else {
                                          TextField(placeholder(for: ref.wrappedValue.kind), text: Binding(
                                            get: { ref.wrappedValue.ref },
                                            set: { ref.wrappedValue.ref = $0 }
                                          ))
                                          .textFieldStyle(.plain)
                                          .font(AppTheme.Typography.mono(12))
                                          .disableAutocorrection(true)
                                          .padding(10)
                                          .background(AppTheme.Colors.surface1)
                                          .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous))
                                          .overlay(
                                            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                                              .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                                          )
                                          .focused($focusedSourceID, equals: refID)
                                        }

                }

                Text(hint(for: ref.wrappedValue.kind))
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
                        .frame(maxWidth: .infinity, alignment: .leading)
            
                        Button {
                deleteSource(id: refID)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            .help("Remove")
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.Colors.surface1)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
        )
    }
    
    private func beginPickFile(for id: String) {
      filePickTargetID = id
      isPickingFile = true
    }

    private func kindLabel(_ kind: VppSourceKind) -> String {
      switch kind {
      case .web:  return "URL"
      case .repo: return "REPO"
      case .file: return "FILE"
      case .ssh:  return "SSH (buggy)"
      }
    }

    private func kindChip(ref: Binding<VppSourceRef>) -> some View {
        let id = ref.wrappedValue.id

        return Button {
            withAnimation(.easeOut(duration: 0.18)) {
                activeKindPickerID = (activeKindPickerID == id ? nil : id)
            }
        } label: {
            HStack(spacing: 6) {
                Text(kindLabel(ref.wrappedValue.kind))
                    .font(.system(size: 10, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppTheme.Colors.surface1)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                    .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
            )
            .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .buttonStyle(ScalePressButtonStyle())
        .anchorPreference(key: SourceKindAnchorKey.self, value: .bounds) { anchor in
            [id: anchor]
        }
    }

    private func kindPickerPopover(for id: String) -> some View {
        PopoverChrome {
            HStack {
                Text("Kind")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(StudioTheme.Colors.textSecondary)
                Spacer()
                Button("Done") {
                    activeKindPickerID = nil
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(StudioTheme.Colors.textSecondary)
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)

            Divider()

            ForEach(VppSourceKind.allCases, id: \.self) { kind in
                let isSelected = (draftTable.first(where: { $0.id == id })?.kind == kind)

                Button {
                    if let i = draftTable.firstIndex(where: { $0.id == id }) {
                        draftTable[i].kind = kind
                    }
                    activeKindPickerID = nil
                } label: {
                    HStack {
                        Text(kind == .web ? "URL" : kind.rawValue)
                            .font(.system(size: 12))
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
        }
    }

    private var addRow: some View {
        Button {
            withAnimation(popAnimation) {
                let id = nextTokenID()
                draftTable.append(VppSourceRef(id: id, kind: .web, ref: ""))
                focusedSourceID = id
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("Add source")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(StudioTheme.Colors.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(StudioTheme.Colors.accentSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(StudioTheme.Colors.accent.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private var footerHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSubtle)

            Text("These become a temporary attachment at send-time.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(.top, 2)
    }
// MARK: Policy picker
    private var policyPicker: some View {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Web retrieval")
            .font(.system(size: 11, weight: .semibold))
            .textCase(.uppercase)
            .foregroundStyle(AppTheme.Colors.textSubtle)
          Spacer()
        }

        Picker("", selection: Binding(
          get: { WebRetrievalPolicy(rawValue: webPolicyRaw) ?? .auto },
          set: { webPolicyRaw = $0.rawValue }
        )) {
          Text("Auto").tag(WebRetrievalPolicy.auto)
          Text("Always").tag(WebRetrievalPolicy.always)
        }
        .pickerStyle(.segmented)

        Text("Auto fetches only when needed. Always prefers fetching whenever web retrieval is available.")
          .font(.system(size: 11))
          .foregroundStyle(AppTheme.Colors.textSecondary)
      }
    }


    // MARK: - Buttons

    private var buttons: some View {
        HStack(spacing: 10) {
            Button("Clear") {
                withAnimation(popAnimation) {
                    sourcesTable = []
                    sources = .web
                }
                dismiss()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                    .fill(AppTheme.Colors.surface1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                    .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
            )
            .foregroundStyle(AppTheme.Colors.textSecondary)

            Spacer()

            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            Button {
                sourcesTable = draftTable
                sources = .web
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(StudioTheme.Colors.textPrimary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                    .fill(StudioTheme.Colors.accentSoft)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                    .stroke(StudioTheme.Colors.accent, lineWidth: 1)
            )
        }
        .padding(16)
        .background(AppTheme.Colors.surface0)
    }

    // MARK: - State plumbing

    private func seedFromBinding() {
        draftTable = sourcesTable
    }

    private func binding(for id: String) -> Binding<VppSourceRef> {
        Binding(
            get: {
                draftTable.first(where: { $0.id == id })
                ?? VppSourceRef(id: id, kind: .web, ref: "")
            },
            set: { newValue in
                if let i = draftTable.firstIndex(where: { $0.id == id }) {
                    draftTable[i] = newValue
                }
            }
        )
    }

    private func deleteSource(id: String) {
        withAnimation(popAnimation) {
            draftTable.removeAll { $0.id == id }
            if focusedSourceID == id { focusedSourceID = nil }
            if activeKindPickerID == id { activeKindPickerID = nil }
        }
    }

    private func indexLabel(for id: String) -> Int {
        (draftTable.firstIndex(where: { $0.id == id }) ?? 0) + 1
    }

    private func nextTokenID() -> String {
        let used = Set(draftTable.map(\.id))
        var n = 1
        while used.contains("s\(n)") { n += 1 }
        return "s\(n)"
    }

    private func placeholder(for kind: VppSourceKind) -> String {
        switch kind {
        case .web:  return "https://example.com/article"
        case .repo: return "owner/repo (use Configure…)"
        case .file: return "Choose a file…"
        case .ssh:  return "user@host:/path or ssh://user@host/path"
        }
    }

    private func hint(for kind: VppSourceKind) -> String {
        switch kind {
        case .web:  return "Example: https://wikipedia.org/wiki/Spinoza"
        case .repo: return "Example: cbassuarez/praetorius@auto"
        case .file: return "Example: /Users/seb/Desktop/notes.md"
        case .ssh:  return "Example: seb@10.0.0.12:/var/log/app.log"
        }
    }
}

// MARK: - Popover chrome (matches Atlas feel)

private struct PopoverChrome<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(12)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.Colors.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 16, x: 6, y: 12)
        .transition(
            reduceMotion
            ? .opacity
            : .scale(scale: 0.96, anchor: .topLeading).combined(with: .opacity)
        )
    }
}

private struct ScalePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
