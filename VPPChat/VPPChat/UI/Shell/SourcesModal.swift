//
//  SourcesModal.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//

import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

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
    @State private var attachmentCache: [String: FileAttachment] = [:]
    
    // repo editor
    @State private var editingRepoIndex: Int? = nil
    
    @State private var isPickingFile: Bool = false
    @State private var filePickTargetID: String? = nil
    @State private var previewTarget: FilePreviewTarget? = nil
    @State private var showUnreadableWarning: Bool = false
    @State private var isDropTargeted: Bool = false

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
        .onChange(of: attachmentCache) { _ in
            if unreadableAttachmentCount == 0 {
                showUnreadableWarning = false
            }
        }
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
                  ingestPickedFile(id: id, url: url, bookmark: bm)
                } catch {
                  draftTable[i].securityBookmark = nil
                  setNeedsAccessPlaceholder(id: id, path: url.path)
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
        .sheet(item: $previewTarget) { target in
          if let attachment = attachmentCache[target.id] {
            FilePreviewSheet(
              attachment: attachment,
              onRefresh: { refreshAttachment(id: target.id, force: true) }
            )
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
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleFileDrop(providers: providers)
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
                      fileRowContent(refID: refID, ref: ref)
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
        .onAppear {
            ensureAttachment(for: ref.wrappedValue)
        }
    }
    
    private func fileRowContent(refID: String, ref: Binding<VppSourceRef>) -> some View {
      let attachment = attachmentCache[refID]
      let displayName = attachment?.identity.displayName ?? ref.wrappedValue.displayName ?? fallbackFileName(from: ref.wrappedValue.ref)
      let secondary = attachment.map(fileSecondaryText) ?? "Size unknown · \(fileExtensionLabel(from: displayName))"
      let tooltip = attachment?.resolvedURLPath ?? ref.wrappedValue.ref

      return VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 2) {
            Text(displayName)
              .font(AppTheme.Typography.mono(12))
              .foregroundStyle(AppTheme.Colors.textPrimary)
              .lineLimit(1)
              .truncationMode(.middle)
              .help(tooltip)

            Text(secondary)
              .font(.system(size: 11))
              .foregroundStyle(AppTheme.Colors.textSecondary)
          }

          Spacer()

          HStack(spacing: 8) {
            statusPill(for: attachment?.status)

            Button("Preview…") {
              previewTarget = FilePreviewTarget(id: refID)
            }
            .buttonStyle(.plain)
            .disabled(attachment?.extraction == nil)
            .foregroundStyle(AppTheme.Colors.textSecondary)

            Button("Refresh") {
              refreshAttachment(id: refID, force: true)
            }
            .buttonStyle(.plain)
            .disabled(ref.wrappedValue.securityBookmark == nil)
            .foregroundStyle(AppTheme.Colors.textSecondary)
          }
        }

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
          .onChange(of: ref.wrappedValue.ref) { newValue in
            handleFilePathEdit(id: refID, newValue: newValue)
          }

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
      }
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
        VStack(spacing: 10) {
          if showUnreadableWarning {
            unreadableWarningStrip
              .transition(.opacity)
          }

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
                  handleDone()
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
        }
        .padding(16)
        .background(AppTheme.Colors.surface0)
    }

    // MARK: - State plumbing

    private func seedFromBinding() {
        draftTable = sourcesTable
        seedAttachmentCache()
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
            attachmentCache.removeValue(forKey: id)
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

    private var unreadableWarningStrip: some View {
      let count = unreadableAttachmentCount
      return HStack(spacing: 10) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Color.orange)

        Text("\(count) attachments may not be readable. They will be skipped unless fixed.")
          .font(.system(size: 11))
          .foregroundStyle(AppTheme.Colors.textSecondary)

        Spacer()

        Button("Review") {
          showUnreadableWarning = false
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(AppTheme.Colors.textSecondary)

        Button("Proceed") {
          applyAndDismiss()
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(StudioTheme.Colors.accent)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(AppTheme.Colors.surface1)
      .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
          .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
      )
    }

    private var unreadableAttachmentCount: Int {
      attachmentCache.values.filter { attachment in
        switch attachment.status {
        case .needsAccess, .error:
          return true
        default:
          return false
        }
      }.count
    }

    private func handleDone() {
      if unreadableAttachmentCount > 0 {
        showUnreadableWarning = true
        return
      }
      applyAndDismiss()
    }

    private func applyAndDismiss() {
      sourcesTable = draftTable
      sources = .web
      dismiss()
    }

    private func seedAttachmentCache() {
      let fileIDs = Set(draftTable.filter { $0.kind == .file }.map(\.id))
      attachmentCache = attachmentCache.filter { fileIDs.contains($0.key) }
      for ref in draftTable {
        ensureAttachment(for: ref)
      }
    }

    private func ensureAttachment(for ref: VppSourceRef) {
      guard ref.kind == .file else {
        attachmentCache.removeValue(forKey: ref.id)
        return
      }

      if let existing = attachmentCache[ref.id] {
        var updated = existing
        let displayName = ref.displayName ?? fallbackFileName(from: ref.ref)
        if updated.identity.displayName != displayName {
          updated.identity.displayName = displayName
        }
        attachmentCache[ref.id] = updated
        return
      }

      let displayName = ref.displayName ?? fallbackFileName(from: ref.ref)
      let identity = FileIdentity(
        displayName: displayName,
        ext: URL(fileURLWithPath: displayName).pathExtension.lowercased(),
        contentType: nil,
        byteSize: nil,
        modifiedAt: nil
      )
      let status: AttachmentStatus = ref.securityBookmark == nil ? .needsAccess : .picked
      let attachment = FileAttachment(
        sourceID: ref.id,
        bookmark: ref.securityBookmark ?? Data(),
        resolvedURLPath: ref.ref.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : ref.ref,
        identity: identity,
        status: status,
        extraction: nil
      )
      attachmentCache[ref.id] = attachment

      if let bookmark = ref.securityBookmark {
        Task {
          await probeAndExtract(id: ref.id, bookmark: bookmark, force: false)
        }
      }
    }

    private func ingestPickedFile(id: String, url: URL, bookmark: Data) {
      let identity = FileIdentity(
        displayName: url.lastPathComponent,
        ext: url.pathExtension.lowercased(),
        contentType: nil,
        byteSize: nil,
        modifiedAt: nil
      )
      let attachment = FileAttachment(
        sourceID: id,
        bookmark: bookmark,
        resolvedURLPath: url.path,
        identity: identity,
        status: .picked,
        extraction: nil
      )
      attachmentCache[id] = attachment

      Task {
        await probeAndExtract(id: id, bookmark: bookmark, force: true)
      }
    }

    private func refreshAttachment(id: String, force: Bool) {
      guard let ref = draftTable.first(where: { $0.id == id }) else { return }
      guard let bookmark = ref.securityBookmark else {
        setNeedsAccessPlaceholder(id: id, path: ref.ref)
        return
      }
      Task {
        await probeAndExtract(id: id, bookmark: bookmark, force: force)
      }
    }

    private func probeAndExtract(id: String, bookmark: Data, force: Bool) async {
      await MainActor.run {
        updateStatus(id: id, status: .reading(progress: 0.2, phase: "Probing"))
      }

      var isStale = false
      do {
        let url = try URL(
          resolvingBookmarkData: bookmark,
          options: [.withSecurityScope],
          relativeTo: nil,
          bookmarkDataIsStale: &isStale
        )

        guard url.startAccessingSecurityScopedResource() else {
          await MainActor.run {
            updateStatus(id: id, status: .needsAccess)
          }
          return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let identity = try SourcesResolver.statFile(url: url)
        let previous = attachmentCache[id]
        let changed = previous.map { $0.identity != identity } ?? false

        if changed, !force, previous?.extraction != nil {
          await MainActor.run {
            updateAttachment(id: id, identity: identity, resolvedPath: url.path)
            updateStatus(id: id, status: .changed)
          }
          return
        }

        let budget = perFileBudget()
        let extraction = try SourcesResolver.extractFileExcerpt(
          url: url,
          source: draftTable.first(where: { $0.id == id }) ?? VppSourceRef(id: id, kind: .file, ref: url.path),
          identity: identity,
          budget: budget
        ) { progress in
          Task { @MainActor in
            updateStatus(id: id, status: .reading(progress: 0.2 + progress * 0.6, phase: "Extracting"))
          }
        }

        await MainActor.run {
          updateStatus(id: id, status: .reading(progress: 1.0, phase: "Finalizing"))
          updateAttachment(id: id, identity: identity, resolvedPath: url.path, extraction: extraction)
          updateStatus(id: id, status: .ready)
        }
      } catch {
        await MainActor.run {
          updateStatus(id: id, status: .error(message: error.localizedDescription))
        }
      }
    }

    private func updateAttachment(
      id: String,
      identity: FileIdentity,
      resolvedPath: String?,
      extraction: FileExtractionResult? = nil
    ) {
      guard var attachment = attachmentCache[id] else { return }
      attachment.identity = identity
      attachment.resolvedURLPath = resolvedPath
      if let extraction {
        attachment.extraction = extraction
      }
      attachmentCache[id] = attachment
    }

    private func updateStatus(id: String, status: AttachmentStatus) {
      guard var attachment = attachmentCache[id] else { return }
      attachment.status = status
      attachmentCache[id] = attachment
    }

    private func setNeedsAccessPlaceholder(id: String, path: String) {
      let displayName = fallbackFileName(from: path)
      let identity = FileIdentity(
        displayName: displayName,
        ext: URL(fileURLWithPath: displayName).pathExtension.lowercased(),
        contentType: nil,
        byteSize: nil,
        modifiedAt: nil
      )
      let attachment = FileAttachment(
        sourceID: id,
        bookmark: Data(),
        resolvedURLPath: path,
        identity: identity,
        status: .needsAccess,
        extraction: nil
      )
      attachmentCache[id] = attachment
    }

    private func handleFilePathEdit(id: String, newValue: String) {
      guard looksLikeAbsolutePath(newValue) else { return }
      guard let idx = draftTable.firstIndex(where: { $0.id == id }) else { return }
      guard draftTable[idx].securityBookmark == nil else { return }

      draftTable[idx].displayName = URL(fileURLWithPath: newValue).lastPathComponent
      setNeedsAccessPlaceholder(id: id, path: newValue)
    }

    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
      for provider in providers {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
          provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL? = {
              if let url = item as? URL { return url }
              if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
              return nil
            }()
            guard let url else { return }
            DispatchQueue.main.async { addDroppedFile(url: url) }
          }
          return true
        }
      }
      return false
    }

    private func addDroppedFile(url: URL) {
      let id = nextTokenID()
      var ref = VppSourceRef(id: id, kind: .file, ref: url.path, displayName: url.lastPathComponent)
      do {
        let bookmark = try url.bookmarkData(
          options: [.withSecurityScope],
          includingResourceValuesForKeys: nil,
          relativeTo: nil
        )
        ref.securityBookmark = bookmark
        withAnimation(popAnimation) {
          draftTable.append(ref)
        }
        ingestPickedFile(id: id, url: url, bookmark: bookmark)
      } catch {
        withAnimation(popAnimation) {
          draftTable.append(ref)
        }
        setNeedsAccessPlaceholder(id: id, path: url.path)
      }
      focusedSourceID = id
    }

    private func perFileBudget() -> Int {
      let maxCharsPerSource = 20_000
      let maxTotalChars = 60_000
      let fileCount = draftTable.filter { $0.kind == .file }.count
      guard fileCount > 0 else { return maxCharsPerSource }
      let reserved = Double(maxTotalChars) * 0.8
      let perFile = Int(floor(reserved / Double(fileCount)))
      return min(maxCharsPerSource, max(1, perFile))
    }

    private func fileSecondaryText(_ attachment: FileAttachment) -> String {
      let sizeText = attachment.identity.byteSize.map { formatByteCount($0) } ?? "Size unknown"
      let extText = fileExtensionLabel(from: attachment.identity.displayName)
      let modifiedText = relativeModifiedLabel(attachment.identity.modifiedAt)
      return "\(sizeText) · \(extText) · \(modifiedText)"
    }

    private func fileExtensionLabel(from name: String) -> String {
      let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
      return ext.isEmpty ? "unknown type" : ".\(ext)"
    }

    private func fallbackFileName(from path: String) -> String {
      let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty { return "Untitled" }
      return URL(fileURLWithPath: trimmed).lastPathComponent
    }

    private func relativeModifiedLabel(_ date: Date?) -> String {
      guard let date else { return "Modified unknown" }
      let formatter = RelativeDateTimeFormatter()
      formatter.unitsStyle = .abbreviated
      return "Modified \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    private func formatByteCount(_ bytes: Int64) -> String {
      let formatter = ByteCountFormatter()
      formatter.countStyle = .file
      return formatter.string(fromByteCount: bytes)
    }

    private func looksLikeAbsolutePath(_ path: String) -> Bool {
      let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.hasPrefix("/") || trimmed.hasPrefix("~")
    }

    @ViewBuilder
    private func statusPill(for status: AttachmentStatus?) -> some View {
      let resolvedStatus = status ?? .picked
      let label: String
      let tint: Color
      let showsProgress: Bool

      switch resolvedStatus {
      case .picked:
        label = "Picked"
        tint = AppTheme.Colors.textSecondary
        showsProgress = false
      case .needsAccess:
        label = "Needs access"
        tint = Color.orange
        showsProgress = false
      case .reading(let progress, let phase):
        let percent = Int((progress * 100).rounded())
        label = "\(phase) \(percent)%"
        tint = StudioTheme.Colors.accent
        showsProgress = true
      case .ready:
        label = "Ready"
        tint = Color.green
        showsProgress = false
      case .changed:
        label = "Changed"
        tint = Color.orange
        showsProgress = false
      case .error:
        label = "Error"
        tint = Color.red
        showsProgress = false
      }

      HStack(spacing: 6) {
        if showsProgress, case .reading(let progress, _) = resolvedStatus {
          ProgressView(value: progress)
            .progressViewStyle(.linear)
            .frame(width: 36)
        }
        Text(label)
          .font(.system(size: 10, weight: .semibold))
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(AppTheme.Colors.surface2)
      .clipShape(Capsule())
      .overlay(
        Capsule()
          .stroke(tint.opacity(0.6), lineWidth: 1)
      )
      .foregroundStyle(tint)
    }
}

private struct FilePreviewTarget: Identifiable {
  let id: String
}

private struct FilePreviewSheet: View {
  let attachment: FileAttachment
  let onRefresh: () -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 12) {
      HStack {
        Text("Attachment Preview")
          .font(.system(size: 14, weight: .semibold))
        Spacer()
        Button("Done") {
          dismiss()
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.Colors.textSecondary)
      }

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          metadataSection
          strategySection
          excerptSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      HStack(spacing: 10) {
        Button("Copy excerpt") {
          copyExcerpt()
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.Colors.textSecondary)

        Button("Refresh excerpt") {
          onRefresh()
        }
        .buttonStyle(.plain)
        .foregroundStyle(StudioTheme.Colors.accent)

        Spacer()
      }
    }
    .padding(16)
    .frame(minWidth: 520, minHeight: 520)
    .background(AppTheme.Colors.surface0)
  }

  private var metadataSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Metadata")
        .font(.system(size: 12, weight: .semibold))
        .textCase(.uppercase)
        .foregroundStyle(AppTheme.Colors.textSubtle)

      metadataRow(label: "Name", value: attachment.identity.displayName)
      metadataRow(label: "Type", value: attachment.identity.contentType ?? fileExtensionLabel)
      metadataRow(label: "Bytes", value: attachment.identity.byteSize.map { "\(formatByteCount($0)) (\($0) bytes)" } ?? "Unknown")
      metadataRow(label: "Modified", value: attachment.identity.modifiedAt.map { dateString($0) } ?? "Unknown")
      metadataRow(label: "Extracted at", value: attachment.extraction.map { dateString($0.extractedAt) } ?? "Not extracted")
    }
    .padding(12)
    .background(AppTheme.Colors.surface1)
    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
        .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
    )
  }

  private var strategySection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Strategy")
        .font(.system(size: 12, weight: .semibold))
        .textCase(.uppercase)
        .foregroundStyle(AppTheme.Colors.textSubtle)

      Text(attachment.extraction?.strategy.rawValue ?? "Not extracted")
        .font(AppTheme.Typography.mono(12))
        .foregroundStyle(AppTheme.Colors.textPrimary)
    }
  }

  private var excerptSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Exact excerpt")
        .font(.system(size: 12, weight: .semibold))
        .textCase(.uppercase)
        .foregroundStyle(AppTheme.Colors.textSubtle)

      Text(attachment.extraction?.excerptText ?? "No excerpt available.")
        .font(AppTheme.Typography.mono(12))
        .foregroundStyle(AppTheme.Colors.textPrimary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.surface1)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
            .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
        )
    }
  }

  private func metadataRow(label: String, value: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Text(label)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(AppTheme.Colors.textSecondary)
        .frame(width: 90, alignment: .leading)
      Text(value)
        .font(.system(size: 11))
        .foregroundStyle(AppTheme.Colors.textPrimary)
    }
  }

  private var fileExtensionLabel: String {
    let ext = attachment.identity.ext
    return ext.isEmpty ? "Unknown" : ".\(ext)"
  }

  private func formatByteCount(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
  }

  private func dateString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  private func copyExcerpt() {
    guard let excerpt = attachment.extraction?.excerptText else { return }
#if os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(excerpt, forType: .string)
#endif
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
