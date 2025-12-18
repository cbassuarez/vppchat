import SwiftUI

/// Canonical sidebar for BOTH Studio + Console:
/// - Library tree: Environment → Project → Topic → Chat
/// - Inline rename (Enter commits, Esc cancels)
/// - Hover-only “…” menu for env/project/track/scene
/// - Move submenu with tree
/// - Drag/drop move + reorder (projects within env, topics within project, chats within topic)
/// - Trash section appended at bottom (console trash feature)
struct TracksRailView: View {
    @EnvironmentObject private var vm: WorkspaceViewModel
    @EnvironmentObject private var theme: ThemeManager
    @State private var isTrashHovering = false
    @State private var isTrashExpanded = false

    // Hover / menu affordances
    @State private var hovered: HoverTarget? = nil

    // Inline rename
    @State private var editing: EditingTarget? = nil
    @State private var editingText: String = ""
    @FocusState private var renameFocused: Bool

    // Trash restore sheet
    @State private var restoreRequest: RestoreRequest?
    // Disclosure persistence (default open; store closed IDs)
      @State private var collapsedProjects: Set<UUID> = []
      @State private var collapsedTracks: Set<UUID> = []


    private enum HoverTarget: Hashable {
        case env(UUID), project(UUID), track(UUID), scene(UUID)
    }
    private func titleForTrash(_ payload: WorkspaceDragPayload) -> String {
      switch payload.kind {
      case .project:
        return vm.store.project(id: payload.id)?.name ?? "Project"
      case .track:
        return vm.store.track(id: payload.id)?.name ?? "Topic"
      case .scene:
        return vm.store.scene(id: payload.id)?.title ?? "Chat"
 //     case .block:
 //        return vm.store.block(id: payload.id)?.title ?? "Block"
      default:
        return "Item"
      }
    }
    private struct EditingTarget: Hashable {
        let kind: RenameRequest.Kind
        let id: UUID
        let currentName: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            GeometryReader { geo in
                  // Reserve space so Trash is always visible (tweak if needed)
                  let reservedForTrash: CGFloat = 120
                  let libraryViewport = max(0, geo.size.height - reservedForTrash)
            
                  VStack(alignment: .leading, spacing: 8) {
                    ScrollView {
                      libraryTree(viewportHeight: libraryViewport)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
            
                    Divider().opacity(0.6)
                    trashSection
                  }
                }
        }
        .padding(12)
        .background(panelChrome)
        .onAppear {
            loadDisclosureState()
            vm.reloadLibraryTree()
            vm.reloadTrash()
        }
        .onChange(of: vm.activeWorkspaceName) { _ in
              loadDisclosureState()
            }
            .onChange(of: collapsedProjects) { _ in persistDisclosureState() }
            .onChange(of: collapsedTracks) { _ in persistDisclosureState() }
        .sheet(item: $restoreRequest) { req in
            RestoreSheet(req: req)
                .environmentObject(vm)
        }
    }

    // MARK: - Chrome
    private var panelChrome: some View {
        ZStack {
            RoundedRectangle(cornerRadius: StudioTheme.Radii.panel, style: .continuous)
                .fill(AppTheme.Colors.surface1)
            RoundedRectangle(cornerRadius: StudioTheme.Radii.panel, style: .continuous)
                .stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: StudioTheme.Radii.panel, style: .continuous))
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 10) {
            Text(vm.activeWorkspaceName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(StudioTheme.Colors.textPrimary)
            Spacer()
        }
    }

    // MARK: - Library tree
    private func libraryTree(viewportHeight: CGFloat) -> some View {
       let envs = vm.libraryTree
       let count = max(envs.count, 1)
       let spacing: CGFloat = 8
       let minPartitionHeight: CGFloat = 160
       let proposed = (viewportHeight - spacing * CGFloat(count - 1)) / CGFloat(count)
       let partitionHeight = max(minPartitionHeight, proposed)
    
       return VStack(alignment: .leading, spacing: spacing) {
         ForEach(envs) { env in
           envPartition(env, height: partitionHeight)
         }
       }
     }

    private func envPartition(_ env: WorkspaceRepository.EnvironmentNode, height: CGFloat) -> some View {
       VStack(alignment: .leading, spacing: 8) {
         // “Container header” (env is not part of the tree)
         treeRow(
           icon: "globe",
           title: env.name,
           selected: false,
           hoverKey: .env(env.id),
           editingKind: .environment,
           editingID: env.id,
           currentName: env.name,
           onTap: { /* env selection not modeled */ },
           menu: { envMenu(env) }
         )
    
         Divider().opacity(0.35)
    
         VStack(alignment: .leading, spacing: 8) {
           ForEach(env.projects) { proj in
             projectSection(env: env, proj: proj)
           }
         }
         .padding(.leading, 12)
       }
       .padding(10)
       .frame(maxWidth: .infinity, alignment: .leading)
       .frame(height: height, alignment: .top)
       .background(
         RoundedRectangle(cornerRadius: StudioTheme.Radii.card, style: .continuous)
           .fill(AppTheme.Colors.surface1)
           .overlay(
             RoundedRectangle(cornerRadius: StudioTheme.Radii.card, style: .continuous)
               .stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
           )
       )
       // Drop project onto env to MOVE (append)
       .dropDestination(for: WorkspaceDragPayload.self) { payloads, _ in
         payloads.contains { payload in
           guard payload.kind == .project else { return false }
           vm.uiMoveOrReorderProject(payload.id, toEnvironmentID: env.id, beforeProjectID: nil)
           return true
         }
       }
     }


    private func projectSection(env: WorkspaceRepository.EnvironmentNode, proj: WorkspaceRepository.ProjectNode) -> some View {
        DisclosureGroup(isExpanded: projectExpandedBinding(proj.id)) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(proj.tracks) { tr in
                    trackSection(env: env, proj: proj, tr: tr)
                }
            }
            .padding(.leading, 12)
        } label: {
            treeRow(
                icon: "folder.fill",
                title: proj.name,
                selected: false,
                hoverKey: .project(proj.id),
                editingKind: .project,
                editingID: proj.id,
                currentName: proj.name,
                onTap: {
                    // selection via underlying models (keeps store in sync)
                    vm.selectedProjectID = proj.id
                },
                menu: { projectMenu(env: env, proj: proj) }
            )
            .draggable(WorkspaceDragPayload(kind: .project, id: proj.id))
            // Drop topic onto project to MOVE (append)
            .dropDestination(for: WorkspaceDragPayload.self) { payloads, _ in
                // 1) topic → move into this project (append)
                let movedTrack = payloads.contains { payload in
                    guard payload.kind == .track else { return false }
                    vm.uiMoveOrReorderTrack(payload.id, toProjectID: proj.id, beforeTrackID: nil)
                    return true
                }
                // 2) project → reorder within this env (insert before this project)
                let reorderedProject = payloads.contains { payload in
                    guard payload.kind == .project, payload.id != proj.id else { return false }
                    vm.uiMoveOrReorderProject(payload.id, toEnvironmentID: env.id, beforeProjectID: proj.id)
                    return true
                }
                return movedTrack || reorderedProject
            }
        }
    }

    private func trackSection(env: WorkspaceRepository.EnvironmentNode, proj: WorkspaceRepository.ProjectNode, tr: WorkspaceRepository.TrackNode) -> some View {
        DisclosureGroup(isExpanded: trackExpandedBinding(tr.id)) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(tr.scenes) { sc in
                    sceneRow(env: env, proj: proj, tr: tr, sc: sc)
                }
            }
            .padding(.leading, 12)
        } label: {
            let trackModel = vm.store.track(id: tr.id)
            treeRow(
                icon: "rectangle.3.offgrid.fill",
                title: trackModel?.name ?? tr.name,
                selected: (vm.selectedTrackID == tr.id),
                hoverKey: .track(tr.id),
                editingKind: .track,
                editingID: tr.id,
                currentName: trackModel?.name ?? tr.name,
                onTap: {
                    if let t = trackModel { vm.select(track: t) }
                    else { vm.selectedTrackID = tr.id }
                },
                menu: { trackMenu(env: env, proj: proj, tr: tr) }
            )
            .draggable(WorkspaceDragPayload(kind: .track, id: tr.id))
            // Drop chat onto topic to MOVE (append)
            .dropDestination(for: WorkspaceDragPayload.self) { payloads, _ in
                // 1) chat → move into this topic (append)
                let movedScene = payloads.contains { payload in
                    guard payload.kind == .scene else { return false }
                    vm.uiMoveOrReorderScene(payload.id, toTrackID: tr.id, beforeSceneID: nil)
                    return true
                }
                // 2) topic → reorder within this project (insert before this track)
                let reorderedTrack = payloads.contains { payload in
                    guard payload.kind == .track, payload.id != tr.id else { return false }
                    vm.uiMoveOrReorderTrack(payload.id, toProjectID: proj.id, beforeTrackID: tr.id)
                    return true
                }
                return movedScene || reorderedTrack
            }
        }
    }
    // MARK: - Disclosure persistence (default open)
    private var disclosureKeyPrefix: String {
      let safe = vm.activeWorkspaceName.replacingOccurrences(of: " ", with: "_")
      return "vpp.sidebar.\(safe)"
    }

    private func loadDisclosureState() {
      collapsedProjects = loadUUIDSet(forKey: "\(disclosureKeyPrefix).collapsedProjects")
      collapsedTracks = loadUUIDSet(forKey: "\(disclosureKeyPrefix).collapsedTracks")
    }

    private func persistDisclosureState() {
      saveUUIDSet(collapsedProjects, forKey: "\(disclosureKeyPrefix).collapsedProjects")
      saveUUIDSet(collapsedTracks, forKey: "\(disclosureKeyPrefix).collapsedTracks")
    }

    private func loadUUIDSet(forKey key: String) -> Set<UUID> {
      let arr = (UserDefaults.standard.array(forKey: key) as? [String]) ?? []
      return Set(arr.compactMap(UUID.init))
    }

    private func saveUUIDSet(_ set: Set<UUID>, forKey key: String) {
      UserDefaults.standard.set(set.map(\.uuidString), forKey: key)
    }

    private func projectExpandedBinding(_ id: UUID) -> Binding<Bool> {
      Binding(
        get: { !collapsedProjects.contains(id) },
        set: { expanded in
          if expanded { collapsedProjects.remove(id) } else { collapsedProjects.insert(id) }
        }
      )
    }

    private func trackExpandedBinding(_ id: UUID) -> Binding<Bool> {
      Binding(
        get: { !collapsedTracks.contains(id) },
        set: { expanded in
          if expanded { collapsedTracks.remove(id) } else { collapsedTracks.insert(id) }
        }
      )
    }

    private func handleTrashDrop(_ payloads: [WorkspaceDragPayload]) -> Bool {
      var any = false
      for p in payloads {
        let title = titleForTrash(p)
        switch p.kind {
        case .project: vm.uiTrashProject(p.id, title: title); any = true
        case .track:   vm.uiTrashTrack(p.id, title: title); any = true
        case .scene:   vm.uiTrashScene(p.id, title: title); any = true
   //   case .block:   vm.uiTrashBlock(p.id, title: title); any = true
        default: break
        }
      }
      return any
    }

    private func sceneRow(env: WorkspaceRepository.EnvironmentNode, proj: WorkspaceRepository.ProjectNode, tr: WorkspaceRepository.TrackNode, sc: WorkspaceRepository.SceneNode) -> some View {
        let sceneModel = vm.store.scene(id: sc.id)
        let title = sceneModel?.title ?? sc.title

        return HStack(spacing: 8) {
            rowTitle(
                kind: .scene,
                id: sc.id,
                title: title,
                selected: (vm.selectedSceneID == sc.id),
                icon: "square.stack.3d.down.right.fill"
            )

            Spacer(minLength: 0)

            trailingEllipsisMenu(
                hoverKey: .scene(sc.id),
                menu: { sceneMenu(env: env, proj: proj, tr: tr, sc: sc) }
            )
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(vm.selectedSceneID == sc.id ? theme.structuralAccent.opacity(0.16) : Color.clear)
        )
        .contentShape(Rectangle())

        .gesture(
            TapGesture(count: 2).onEnded {
                // Keep existing UX: double-click opens in console
                if let t = vm.store.track(id: tr.id) { vm.select(track: t) }
                if let s = sceneModel { vm.select(scene: s) } else { vm.selectedSceneID = sc.id }
                vm.uiOpenSceneInConsole(sc.id)
            }
            .exclusively(before: TapGesture(count: 1).onEnded {
                if let t = vm.store.track(id: tr.id) { vm.select(track: t) }
                if let s = sceneModel { vm.select(scene: s) } else { vm.selectedSceneID = sc.id }
            })
        )
        .draggable(WorkspaceDragPayload(kind: .scene, id: sc.id))
        // Drop chat onto chat = reorder within topic (insert before)
        .dropDestination(for: WorkspaceDragPayload.self) { payloads, _ in
            payloads.contains { payload in
                guard payload.kind == .scene, payload.id != sc.id else { return false }
                vm.uiMoveOrReorderScene(payload.id, toTrackID: tr.id, beforeSceneID: sc.id)
                return true
            }
        }
        #if os(macOS)
        .onHover { isHovering in
            hovered = isHovering ? .scene(sc.id) : (hovered == .scene(sc.id) ? nil : hovered)
        }
        #endif
        .animation(.easeInOut(duration: 0.12), value: hovered)
    }

    // MARK: - Tree row primitives
    private func treeRow(
        icon: String,
        title: String,
        selected: Bool,
        hoverKey: HoverTarget,
        editingKind: RenameRequest.Kind,
        editingID: UUID,
        currentName: String,
        onTap: @escaping () -> Void,
        @ViewBuilder menu: @escaping () -> some View
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(StudioTheme.Colors.textSecondary)

            rowTitle(
                kind: editingKind,
                id: editingID,
                title: title,
                selected: selected,
                icon: nil
            )

            Spacer(minLength: 0)

            trailingEllipsisMenu(hoverKey: hoverKey, menu: menu)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        #if os(macOS)
        .onHover { isHovering in
            hovered = isHovering ? hoverKey : (hovered == hoverKey ? nil : hovered)
        }
        #endif
        .animation(.easeInOut(duration: 0.12), value: hovered)
    }

    @ViewBuilder
    private func rowTitle(
        kind: RenameRequest.Kind,
        id: UUID,
        title: String,
        selected: Bool,
        icon: String?
    ) -> some View {
        if editing?.id == id, editing?.kind == kind {
            TextField("", text: $editingText)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(StudioTheme.Colors.textPrimary)
                .focused($renameFocused)
                .onAppear {
                    if editingText.isEmpty { editingText = title }
                    DispatchQueue.main.async { renameFocused = true }
                }
                .onSubmit { commitRename() }
                .onExitCommand { cancelRename() }
        } else {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? theme.structuralAccent : StudioTheme.Colors.textPrimary)
        }
    }

    @ViewBuilder
    private func trailingEllipsisMenu(
        hoverKey: HoverTarget,
        @ViewBuilder menu: @escaping () -> some View
    ) -> some View {
        let show = (hovered == hoverKey) && (editing == nil)
        Menu {
            menu()
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(StudioTheme.Colors.textSecondary)
                .padding(6)
                .background(
                    Circle().fill(AppTheme.Colors.surface0.opacity(0.8))
                )
                .overlay(
                    Circle().stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
                )
        }
        .menuStyle(.borderlessButton)
        .opacity(show ? 1 : 0)
        .allowsHitTesting(show)
    }

    // MARK: - Menus
    private func envMenu(_ env: WorkspaceRepository.EnvironmentNode) -> some View {
        Group {
            Button("Rename") { beginRename(kind: .environment, id: env.id, current: env.name) }
            Divider()
            Button("New Project…") { vm.uiCreateProject(in: env.id) }
            Divider()
            Button("Move to Trash") { vm.uiTrashEnvironment(env.id, title: env.name) }
        }
    }

    private func projectMenu(env: WorkspaceRepository.EnvironmentNode, proj: WorkspaceRepository.ProjectNode) -> some View {
        Group {
            Button("Rename") { beginRename(kind: .project, id: proj.id, current: proj.name) }
            Menu("Move…") {
                ForEach(vm.libraryTree) { targetEnv in
                    Button(targetEnv.name) {
                        vm.uiMoveOrReorderProject(proj.id, toEnvironmentID: targetEnv.id, beforeProjectID: nil)
                    }
                }
            }
            Divider()
            Button(WorkspaceLexicon.newTopicEllipsis) { vm.uiCreateTrack(in: proj.id) }
            Divider()
            Button("Move to Trash") { vm.uiTrashProject(proj.id, title: proj.name) }
        }
    }

    private func trackMenu(env: WorkspaceRepository.EnvironmentNode, proj: WorkspaceRepository.ProjectNode, tr: WorkspaceRepository.TrackNode) -> some View {
        Group {
            Button("Rename") { beginRename(kind: .track, id: tr.id, current: tr.name) }
            Menu("Move…") {
                ForEach(vm.libraryTree) { targetEnv in
                    Menu(targetEnv.name) {
                        ForEach(targetEnv.projects) { targetProj in
                            Button(targetProj.name) {
                                vm.uiMoveOrReorderTrack(tr.id, toProjectID: targetProj.id, beforeTrackID: nil)
                            }
                        }
                    }
                }
            }
            Divider()
            Button(WorkspaceLexicon.newChatEllipsis) { vm.presentNewChatEnvironmentFlow() }
            Divider()
            Button("Move to Trash") { vm.uiTrashTrack(tr.id, title: tr.name) }
        }
    }

    private func sceneMenu(env: WorkspaceRepository.EnvironmentNode, proj: WorkspaceRepository.ProjectNode, tr: WorkspaceRepository.TrackNode, sc: WorkspaceRepository.SceneNode) -> some View {
        Group {
            Button("Rename") { beginRename(kind: .scene, id: sc.id, current: sc.title) }
            Menu("Move…") {
                ForEach(vm.libraryTree) { targetEnv in
                    Menu(targetEnv.name) {
                        ForEach(targetEnv.projects) { targetProj in
                            Menu(targetProj.name) {
                                ForEach(targetProj.tracks) { targetTrack in
                                    Button(targetTrack.name) {
                                        vm.uiMoveOrReorderScene(sc.id, toTrackID: targetTrack.id, beforeSceneID: nil)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Divider()
            Button("Move to Trash") { vm.uiTrashScene(sc.id, title: sc.title) }
        }
    }

    // MARK: - Inline rename
    private func beginRename(kind: RenameRequest.Kind, id: UUID, current: String) {
        editing = EditingTarget(kind: kind, id: id, currentName: current)
        editingText = current
        DispatchQueue.main.async { renameFocused = true }
    }

    private func cancelRename() {
        editing = nil
        editingText = ""
        renameFocused = false
    }

    private func commitRename() {
        guard let e = editing else { return }
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != e.currentName else {
            cancelRename()
            return
        }
        vm.uiRename(req: .init(kind: e.kind, entityID: e.id, currentName: e.currentName), newValue: trimmed)
        cancelRename()
    }

    // MARK: - Trash
    private var trashSection: some View {
      VStack(alignment: .leading, spacing: 8) {
        // Header row (always visible when trash is non-empty)
        HStack(spacing: 8) {
          Image(systemName: "trash")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppTheme.Colors.textSecondary)

          Text("Trash")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppTheme.Colors.textSecondary)

          Spacer(minLength: 0)

          // Root count badge (keeps it readable without expanding)
          Text("\(vm.trashRoots.count)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
              RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.Colors.surface1.opacity(0.7))
            )

          Image(systemName: isTrashExpanded ? "chevron.down" : "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
          withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            isTrashExpanded.toggle()
          }
        }
        .contextMenu {
          Button("Empty Trash…") { vm.uiEmptyTrash() }
        }

        if isTrashExpanded {
          ScrollView {
            VStack(alignment: .leading, spacing: 6) {
              ForEach(vm.trashRoots) { item in
                trashRow(item)
              }
            }
            .padding(.top, 2)
          }
          .frame(maxHeight: 220)
        }
      }
    }
    
    private func trashIcon(for kind: WorkspaceRepository.TrashKind) -> String {
      switch kind {
      case .environment: return "folder"
      case .project: return "folder.fill"
      case .track: return "rectangle.3.offgrid"
      case .scene: return "square.stack.3d.down.right"
      case .block: return "doc.text"
      }
    }
    
   private func trashRow(_ item: WorkspaceRepository.TrashRoot) -> some View {
      HStack(spacing: 8) {
        Image(systemName: trashIcon(for: item.kind))
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(AppTheme.Colors.textSecondary)

        Text(item.title)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(AppTheme.Colors.textSecondary)
          .lineLimit(1)

        Spacer(minLength: 0)

        if item.childCount > 0 {
          Text("\(item.childCount)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
              RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.Colors.surface1.opacity(0.7))
            )
        }
      }
      .contentShape(Rectangle())
      .contextMenu {
        Button("Restore…") {
          restoreRequest = .init(kind: kind(item.kind), entityID: item.id, title: item.title)
        }
        Divider()
        Button("Empty Trash…") { vm.uiEmptyTrash() }
      }
    }
    private func kind(_ k: WorkspaceRepository.TrashKind) -> RestoreRequest.Kind {
        switch k {
        case .environment: return .environment
        case .project: return .project
        case .track: return .track
        case .scene: return .scene
        case .block: return .block
        }
    }
}

// MARK: - Trash restore sheet (kept here so TracksRail stays canonical)
private struct RestoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vm: WorkspaceViewModel
    let req: RestoreRequest
    @State private var selectedParentID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Restore “\(req.title)”")
                .font(.system(size: 14, weight: .semibold))

            if req.kind == .environment || req.kind == .block {
                Text("This item can be restored immediately.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            } else {
                Text("Choose destination:")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Picker("", selection: $selectedParentID) {
                    ForEach(vm.restoreDestinations(for: req.kind), id: \.id) { d in
                        Text(d.title).tag(Optional(d.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Restore") {
                    vm.uiRestore(req: req, destinationID: selectedParentID)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled((req.kind != .environment && req.kind != .block) && selectedParentID == nil)
            }
        }
        .padding(16)
        .frame(width: 520)
        .onAppear { selectedParentID = vm.defaultRestoreDestination(for: req.kind) }
    }
}
