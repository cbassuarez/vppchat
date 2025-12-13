import Foundation
import Combine
import SwiftUI

final class WorkspaceViewModel: ObservableObject {
    @Published var store: WorkspaceStore
    @Published var selectedProjectID: Project.ID?
    @Published var selectedTrackID: Track.ID?
    @Published var selectedSceneID: Scene.ID?

    @Published var isCommandSpaceVisible: Bool = false
    @Published var vppRuntime: VppRuntime

    private var cancellables: Set<AnyCancellable> = []

    init(store: WorkspaceStore = WorkspaceStore(), runtime: VppRuntime = VppRuntime(state: .default)) {
        self.store = store
        self.vppRuntime = runtime

        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        if let project = store.allProjects.first {
            selectedProjectID = project.id
            if let trackID = project.tracks.first,
               let track = store.track(id: trackID),
               let sceneID = track.lastOpenedSceneID ?? track.scenes.first {
                selectedTrackID = track.id
                selectedSceneID = sceneID
            }
        }
    }

    var selectedProject: Project? {
        store.project(id: selectedProjectID)
    }

    var selectedTrack: Track? {
        store.track(id: selectedTrackID)
    }

    var selectedScene: Scene? {
        store.scene(id: selectedSceneID)
    }

    func select(project: Project) {
        selectedProjectID = project.id
        if let trackID = project.lastOpenedTrackID ?? project.tracks.first,
           let track = store.track(id: trackID) {
            select(track: track)
        }
    }

    func select(track: Track) {
        selectedTrackID = track.id
        if let sceneID = track.lastOpenedSceneID ?? track.scenes.first,
           let scene = store.scene(id: sceneID) {
            select(scene: scene)
        }
    }

    func select(scene: Scene) {
        selectedSceneID = scene.id
    }

    func select(block: Block) {
        guard let scene = store.scene(id: block.sceneID),
              let track = store.track(id: scene.trackID),
              let project = store.project(id: track.projectID) else {
            return
        }

        selectedProjectID = project.id
        selectedTrackID = track.id
        selectedSceneID = scene.id
    }
}
