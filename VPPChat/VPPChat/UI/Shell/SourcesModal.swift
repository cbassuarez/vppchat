//
//  SourcesModal.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//

import SwiftUI

// MARK: - Kind popover plumbing (Atlas-style)

private struct SourceKindAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>],
                       nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct SourcesModal: View {
    @Binding var sources: VppSources
    @Binding var sourcesTable: [VppSourceRef]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var draftSources: VppSources = .none
    @State private var draftTable: [VppSourceRef] = []

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
                    Text("Choose whether this send should use web sources, and review any attached source references. These are applied at send-time (not stored in the transcript).")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    modePicker

                    sourcesSection

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

    // MARK: - Mode

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Mode")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.Colors.textSubtle)
                Spacer()
            }

            HStack(spacing: 6) {
                modeChip("None", isSelected: draftSources == .none) {
                    withAnimation(popAnimation) { draftSources = .none }
                }

                modeChip("Web", isSelected: draftSources == .web) {
                    withAnimation(popAnimation) { draftSources = .web }
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func modeChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isSelected ? StudioTheme.Colors.accentSoft : AppTheme.Colors.surface1)
                )
                .overlay(
                    Capsule().stroke(
                        isSelected ? StudioTheme.Colors.accent : AppTheme.Colors.borderSoft,
                        lineWidth: isSelected ? 1.4 : 1
                    )
                )
                .foregroundStyle(isSelected ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sources section

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Attached sources")
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
                Text("If you expected items here, ensure `sourcesTable` is being passed into `ComposerView` from the parent view.")
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

                    TextField(placeholder(for: ref.wrappedValue.kind), text: Binding(
                        get: { ref.wrappedValue.ref },
                        set: { ref.wrappedValue.ref = $0 }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    /// TODO: implement
//                    .textInputAutocapitalization(.never)
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

                Text(hint(for: ref.wrappedValue.kind))
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

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

    private func kindChip(ref: Binding<VppSourceRef>) -> some View {
        let id = ref.wrappedValue.id

        return Button {
            withAnimation(.easeOut(duration: 0.18)) {
                activeKindPickerID = (activeKindPickerID == id ? nil : id)
            }
        } label: {
            HStack(spacing: 6) {
                Text(ref.wrappedValue.kind.rawValue.uppercased())
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
                        Text(kind.rawValue)
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

    // MARK: - Buttons

    private var buttons: some View {
        HStack(spacing: 10) {
            Button("Clear") {
                withAnimation(popAnimation) {
                    sources = .none
                    sourcesTable = []
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
                sources = draftSources
                sourcesTable = draftTable
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
        draftSources = sources
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
        case .web:  return "domain/page/* or full URL"
        case .repo: return "github.com/owner/repo (optional #path @ref)"
        case .file: return "/path/to/file"
        case .ssh:  return "user@host:/path or ssh://user@host/path"
        }
    }

    private func hint(for kind: VppSourceKind) -> String {
        switch kind {
        case .web:  return "Example: wikipedia.org/wiki/Spinoza"
        case .repo: return "Example: github.com/StageDevices/VPPChat#UI @main"
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
