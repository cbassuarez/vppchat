//
//  SceneWizardReducer.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/16/25.
//


import Foundation


public enum SceneWizardAction: Equatable {
    case setGoal(SceneWizardGoal)


    case setEnv(UUID?)
    case setProject(UUID?)
    case setTrack(UUID?)


    case setEnvName(String)
    case setProjectName(String)
    case setTrackName(String)
    case setSceneName(String)


    case toggleMoveProject(UUID)
    case toggleMoveTrack(UUID)
    case toggleMoveScene(UUID)


    case setChoseCreateNewProject(Bool)
    case setChoseCreateNewTrack(Bool)
    case setChoseCreateNewScene(Bool)


    case back
    case next
    case setError(String?)
    case setBusy(Bool)
}


public struct SceneWizardReducer {
    public init() {}


    public func canContinue(_ state: SceneWizardState) -> Bool {
        if state.isBusy { return false }


        switch state.step {
        case .goal:
            return true


        case .targetTrack:
            // You can continue if:
            // - an existing track is selected, OR
            // - you’ve chosen to create upstream (represented by advancing via dedicated buttons in UI)
            return state.trackID != nil


        case .createEnvironment:
            return !trim(state.envName).isEmpty


        case .populateEnvironment:
            return !state.selectedProjectIDsToMove.isEmpty || state.choseCreateNewProject


        case .createProject:
            return (state.envID != nil) && !trim(state.projectName).isEmpty


        case .populateProject:
            return !state.selectedTrackIDsToMove.isEmpty || state.choseCreateNewTrack


        case .createTrack:
            return (state.projectID != nil) && !trim(state.trackName).isEmpty


        case .populateTrack:
            return !state.selectedSceneIDsToMove.isEmpty || state.choseCreateNewScene


        case .createScene:
            return (state.trackID != nil) && !trim(state.sceneName).isEmpty
        }
    }


    public mutating func reduce(_ state: inout SceneWizardState, _ action: SceneWizardAction) {
        switch action {
        case .setGoal(let g):
            state.goal = g


        case .setEnv(let id):
            state.envID = id
            // reset downstream if parent changes
            state.projectID = nil
            state.trackID = nil


        case .setProject(let id):
            state.projectID = id
            state.trackID = nil


        case .setTrack(let id):
            state.trackID = id


        case .setEnvName(let s):
            state.envName = s


        case .setProjectName(let s):
            state.projectName = s


        case .setTrackName(let s):
            state.trackName = s


        case .setSceneName(let s):
            state.sceneName = s


        case .toggleMoveProject(let id):
            toggle(&state.selectedProjectIDsToMove, id)


        case .toggleMoveTrack(let id):
            toggle(&state.selectedTrackIDsToMove, id)


        case .toggleMoveScene(let id):
            toggle(&state.selectedSceneIDsToMove, id)


        case .setChoseCreateNewProject(let b):
            state.choseCreateNewProject = b


        case .setChoseCreateNewTrack(let b):
            state.choseCreateNewTrack = b


        case .setChoseCreateNewScene(let b):
            state.choseCreateNewScene = b


        case .back:
            state.errorText = nil
            state.step = prev(state.step)


        case .next:
            state.errorText = nil
            state.step = next(state.step)


        case .setError(let msg):
            state.errorText = msg


        case .setBusy(let b):
            state.isBusy = b
        }
    }


    private func trim(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }


    private func toggle(_ set: inout Set<UUID>, _ id: UUID) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
    }


    private func prev(_ step: SceneWizardStep) -> SceneWizardStep {
        SceneWizardStep(rawValue: max(0, step.rawValue - 1)) ?? .targetTrack
    }


    private func next(_ step: SceneWizardStep) -> SceneWizardStep {
        // Note: createScene is terminal; the view will call complete() instead of advancing.
        SceneWizardStep(rawValue: min(SceneWizardStep.createScene.rawValue, step.rawValue + 1)) ?? .createScene
    }
}
