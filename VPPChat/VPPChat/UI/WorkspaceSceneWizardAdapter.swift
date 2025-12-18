//
//  WorkspaceSceneWizardAdapter.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/16/25.
//


import Foundation

@MainActor
final class WorkspaceSceneWizardAdapter: SceneWizardAPI, @unchecked Sendable {
    private unowned let vm: WorkspaceViewModel

    init(vm: WorkspaceViewModel) {
        self.vm = vm
    }

    // MARK: - Lists

    func listEnvironments() async throws -> [SceneWizardOption] {
        vm.libraryTree.map { .init(id: $0.id, title: $0.name) }
    }

    func listProjects() async throws -> [SceneWizardOption] {
        vm.store.allProjects.map { .init(id: $0.id, title: $0.name) }
    }

    func listTracks() async throws -> [SceneWizardOption] {
        var out: [SceneWizardOption] = []
        var seen: Set<UUID> = []

        for project in vm.store.allProjects {
            for trackID in project.tracks {
                guard seen.insert(trackID).inserted else { continue }
                if let t = vm.store.track(id: trackID) {
                    out.append(.init(id: t.id, title: "\(project.name) ▸ \(t.name)"))
                }
            }
        }
        return out
    }

    func listScenes() async throws -> [SceneWizardOption] {
        var out: [SceneWizardOption] = []
        var seen: Set<UUID> = []

        for project in vm.store.allProjects {
            for trackID in project.tracks {
                guard let track = vm.store.track(id: trackID) else { continue }
                for sceneID in track.scenes {
                    guard seen.insert(sceneID).inserted else { continue }
                    if let s = vm.store.scene(id: sceneID) {
                        out.append(.init(id: s.id, title: "\(track.name) ▸ \(s.title)"))
                    }
                }
            }
        }
        return out
    }

    // MARK: - Create

    func createEnvironment(name: String) async throws -> UUID {
        try vm.uiCreateViaWizard(kind: .environment, envID: nil, projectID: nil, trackID: nil, name: name)
    }

    func createProject(envID: UUID, name: String) async throws -> UUID {
        try vm.uiCreateViaWizard(kind: .project, envID: envID, projectID: nil, trackID: nil, name: name)
    }

    func createTrack(projectID: UUID, name: String) async throws -> UUID {
        try vm.uiCreateViaWizard(kind: .track, envID: nil, projectID: projectID, trackID: nil, name: name)
    }

    func createScene(trackID: UUID, name: String) async throws -> UUID {
        try vm.uiCreateViaWizard(kind: .scene, envID: nil, projectID: nil, trackID: trackID, name: name)
    }

    // MARK: - Move

    func moveProjects(projectIDs: [UUID], to envID: UUID) async throws {
        for id in projectIDs {
            vm.uiMoveProject(id, toEnvironment: envID)
        }
    }

    func moveTracks(trackIDs: [UUID], to projectID: UUID) async throws {
        for id in trackIDs {
            vm.uiMoveTrack(id, toProject: projectID)
        }
    }

    func moveScenes(sceneIDs: [UUID], to trackID: UUID) async throws {
        for id in sceneIDs {
            vm.uiMoveScene(id, toTrack: trackID)
        }
    }

    // MARK: - Navigation

    func selectScene(_ sceneID: UUID) async {
        if let scene = vm.store.scene(id: sceneID) {
            vm.select(scene: scene)
        } else {
            vm.selectedSceneID = sceneID
            vm.selectedBlockID = nil
        }
    }

    func goToStudio() async {
        if vm.isSceneWizardOnboarding {
            await MainActor.run { vm.markOnboardingComplete() }
            await MainActor.run { vm.isSceneWizardOnboarding = false }
        }
        vm.isSceneCreationWizardPresented = false

        vm.goToStudio()
    }

    func goToConsole() async {
        // Ensure there’s a conversation block to back the Console session.
        if let sceneID = vm.selectedSceneID,
           let scene = vm.store.scene(id: sceneID)
        {
            let existing = vm.store.blocks(in: scene)
                .filter { $0.kind == .conversation }
                .sorted { $0.updatedAt > $1.updatedAt }
                .first

            let convo: Block = existing ?? {
                let b = Block(
                    sceneID: scene.id,
                    kind: .conversation,
                    title: "New Chat",
                    subtitle: nil,
                    messages: [],
                    documentText: nil,
                    isCanonical: false,
                    createdAt: .now,
                    updatedAt: .now
                )
                vm.store.add(block: b)
                vm.syncConsoleSessionsFromBlocks()
                return b
            }()

            vm.selectedSessionID = convo.id
            vm.selectedBlockID = convo.id
        }

        if vm.isSceneWizardOnboarding {
            await MainActor.run { vm.markOnboardingComplete() }
            await MainActor.run { vm.isSceneWizardOnboarding = false }
        }
        vm.isSceneCreationWizardPresented = false

        vm.goToConsole()
    }
}
