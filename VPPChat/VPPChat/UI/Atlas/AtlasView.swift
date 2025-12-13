import SwiftUI

struct AtlasView: View {
    var onOpenInStudio: ((Block) -> Void)? = nil
    var onSendToConsole: ((Block) -> Void)? = nil

    @EnvironmentObject private var workspaceVM: WorkspaceViewModel
    @StateObject private var filters = AtlasFilterState()

    var body: some View {
        VStack(spacing: 12) {
            filtersBand

            if filteredBlocks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 260), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(filteredBlocks) { block in
                            BlockCardView(block: block)
                                .contextMenu {
                                    Button("Open in Studio") {
                                        openInStudio(block: block)
                                    }
                                    Button("Send to Console") {
                                        sendToConsole(block: block)
                                    }
                                }
                                .onTapGesture(count: 2) {
                                    openInStudio(block: block)
                                }
                        }
                        .padding(.bottom, 8)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.Radii.panel, style: .continuous)
                .fill(StudioTheme.Colors.surface1)
                .overlay(
                    RoundedRectangle(cornerRadius: StudioTheme.Radii.panel, style: .continuous)
                        .stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
                )
        )
    }

    private var filtersBand: some View {
        HStack(spacing: 10) {
            projectFilter
            kindFilter
            tagFilter
            canonicalToggle

            Spacer()

            searchField

            if hasActiveFilters {
                Button("Reset") {
                    resetFilters()
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(StudioTheme.Colors.textSecondary)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(StudioTheme.Colors.surface2)
        )
    }

    private var projectFilter: some View {
        Menu {
            Button("All Projects") {
                filters.selectedProjectID = nil
            }
            ForEach(workspaceVM.store.allProjects) { project in
                Button(project.name) {
                    filters.selectedProjectID = project.id
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(filters.selectedProjectID.flatMap { id in
                    workspaceVM.store.project(id: id)?.name
                } ?? "All Projects")
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(StudioTheme.Colors.surface1)
            )
            .foregroundStyle(StudioTheme.Colors.textSecondary)
        }
    }

    private var kindFilter: some View {
        Menu {
            Button("Any kind") {
                filters.kind = nil
            }
            Button("Conversation") {
                filters.kind = .conversation
            }
            Button("Document") {
                filters.kind = .document
            }
            Button("Reference") {
                filters.kind = .reference
            }
        } label: {
            HStack(spacing: 6) {
                Text(kindLabel)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(StudioTheme.Colors.surface1)
            )
            .foregroundStyle(StudioTheme.Colors.textSecondary)
        }
    }

    private var tagFilter: some View {
        HStack(spacing: 4) {
            ForEach(VppTag.allCases, id: \.self) { tag in
                let isOn = filters.selectedTags.contains(tag)
                Button {
                    if isOn {
                        filters.selectedTags.remove(tag)
                    } else {
                        filters.selectedTags.insert(tag)
                    }
                } label: {
                    Text(tag.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .textCase(.uppercase)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isOn ? StudioTheme.Colors.accentSoft
                                           : StudioTheme.Colors.surface1)
                        )
                        .foregroundStyle(isOn ? StudioTheme.Colors.textPrimary
                                              : StudioTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var canonicalToggle: some View {
        Button {
            filters.canonicalOnly.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filters.canonicalOnly ? "checkmark.seal.fill" : "checkmark.seal")
                    .font(.system(size: 11, weight: .semibold))
                Text("Canonical only")
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(filters.canonicalOnly
                          ? StudioTheme.Colors.accentSoft
                          : StudioTheme.Colors.surface1)
            )
            .foregroundStyle(filters.canonicalOnly
                             ? StudioTheme.Colors.textPrimary
                             : StudioTheme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(StudioTheme.Colors.textSubtle)
            TextField("Search blocks", text: $filters.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(StudioTheme.Colors.surface1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No blocks match these filters.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(StudioTheme.Colors.textPrimary)
            Text("Try clearing the search field, tags, or Canonical-only filter.")
                .font(.system(size: 12))
                .foregroundStyle(StudioTheme.Colors.textSecondary)
            Button("Reset filters") {
                resetFilters()
            }
            .font(.system(size: 12, weight: .semibold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var allBlocks: [Block] {
        workspaceVM.store.allBlocksSortedByUpdatedAtDescending()
    }

    private var filteredBlocks: [Block] {
        allBlocks.filter { block in
            if let pid = filters.selectedProjectID,
               workspaceVM.store.project(for: block)?.id != pid {
                return false
            }

            if let kind = filters.kind,
               block.kind != kind {
                return false
            }

            if filters.canonicalOnly && !block.isCanonical {
                return false
            }

            if !filters.selectedTags.isEmpty {
                let hasTag = block.messages.contains { msg in
                    filters.selectedTags.contains(msg.tag)
                }
                if !hasTag { return false }
            }

            let q = filters.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !q.isEmpty {
                let haystack = (
                    (block.title) + " " +
                    (block.subtitle ?? "") + " " +
                    (block.documentText ?? "") + " " +
                    block.messages.map { $0.body }.joined(separator: " ")
                ).lowercased()
                if !haystack.contains(q.lowercased()) {
                    return false
                }
            }

            return true
        }
    }

    private var hasActiveFilters: Bool {
        filters.selectedProjectID != nil ||
        filters.kind != nil ||
        !filters.selectedTags.isEmpty ||
        filters.canonicalOnly ||
        !filters.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func resetFilters() {
        filters.selectedProjectID = nil
        filters.kind = nil
        filters.selectedTags.removeAll()
        filters.canonicalOnly = false
        filters.searchText = ""
    }

    private var kindLabel: String {
        switch filters.kind {
        case .none:            return "Any kind"
        case .some(.conversation): return "Conversation"
        case .some(.document):     return "Document"
        case .some(.reference):    return "Reference"
        }
    }

    private func openInStudio(block: Block) {
        workspaceVM.select(block: block)
        onOpenInStudio?(block)
    }

    private func sendToConsole(block: Block) {
        onSendToConsole?(block)
    }
}
