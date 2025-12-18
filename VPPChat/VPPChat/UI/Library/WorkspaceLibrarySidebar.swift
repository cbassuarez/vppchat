//
//  WorkspaceLibrarySidebar.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import SwiftUI

struct WorkspaceLibrarySidebar: View {
    @EnvironmentObject private var vm: WorkspaceViewModel

    @State private var renameRequest: RenameRequest?
    @State private var restoreRequest: RestoreRequest?
    @State private var isTrashExpanded = false
    @State private var isTrashHovering = false

    @State private var expandedEnvs: Set<UUID> = []
    @State private var expandedProjects: Set<UUID> = []
    @State private var expandedTracks: Set<UUID> = []
    @State private var expandedScenes: Set<UUID> = []

    var body: some View {
        VStack(spacing: 10) {
            workspaceHeader

            ScrollView {
              VStack(alignment: .leading, spacing: 8) {
                environmentsTree
              }
              .padding(.vertical, 6)
            }

            Divider().opacity(0.6)
            trashSection
        }
        .overlay(alignment: .top) {
          if let t = vm.toast {
            Text(t.message)
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(AppTheme.Colors.textPrimary)
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(
                RoundedRectangle(cornerRadius: 10)
                  .fill(AppTheme.Colors.surface1.opacity(0.92))
              )
              .padding(.top, 8)
              .transition(.move(edge: .top).combined(with: .opacity))
          }
        }

        .padding(12)
        .panelBackground()
        .onAppear {
          vm.reloadLibraryTree()
          vm.reloadTrash()
        }
        .onChange(of: vm.activeWorkspaceID) { _ in
          vm.reloadLibraryTree()
          vm.reloadTrash()
        }
        .sheet(item: $renameRequest) { req in
            RenameSheet(req: req)
                .environmentObject(vm)
        }
        .sheet(item: $restoreRequest) { req in
            RestoreSheet(req: req)
                .environmentObject(vm)
        }
    }

    private var workspaceHeader: some View {
        HStack(spacing: 8) {
            Text(vm.activeWorkspaceName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Spacer()
        }
    }


    private var environmentsTree: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(vm.libraryTree) { env in
                envRow(env)
            }
        }
    }

    private func envRow(_ env: WorkspaceRepository.EnvironmentNode) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedEnvs.contains(env.id) },
                set: { isExpanded in
                                    if isExpanded { expandedEnvs.insert(env.id) }
                                    else { expandedEnvs.remove(env.id) }
                                }
            )
        ) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(env.projects) { p in
                    projectRow(p)
                }
            }
            .padding(.leading, 12)
        } label: {
            HStack(spacing: 8) {
            //    Image(systemName: "folder.fill")
                Text(env.name)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .contentShape(Rectangle())
            .contextMenu {
                Button("New Project…") { vm.uiCreateProject(in: env.id) }
                Button("Rename…") { renameRequest = .init(kind: .environment, entityID: env.id, currentName: env.name) }
                Divider()
                Button("Move to Trash…") { vm.uiTrashEnvironment(env.id, title: env.name) }
            }
            .dropDestination(for: WorkspaceDragPayload.self) { payloads, _ in
                // project -> environment only
                let moved = payloads.contains { payload in
                    guard payload.kind == .project else { return false }
                    vm.uiMoveProject(payload.id, toEnvironment: env.id)
                    return true
                }
                return moved
            }
        }
    }

    private func projectRow(_ p: WorkspaceRepository.ProjectNode) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedProjects.contains(p.id) },
                set: { isExpanded in
                                    if isExpanded { expandedProjects.insert(p.id) }
                                    else { expandedProjects.remove(p.id) }
                                }
            )
        ) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(p.tracks) { t in
                    trackRow(t)
                }
            }
            .padding(.leading, 12)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                Text(p.name)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .contentShape(Rectangle())
            .contextMenu {
                Button(WorkspaceLexicon.newTopicEllipsis) { vm.uiCreateTrack(in: p.id) }
                Button("Rename…") { renameRequest = .init(kind: .project, entityID: p.id, currentName: p.name) }
                Divider()
                Button("Move to Trash…") { vm.uiTrashProject(p.id, title: p.name) }
            }
            .draggable(WorkspaceDragPayload(kind: .project, id: p.id))
            .dropDestination(for: WorkspaceDragPayload.self) { payloads, _ in
                // topic -> project only
                let moved = payloads.contains { payload in
                    guard payload.kind == .track else { return false }
                    vm.uiMoveTrack(payload.id, toProject: p.id)
                    return true
                }
                return moved
            }
        }
    }

    private func trackRow(_ t: WorkspaceRepository.TrackNode) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedTracks.contains(t.id) },
                set: { isExpanded in
                                    if isExpanded { expandedTracks.insert(t.id) }
                                    else { expandedTracks.remove(t.id) }
                                }
            )
        ) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(t.scenes) { s in
                    sceneRow(s)
                }
            }
            .padding(.leading, 12)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.3.offgrid.fill")
                Text(t.name)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .contentShape(Rectangle())
            .contextMenu {
                Button(WorkspaceLexicon.newChatEllipsis) { vm.presentNewChatEnvironmentFlow() }
                Button("Rename…") { renameRequest = .init(kind: .track, entityID: t.id, currentName: t.name) }
                Divider()
                Button("Move to Trash…") { vm.uiTrashTrack(t.id, title: t.name) }
            }
            .draggable(WorkspaceDragPayload(kind: .track, id: t.id))
            .dropDestination(for: WorkspaceDragPayload.self) { payloads, _ in
                // chat -> topic only
                let moved = payloads.contains { payload in
                    guard payload.kind == .scene else { return false }
                    vm.uiMoveScene(payload.id, toTrack: t.id)
                    return true
                }
                return moved
            }
        }
    }

    func sceneRow(_ s: WorkspaceRepository.SceneNode) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedScenes.contains(s.id) },
                set: { isExpanded in
                                    if isExpanded { expandedScenes.insert(s.id) }
                                    else { expandedScenes.remove(s.id) }
                                }
            )
        ) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(s.blocks) { b in
                    blockRow(b)
                }
            }
            .padding(.leading, 12)
        } label: {
            Button {
                vm.uiSelectScene(s.id)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.down.right.fill")
                    Text(s.title)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(vm.selectedSceneID == s.id ? AppTheme.Colors.structuralAccent : AppTheme.Colors.textPrimary)
            .contentShape(Rectangle())
            .contextMenu {
                Button("Rename…") { renameRequest = .init(kind: .scene, entityID: s.id, currentName: s.title) }
                Divider()
                Button("Move to Trash…") { vm.uiTrashScene(s.id, title: s.title) }
            }
            .draggable(WorkspaceDragPayload(kind: .scene, id: s.id))
        }
    }

    private func blockRow(_ b: WorkspaceRepository.BlockNode) -> some View {
        Button {
            if b.kind == "conversation" {
                vm.uiSelectConversationBlock(b.id, sceneID: b.sceneID)
            } else {
                vm.uiSelectBlockInStudio(b.id, sceneID: b.sceneID)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: b.kind == "conversation" ? "bubble.left.and.text.bubble.fill" : "doc.text.fill")
                Text(b.title)
                if b.isCanonical {
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.structuralAccent)
                }
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(vm.selectedBlockID == b.id ? AppTheme.Colors.structuralAccent : AppTheme.Colors.textSecondary)
        .contentShape(Rectangle())
        .contextMenu {
            if b.kind == "conversation" || b.kind == "document" {
                Button("Move to Trash…") { vm.uiTrashBlock(b.id, title: b.title) }
            }
        }
    }
    
    func trashRow(_ item: WorkspaceRepository.TrashRoot) -> some View {
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

    private func trashIcon(for kind: WorkspaceRepository.TrashKind) -> String {
      switch kind {
      case .environment: return "folder"
      case .project: return "folder.fill"
      case .track: return "rectangle.3.offgrid"
      case .scene: return "square.stack.3d.down.right"
      case .block: return "doc.text"
      }
    }
    

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

// MARK: - Sheets

private struct RenameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vm: WorkspaceViewModel
    let req: RenameRequest

    @State private var text: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rename")
                .font(.system(size: 14, weight: .semibold))
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    vm.uiRename(req: req, newValue: text)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 420)
        .onAppear { text = req.currentName }
    }
}

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
