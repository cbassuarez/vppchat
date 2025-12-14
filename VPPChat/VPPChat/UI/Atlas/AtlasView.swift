import SwiftUI

// MARK: - Atlas filter popover plumbing

private enum AtlasPopover: Hashable {
    case project
    case kind
    case tags
}

private struct FilterChipAnchorKey: PreferenceKey {
    static var defaultValue: [AtlasPopover: Anchor<CGRect>] = [:]

    static func reduce(value: inout [AtlasPopover: Anchor<CGRect>],
                       nextValue: () -> [AtlasPopover: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Main Atlas View

struct AtlasView: View {
    var onOpenInStudio: ((Block) -> Void)? = nil
    var onSendToConsole: ((Block) -> Void)? = nil

    @EnvironmentObject private var workspaceVM: WorkspaceViewModel
    @Environment(\.shellModeBinding) private var shellModeBinding
    @StateObject private var filters = AtlasFilterState()
    @State private var selectedIndex: Int = 0

    // Which dropdown is currently open
    @State private var activePopover: AtlasPopover? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 12) {
                filtersBand

                atlasContent
            }
            .padding(12)
            .background(
                ZStack {

                    RoundedRectangle(cornerRadius: StudioTheme.Radii.panel, style: .continuous)
                        .fill(AppTheme.Colors.surface1) // a bit lighter / more glassy
                        .overlay(
                            RoundedRectangle(cornerRadius: StudioTheme.Radii.panel, style: .continuous)
                                .stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
                        )
                }
            )
            .onChange(of: visibleBlocks) { blocks in
                let newIndex = max(0, min(selectedIndex, max(blocks.count - 1, 0)))
                selectedIndex = newIndex
            }
        }
        // Toolbar-style popovers, anchored to each chip via preferences + geometry
        .overlayPreferenceValue(FilterChipAnchorKey.self) { anchors in
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    if let active = activePopover,
                       let anchor = anchors[active] {
                        let rect = proxy[anchor]

                        popover(for: active)
                            // 👇 Hug content horizontally, don’t fill the whole width
                            .fixedSize(horizontal: true, vertical: true)
                            // 👇 Cap the width so long project names don’t explode the popover
                            .frame(maxWidth: 320, alignment: .leading)
                            // 👇 Position directly under the chip
                            .offset(x: rect.minX,
                                    y: rect.maxY + 8)
                    }
                }
                       .frame(maxWidth: .infinity,
                      maxHeight: .infinity,
                      alignment: .topLeading)
            }
        }
#if os(macOS)
        .onKeyPress(.upArrow) {
            moveSelection(delta: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(delta: 1)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            moveSelection(delta: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            moveSelection(delta: 1)
            return .handled
        }
        .onKeyPress(.return) {
            openSelectedBlock()
            return .handled
        }
#endif
    }

    // MARK: - Filters band (toolbar)

    private var filtersBand: some View {
        HStack(spacing: 10) {
            projectFilterChip
            kindFilterChip
            tagsFilterChip
            canonicalChip

            if filters.hasActiveFilters {
                Button {
                    filters.reset()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Reset filters")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.Colors.surface0)
                    .clipShape(Capsule())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            searchField
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10) // slightly taller than before
        .frame(maxWidth: 900)   // inset, toolbar-like
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(StudioTheme.Colors.surface1)
        )
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: - Individual chips

    private var projectFilterChip: some View {
        let isActive = filters.selectedProjectID != nil
        let labelText = filters.selectedProjectID.flatMap { id in
            workspaceVM.store.project(id: id)?.name
        } ?? "All Projects"

        return FilterChip(isActive: isActive, primary: true) {
            withAnimation(.easeOut(duration: 0.18)) {
                activePopover = (activePopover == .project ? nil : .project)
            }
        } label: {
            Text(labelText)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
        }
        .anchorPreference(key: FilterChipAnchorKey.self, value: .bounds) { anchor in
            [.project: anchor]
        }
    }

    private var kindFilterChip: some View {
        let isActive = (filters.kind != nil)

        return FilterChip(isActive: isActive, primary: false) {
            withAnimation(.easeOut(duration: 0.18)) {
                activePopover = (activePopover == .kind ? nil : .kind)
            }
        } label: {
            Text(kindLabel)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
        }
        .anchorPreference(key: FilterChipAnchorKey.self, value: .bounds) { anchor in
            [.kind: anchor]
        }
    }

    private var tagsFilterChip: some View {
        let count = filters.selectedTags.count
        let baseLabel = "Tags"
        let labelText: String = {
            if count == 0 {
                return baseLabel
            } else {
                return "\(baseLabel): \(count) selected"
            }
        }()

        let isActive = count > 0

        return FilterChip(isActive: isActive, primary: false) {
            withAnimation(.easeOut(duration: 0.18)) {
                activePopover = (activePopover == .tags ? nil : .tags)
            }
        } label: {
            Text(labelText)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
        }
        .anchorPreference(key: FilterChipAnchorKey.self, value: .bounds) { anchor in
            [.tags: anchor]
        }
    }

    private var canonicalChip: some View {
        let isOn = filters.canonicalOnly

        return Button {
            filters.canonicalOnly.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.seal.fill" : "checkmark.seal")
                    .font(.system(size: 11, weight: .semibold))
                Text("Canonical only")
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isOn
                          ? StudioTheme.Colors.accent   // badge-like: solid accent
                          : StudioTheme.Colors.surface1)
            )
            .overlay(
                Capsule()
                    .stroke(isOn
                            ? StudioTheme.Colors.accent
                            : StudioTheme.Colors.borderSoft,
                            lineWidth: 1)
            )
            .foregroundStyle(isOn
                             ? Color.white        // badge: white text/icon on accent
                             : StudioTheme.Colors.textSecondary)
        }
        .buttonStyle(ScalePressButtonStyle())
    }

    // MARK: - Search field (slightly taller than chips)

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(StudioTheme.Colors.textSubtle)
            TextField("Search blocks", text: $filters.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8) // a bit taller than filter chips
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(StudioTheme.Colors.surface1)
        )
    }

    // MARK: - Popover content

    @ViewBuilder
    private func popover(for popover: AtlasPopover) -> some View {
        switch popover {
        case .project:
            ProjectFilterPopover(
                selectedProjectID: $filters.selectedProjectID,
                projects: workspaceVM.store.allProjects,
                onClose: { activePopover = nil }
            )
        case .kind:
            KindFilterPopover(
                selectedKind: $filters.kind,
                onClose: { activePopover = nil }
            )
        case .tags:
            TagsFilterPopover(
                selectedTags: $filters.selectedTags,
                allTags: VppTag.allCases,
                onClose: { activePopover = nil }
            )
        }
    }

    // MARK: - Content & empty states

    @ViewBuilder
    private var atlasContent: some View {
        if visibleBlocks.isEmpty {
            if allBlocks.isEmpty {
                onboardingEmptyState
            } else {
                filteredEmptyState
            }
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 260), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(Array(visibleBlocks.enumerated()), id: \.1.id) { index, block in
                        BlockCardView(block: block, isSelected: index == selectedIndex)
                            .contextMenu {
                                Button("Open in Studio") {
                                    openInStudio(block: block)
                                }
                                Button("Send to Console") {
                                    sendToConsole(block: block)
                                }
                            }
                            .onTapGesture {
                                selectedIndex = index
                            }
                            .onTapGesture(count: 2) {
                                selectedIndex = index
                                openBlock(block)
                            }
                    }
                    .padding(8)
                }
                // 👇 Slightly more vertical padding around the grid as a whole
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            }
        }
    }

    private var onboardingEmptyState: some View {
        VStack(spacing: 6) {
            Text("You haven’t saved any blocks yet.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(StudioTheme.Colors.textPrimary)

            Text("Create a block in Studio or Console to see it here.")
                .font(.system(size: 11))
                .foregroundStyle(StudioTheme.Colors.textSecondary)

            HStack(spacing: 8) {
                Button("Open Studio") {
                    shellModeBinding?.wrappedValue = .studio
                }
                .buttonStyle(PrimaryCapsuleButton())

                Button("Open Console") {
                    shellModeBinding?.wrappedValue = .console
                }
                .buttonStyle(SecondaryCapsuleButton())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                .fill(AppTheme.Colors.surface0)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                        .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                )
        )
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 6) {
            Text("No blocks match these filters.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(StudioTheme.Colors.textPrimary)

            Button {
                filters.reset()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Reset filters")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.Colors.surface0)
                .clipShape(Capsule())
                .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Filtering logic (unchanged)

    private var allBlocks: [Block] {
        workspaceVM.store.allBlocksSortedByUpdatedAtDescending()
    }

    private var filteredBlocks: [Block] {
        allBlocks.filter { block in
            matchesFilters(block)
        }
    }

    private var visibleBlocks: [Block] { filteredBlocks }

    private func matchesFilters(_ block: Block) -> Bool {
        // Project filter
        if let pid = filters.selectedProjectID,
           workspaceVM.store.project(for: block)?.id != pid {
            return false
        }

        // Kind filter
        if let kind = filters.kind,
           block.kind != kind {
            return false
        }

        // Canonical-only filter
        if filters.canonicalOnly && !block.isCanonical {
            return false
        }

        // Tag filter
        if !filters.selectedTags.isEmpty {
            let hasTag = block.messages.contains { msg in
                filters.selectedTags.contains(msg.tag)
            }
            if !hasTag { return false }
        }

        // Search filter
        let q = filters.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            let lowerQ = q.lowercased()

            let textParts: [String] = [
                block.title,
                block.subtitle ?? "",
                block.documentText ?? "",
                block.messages.map { $0.body }.joined(separator: " ")
            ]

            let haystack = textParts.joined(separator: " ").lowercased()

            if !haystack.contains(lowerQ) {
                return false
            }
        }

        return true
    }

    private var kindLabel: String {
        switch filters.kind {
        case .none:                return "Any kind"
        case .some(.conversation): return "Conversation"
        case .some(.document):     return "Document"
        case .some(.reference):    return "Reference"
        }
    }

    private func openInStudio(block: Block) {
        workspaceVM.select(block: block)
        onOpenInStudio?(block)
    }

    private func openBlock(_ block: Block) {
        openInStudio(block: block)
    }

    private func openSelectedBlock() {
        guard visibleBlocks.indices.contains(selectedIndex) else { return }
        openBlock(visibleBlocks[selectedIndex])
    }

    private func moveSelection(delta: Int) {
        guard !visibleBlocks.isEmpty else { return }
        let newIndex = max(0, min(selectedIndex + delta, visibleBlocks.count - 1))
        selectedIndex = newIndex
    }

    private func sendToConsole(block: Block) {
        if let scene = workspaceVM.store.scene(id: block.sceneID),
           let track = workspaceVM.store.track(id: scene.trackID),
           let project = workspaceVM.store.project(id: track.projectID) {
            let session = workspaceVM.openConsole(for: block, project: project, track: track, scene: scene)
            workspaceVM.touchConsoleSession(session.id)
            shellModeBinding?.wrappedValue = .console
        }
        onSendToConsole?(block)
    }
}

// MARK: - Popover shells

private struct PopoverChrome<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(12)
        .background(
            .ultraThinMaterial.opacity(0.5),
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

// MARK: - Project popover

private struct ProjectFilterPopover: View {
    @Binding var selectedProjectID: Project.ID?
    let projects: [Project]
    let onClose: () -> Void

    var body: some View {
        PopoverChrome {
            HStack {
                Text("Project")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(StudioTheme.Colors.textSecondary)
                Spacer()
                if selectedProjectID != nil {
                    Button("Clear") {
                        selectedProjectID = nil
                        onClose()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(StudioTheme.Colors.textSecondary)
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)

            Button {
                selectedProjectID = nil
                onClose()
            } label: {
                HStack {
                    Text("All Projects")
                    Spacer()
                    if selectedProjectID == nil {
                        Image(systemName: "checkmark")
                    }
                }
                .font(.system(size: 12, weight: .regular))
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)

            Divider()

            ForEach(projects) { project in
                let isSelected = (selectedProjectID == project.id)
                Button {
                    selectedProjectID = project.id
                    onClose()
                } label: {
                    HStack {
                        Text(project.name)
                            .lineLimit(1)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark")
                        }
                    }
                    .font(.system(size: 12, weight: .regular))
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Kind popover

private struct KindFilterPopover: View {
    @Binding var selectedKind: BlockKind?
    let onClose: () -> Void

    var body: some View {
        PopoverChrome {
            HStack {
                Text("Kind")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(StudioTheme.Colors.textSecondary)
                Spacer()
                if selectedKind != nil {
                    Button("Clear") {
                        selectedKind = nil
                        onClose()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(StudioTheme.Colors.textSecondary)
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)

            kindRow(label: "Any kind", kind: nil)
            Divider()
            kindRow(label: "Conversation", kind: .conversation)
            kindRow(label: "Document", kind: .document)
            kindRow(label: "Reference", kind: .reference)
        }
    }

    @ViewBuilder
    private func kindRow(label: String, kind: BlockKind?) -> some View {
        let isSelected = (selectedKind == kind)
        Button {
            selectedKind = kind
            onClose()
        } label: {
            HStack {
                Text(label)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
            .font(.system(size: 12, weight: .regular))
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

// MARK: - Tags popover

private struct TagsFilterPopover: View {
    @Binding var selectedTags: Set<VppTag>
    let allTags: [VppTag]
    let onClose: () -> Void

    var body: some View {
        PopoverChrome {
            HStack {
                Text("Tags")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(StudioTheme.Colors.textSecondary)
                Spacer()
                if !selectedTags.isEmpty {
                    Button("Clear") {
                        selectedTags.removeAll()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(StudioTheme.Colors.textSecondary)
                    .buttonStyle(.plain)
                }
                Button("Done") {
                    onClose()
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(StudioTheme.Colors.textSecondary)
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(allTags, id: \.self) { tag in
                        tagRow(tag)
                    }
                }
            }
            .frame(maxHeight: 260) // keep it compact
        }
    }

    @ViewBuilder
    private func tagRow(_ tag: VppTag) -> some View {
        let isOn = selectedTags.contains(tag)
        Button {
            if isOn {
                selectedTags.remove(tag)
            } else {
                selectedTags.insert(tag)
            }
        } label: {
            HStack {
                Text(tag.rawValue)
                    .font(.system(size: 12, weight: .regular))
                Spacer()
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(StudioTheme.Colors.accent)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isOn ? StudioTheme.Colors.accentSoft : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared chip styles

private struct FilterChip<Label: View>: View {
    let isActive: Bool
    let primary: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                label()
            }
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isActive
                          ? StudioTheme.Colors.accentSoft
                          : StudioTheme.Colors.surface1)
            )
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: primary ? (isActive ? 1.2 : 1) : 1)
            )
            .foregroundStyle(isActive
                             ? StudioTheme.Colors.textPrimary
                             : StudioTheme.Colors.textSecondary)
            .scaleEffect(isHovering ? 1.02 : 1.0)
        }
        .buttonStyle(ScalePressButtonStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private var borderColor: Color {
        if primary {
            return isActive ? StudioTheme.Colors.accent : StudioTheme.Colors.borderSoft
        } else {
            return isActive ? StudioTheme.Colors.accent : StudioTheme.Colors.borderSoft.opacity(0.9)
        }
    }
}

private struct PrimaryCapsuleButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(StudioTheme.Colors.accent))
            .overlay(
                Capsule()
                    .stroke(StudioTheme.Colors.accent, lineWidth: 1.1)
            )
            .foregroundStyle(Color.white)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

private struct SecondaryCapsuleButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(AppTheme.Colors.surface0))
            .overlay(
                Capsule()
                    .stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
            )
            .foregroundStyle(StudioTheme.Colors.textSecondary)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

private struct ScalePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
